#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/com/example/sunalarm

cat > app/src/main/java/com/example/sunalarm/AlarmScheduler.java <<'EOF'
package com.example.sunalarm;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import java.util.Calendar;
import java.util.Locale;

public final class AlarmScheduler {
    public static final String EXTRA_MODE = "mode";
    public static final String EXTRA_SNOOZE = "snooze";
    public static final String MODE_SUNRISE = "sunrise";
    public static final String MODE_SUNSET = "sunset";

    private static final int REQ_SUNRISE = 1001;
    private static final int REQ_SUNSET = 1002;
    private static final int REQ_SNOOZE_SUNRISE = 1003;
    private static final int REQ_SNOOZE_SUNSET = 1004;
    private static final int REQ_SHOW_APP = 2001;

    private AlarmScheduler() {
    }

    public static void scheduleAll(Context context) {
        if (Prefs.isSunriseEnabled(context)) schedule(context, MODE_SUNRISE);
        else cancel(context, MODE_SUNRISE);

        if (Prefs.isSunsetEnabled(context)) schedule(context, MODE_SUNSET);
        else cancel(context, MODE_SUNSET);
    }

    public static void schedule(Context context, String mode) {
        AlarmManager am = alarmManager(context);
        PendingIntent operation = createPendingIntent(context, mode, false);
        am.cancel(operation);

        boolean enabled = MODE_SUNRISE.equals(mode)
                ? Prefs.isSunriseEnabled(context)
                : Prefs.isSunsetEnabled(context);
        if (!enabled) return;

        long triggerAtMillis = nextTrigger(context, mode).getTimeInMillis();
        setExact(am, context, triggerAtMillis, operation);
    }

    public static void scheduleSnooze(Context context, String mode, int minutes) {
        AlarmManager am = alarmManager(context);
        PendingIntent operation = createPendingIntent(context, mode, true);
        long triggerAtMillis = System.currentTimeMillis() + minutes * 60_000L;
        setExact(am, context, triggerAtMillis, operation);
    }

    private static void setExact(AlarmManager am, Context context, long triggerAtMillis, PendingIntent operation) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation);
        } else {
            AlarmManager.AlarmClockInfo info =
                    new AlarmManager.AlarmClockInfo(triggerAtMillis, createShowIntent(context));
            am.setAlarmClock(info, operation);
        }
    }

    public static void cancel(Context context, String mode) {
        alarmManager(context).cancel(createPendingIntent(context, mode, false));
    }

    public static String getNextAlarmText(Context context) {
        boolean sunriseEnabled = Prefs.isSunriseEnabled(context);
        boolean sunsetEnabled = Prefs.isSunsetEnabled(context);
        if (!sunriseEnabled && !sunsetEnabled) {
            return context.getString(R.string.status_none);
        }

        Long sunriseMillis = sunriseEnabled ? nextTrigger(context, MODE_SUNRISE).getTimeInMillis() : null;
        Long sunsetMillis = sunsetEnabled ? nextTrigger(context, MODE_SUNSET).getTimeInMillis() : null;

        boolean useSunrise;
        if (sunriseMillis == null) useSunrise = false;
        else if (sunsetMillis == null) useSunrise = true;
        else useSunrise = sunriseMillis <= sunsetMillis;

        long millis = useSunrise ? sunriseMillis : sunsetMillis;

        String modeName = useSunrise
                ? context.getString(R.string.sunrise_label)
                : context.getString(R.string.sunset_label);

        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(millis);
        String time = String.format(Locale.getDefault(), "%02d:%02d",
                c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE));

        return context.getString(R.string.status_next, modeName, time);
    }

    private static AlarmManager alarmManager(Context context) {
        return (AlarmManager) context.getApplicationContext().getSystemService(Context.ALARM_SERVICE);
    }

    private static Calendar nextTrigger(Context context, String mode) {
        int hour, minute;
        if (MODE_SUNRISE.equals(mode)) {
            hour = Prefs.getSunriseHour(context);
            minute = Prefs.getSunriseMinute(context);
        } else {
            hour = Prefs.getSunsetHour(context);
            minute = Prefs.getSunsetMinute(context);
        }

        Calendar calendar = Calendar.getInstance();
        calendar.set(Calendar.HOUR_OF_DAY, hour);
        calendar.set(Calendar.MINUTE, minute);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        if (calendar.getTimeInMillis() <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1);
        }
        return calendar;
    }

    private static PendingIntent createPendingIntent(Context context, String mode, boolean snooze) {
        Intent intent = new Intent(context.getApplicationContext(), AlarmReceiver.class);
        intent.putExtra(EXTRA_MODE, mode);
        intent.putExtra(EXTRA_SNOOZE, snooze);

        int requestCode;
        if (snooze) {
            requestCode = MODE_SUNRISE.equals(mode) ? REQ_SNOOZE_SUNRISE : REQ_SNOOZE_SUNSET;
        } else {
            requestCode = MODE_SUNRISE.equals(mode) ? REQ_SUNRISE : REQ_SUNSET;
        }

        return PendingIntent.getBroadcast(context.getApplicationContext(), requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static PendingIntent createShowIntent(Context context) {
        Intent intent = new Intent(context.getApplicationContext(), MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(context.getApplicationContext(), REQ_SHOW_APP, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
}
EOF

cat > app/src/main/java/com/example/sunalarm/AlarmReceiver.java <<'EOF'
package com.example.sunalarm;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.PowerManager;

public class AlarmReceiver extends BroadcastReceiver {
    private static PowerManager.WakeLock receiverWakeLock;

    @Override
    public void onReceive(Context context, Intent intent) {
        String mode = intent != null ? intent.getStringExtra(AlarmScheduler.EXTRA_MODE) : null;
        if (mode == null) mode = AlarmScheduler.MODE_SUNRISE;

        boolean snooze = intent != null && intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE, false);

        acquireWakeLock(context);

        if (!snooze) {
            AlarmScheduler.schedule(context, mode);
        }

        Intent serviceIntent = new Intent(context.getApplicationContext(), AlarmService.class);
        serviceIntent.putExtra(AlarmScheduler.EXTRA_MODE, mode);

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.getApplicationContext().startForegroundService(serviceIntent);
            } else {
                context.getApplicationContext().startService(serviceIntent);
            }
        } catch (Exception e) {
            Intent activityIntent = new Intent(context.getApplicationContext(), AlarmActivity.class);
            activityIntent.putExtra(AlarmScheduler.EXTRA_MODE, mode);
            activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
            try {
                context.getApplicationContext().startActivity(activityIntent);
            } catch (Exception ignored) {
            }
        }
    }

    private static synchronized void acquireWakeLock(Context context) {
        PowerManager pm = (PowerManager) context.getApplicationContext()
                .getSystemService(Context.POWER_SERVICE);
        if (receiverWakeLock == null) {
            receiverWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SunAlarm:AlarmReceiver");
            receiverWakeLock.setReferenceCounted(false);
        }
        if (!receiverWakeLock.isHeld()) {
            receiverWakeLock.acquire(10_000L);
        }
    }
}
EOF

cat > app/src/main/java/com/example/sunalarm/AlarmService.java <<'EOF'
package com.example.sunalarm;

import android.animation.ValueAnimator;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.os.VibrationEffect;
import android.os.Vibrator;

public class AlarmService extends Service {
    private static final String CHANNEL_ID = "sun_alarm_channel";
    private static final int NOTIFICATION_ID = 3001;
    private static final String ACTION_STOP = "com.example.sunalarm.STOP_ALARM";

    private MediaPlayer mediaPlayer;
    private ValueAnimator volumeAnimator;
    private Vibrator vibrator;
    private PowerManager.WakeLock serviceWakeLock;
    private String mode = AlarmScheduler.MODE_SUNRISE;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }

        if (intent != null && intent.hasExtra(AlarmScheduler.EXTRA_MODE)) {
            String extra = intent.getStringExtra(AlarmScheduler.EXTRA_MODE);
            if (extra != null) mode = extra;
        }

        acquireWakeLock();
        createNotificationChannel();
        startForegroundWithNotification();
        startSound();
        startVibration();

        return START_REDELIVER_INTENT;
    }

    private void acquireWakeLock() {
        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        if (serviceWakeLock == null) {
            serviceWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SunAlarm:AlarmService");
            serviceWakeLock.setReferenceCounted(false);
        }
        if (!serviceWakeLock.isHeld()) {
            serviceWakeLock.acquire(10 * 60 * 1000L);
        }
    }

    private void createNotificationChannel() {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID,
                getString(R.string.alarm_channel_name), NotificationManager.IMPORTANCE_HIGH);
        channel.setBypassDnd(true);
        channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        channel.setSound(null, null);
        channel.enableVibration(false);
        nm.createNotificationChannel(channel);
    }

    private void startForegroundWithNotification() {
        Intent fullScreenIntent = new Intent(this, AlarmActivity.class);
        fullScreenIntent.putExtra(AlarmScheduler.EXTRA_MODE, mode);
        fullScreenIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);

        PendingIntent fullScreenPendingIntent = PendingIntent.getActivity(this, 4001, fullScreenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Intent stopIntent = new Intent(this, AlarmService.class);
        stopIntent.setAction(ACTION_STOP);
        PendingIntent stopPendingIntent = PendingIntent.getService(this, 4002, stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        String title = AlarmScheduler.MODE_SUNSET.equals(mode)
                ? getString(R.string.sunset_alarm_title)
                : getString(R.string.sunrise_alarm_title);

        Notification notification = new Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_time)
                .setContentTitle(title)
                .setContentText(getString(R.string.sun_simulation))
                .setCategory(Notification.CATEGORY_ALARM)
                .setFullScreenIntent(fullScreenPendingIntent, true)
                .setOngoing(true)
                .setAutoCancel(false)
                .addAction(new Notification.Action.Builder(
                        android.R.drawable.ic_media_pause,
                        getString(R.string.stop),
                        stopPendingIntent).build())
                .build();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    private void startSound() {
        try {
            if (mediaPlayer != null) {
                mediaPlayer.release();
                mediaPlayer = null;
            }

            Uri alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
            if (alarmUri == null) alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            if (alarmUri == null) alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);

            mediaPlayer = new MediaPlayer();
            mediaPlayer.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build());
            mediaPlayer.setDataSource(this, alarmUri);
            mediaPlayer.setLooping(true);
            mediaPlayer.setVolume(0f, 0f);
            mediaPlayer.prepare();
            mediaPlayer.start();

            if (volumeAnimator != null) volumeAnimator.cancel();
            volumeAnimator = ValueAnimator.ofFloat(0f, 1f);
            volumeAnimator.setDuration(20_000L);
            volumeAnimator.addUpdateListener(a -> {
                float v = (float) a.getAnimatedValue();
                if (mediaPlayer != null) mediaPlayer.setVolume(v, v);
            });
            volumeAnimator.start();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void startVibration() {
        vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        if (vibrator != null && vibrator.hasVibrator()) {
            long[] pattern = {0, 600, 400, 600, 1400};
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0));
        }
    }

    @Override
    public void onDestroy() {
        if (volumeAnimator != null) {
            volumeAnimator.cancel();
            volumeAnimator = null;
        }
        if (mediaPlayer != null) {
            try {
                if (mediaPlayer.isPlaying()) mediaPlayer.stop();
            } catch (Exception ignored) {
            }
            mediaPlayer.release();
            mediaPlayer = null;
        }
        if (vibrator != null) {
            vibrator.cancel();
            vibrator = null;
        }
        if (serviceWakeLock != null && serviceWakeLock.isHeld()) {
            serviceWakeLock.release();
        }
        super.onDestroy();
    }
}
EOF

echo "gen2: OK"
