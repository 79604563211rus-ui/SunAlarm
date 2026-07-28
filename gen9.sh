#!/usr/bin/env bash
set -euo pipefail
mkdir -p app/src/main/java/com/example/sunalarm

cat > app/src/main/java/com/example/sunalarm/MainActivity.java <<'EOF'
package com.example.sunalarm;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.TimePickerDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.widget.Button;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final int REQUEST_NOTIFICATIONS = 1;

    private final Handler clockHandler = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("EEEE, d MMMM", Locale.getDefault());

    private TextView mainClock, mainDate, statusText, durationText;
    private Button sunriseTimeButton, sunsetTimeButton, testSunriseButton, testSunsetButton, permissionsButton;
    private Switch sunriseSwitch, sunsetSwitch;
    private SeekBar durationSeekBar;
    private SunView preview;
    private Button[] themeButtons;

    private final Runnable clockTick = new Runnable() {
        @Override public void run() {
            Date now = new Date();
            mainClock.setText(timeFormat.format(now));
            mainDate.setText(dateFormat.format(now));
            updatePreview();
            clockHandler.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        preview = findViewById(R.id.main_preview);
        preview.setAnimated(false);
        mainClock = findViewById(R.id.main_clock);
        mainDate = findViewById(R.id.main_date);
        statusText = findViewById(R.id.status_text);
        durationText = findViewById(R.id.duration_text);
        sunriseTimeButton = findViewById(R.id.sunrise_time_button);
        sunsetTimeButton = findViewById(R.id.sunset_time_button);
        testSunriseButton = findViewById(R.id.test_sunrise_button);
        testSunsetButton = findViewById(R.id.test_sunset_button);
        permissionsButton = findViewById(R.id.permissions_button);
        sunriseSwitch = findViewById(R.id.sunrise_switch);
        sunsetSwitch = findViewById(R.id.sunset_switch);
        durationSeekBar = findViewById(R.id.duration_seekbar);

        themeButtons = new Button[]{
                findViewById(R.id.theme_hills), findViewById(R.id.theme_sea),
                findViewById(R.id.theme_desert), findViewById(R.id.theme_polar)};
        for (int i = 0; i < themeButtons.length; i++) {
            final int theme = i;
            themeButtons[i].setOnClickListener(v -> {
                Prefs.setTheme(this, theme);
                applyTheme();
            });
        }

        durationSeekBar.setMax(9);
        sunriseSwitch.setChecked(Prefs.isSunriseEnabled(this));
        sunsetSwitch.setChecked(Prefs.isSunsetEnabled(this));
        durationSeekBar.setProgress(Math.max(0, Math.min(9, Prefs.getDurationSeconds(this)/60 - 1)));

        sunriseTimeButton.setOnClickListener(v -> showTimePicker(true));
        sunsetTimeButton.setOnClickListener(v -> showTimePicker(false));
        sunriseSwitch.setOnCheckedChangeListener((b, c) -> {
            Prefs.setSunriseEnabled(this, c);
            if (c) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNRISE);
            else AlarmScheduler.cancel(this, AlarmScheduler.MODE_SUNRISE);
            updateUi();
        });
        sunsetSwitch.setOnCheckedChangeListener((b, c) -> {
            Prefs.setSunsetEnabled(this, c);
            if (c) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNSET);
            else AlarmScheduler.cancel(this, AlarmScheduler.MODE_SUNSET);
            updateUi();
        });
        durationSeekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar s, int p, boolean u){
                Prefs.setDurationSeconds(MainActivity.this, (p+1)*60);
                durationText.setText(getString(R.string.duration_minutes, p+1));
            }
            @Override public void onStartTrackingTouch(SeekBar s){}
            @Override public void onStopTrackingTouch(SeekBar s){}
        });
        testSunriseButton.setOnClickListener(v -> startTest(AlarmScheduler.MODE_SUNRISE));
        testSunsetButton.setOnClickListener(v -> startTest(AlarmScheduler.MODE_SUNSET));
        permissionsButton.setOnClickListener(v -> checkAndOpenPermissions());

        applyTheme();
        requestNotificationPermissionIfNeeded();
        clockHandler.post(clockTick);
    }

    @Override protected void onResume(){ super.onResume(); AlarmScheduler.scheduleAll(this); updateUi(); }
    @Override protected void onDestroy(){ clockHandler.removeCallbacks(clockTick); super.onDestroy(); }

    private void applyTheme(){
        int t = Prefs.getTheme(this);
        preview.setTheme(t);
        for (int i = 0; i < themeButtons.length; i++){
            boolean sel = (i == t);
            themeButtons[i].setBackgroundColor(sel ? 0xFF3A6EA5 : 0x33FFFFFF);
            themeButtons[i].setTextColor(sel ? 0xFFFFFFFF : 0xCCFFFFFF);
        }
        updatePreview();
    }

    private void updatePreview(){
        Calendar now = Calendar.getInstance();
        int min = now.get(Calendar.HOUR_OF_DAY)*60 + now.get(Calendar.MINUTE);
        float p; boolean sunsetMode;
        if (min < 5*60)            { sunsetMode = false; p = 0f; }
        else if (min < 12*60)      { sunsetMode = false; p = (min - 5*60)/((12-5)*60f); }
        else if (min < 17*60)      { sunsetMode = false; p = 1f; }
        else if (min < 22*60)      { sunsetMode = true;  p = (min - 17*60)/((22-17)*60f); }
        else                       { sunsetMode = false; p = 0f; }
        preview.setSunset(sunsetMode);
        preview.setProgress(Math.max(0f, Math.min(1f, p)));
    }

    private void updateUi(){
        sunriseTimeButton.setText(getString(R.string.sunrise_time, fmt(Prefs.getSunriseHour(this), Prefs.getSunriseMinute(this))));
        sunsetTimeButton.setText(getString(R.string.sunset_time, fmt(Prefs.getSunsetHour(this), Prefs.getSunsetMinute(this))));
        durationText.setText(getString(R.string.duration_minutes, Math.max(1, Prefs.getDurationSeconds(this)/60)));
        String status = AlarmScheduler.getNextAlarmText(this);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
            if (!am.canScheduleExactAlarms()) status += "\n⚠️ " + getString(R.string.exact_alarm_warning);
        }
        if (Build.VERSION.SDK_INT >= 34) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (!nm.canUseFullScreenIntent()) status += "\n⚠️ " + getString(R.string.full_screen_intent_warning);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            status += "\n⚠️ " + getString(R.string.notification_warning);
        }
        statusText.setText(status);
    }

    private String fmt(int h, int m){ return String.format(Locale.getDefault(), "%02d:%02d", h, m); }

    private void showTimePicker(final boolean sunrise){
        int h = sunrise ? Prefs.getSunriseHour(this) : Prefs.getSunsetHour(this);
        int m = sunrise ? Prefs.getSunriseMinute(this) : Prefs.getSunsetMinute(this);
        new TimePickerDialog(this, (v, sh, sm) -> {
            if (sunrise){ Prefs.setSunriseTime(this, sh, sm); if (Prefs.isSunriseEnabled(this)) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNRISE); }
            else { Prefs.setSunsetTime(this, sh, sm); if (Prefs.isSunsetEnabled(this)) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNSET); }
            updateUi();
        }, h, m, true).show();
    }

    private void startTest(String mode){
        Intent s = new Intent(this, AlarmService.class);
        s.putExtra(AlarmScheduler.EXTRA_MODE, mode);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(s); else startService(s);
        Intent a = new Intent(this, AlarmActivity.class);
        a.putExtra(AlarmScheduler.EXTRA_MODE, mode);
        a.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(a);
    }

    private void requestNotificationPermissionIfNeeded(){
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS}, REQUEST_NOTIFICATIONS);
        }
    }

    private void checkAndOpenPermissions(){
        requestNotificationPermissionIfNeeded();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
            if (!am.canScheduleExactAlarms()) {
                try { Intent i = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM); i.setData(Uri.parse("package:"+getPackageName())); startActivity(i); return; }
                catch (ActivityNotFoundException e){ Toast.makeText(this, R.string.settings_not_found, Toast.LENGTH_SHORT).show(); }
            }
        }
        if (Build.VERSION.SDK_INT >= 34) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (!nm.canUseFullScreenIntent()) {
                try { Intent i = new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT); i.setData(Uri.parse("package:"+getPackageName())); startActivity(i); return; }
                catch (ActivityNotFoundException e){ Toast.makeText(this, R.string.settings_not_found, Toast.LENGTH_SHORT).show(); }
            }
        }
        Toast.makeText(this, R.string.permissions_checked, Toast.LENGTH_SHORT).show();
        updateUi();
    }
}
EOF

cat > app/src/main/java/com/example/sunalarm/AlarmActivity.java <<'EOF'
package com.example.sunalarm;

import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.content.Intent;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.LinearInterpolator;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class AlarmActivity extends Activity {
    private final Handler clockHandler = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("EEEE, d MMMM", Locale.getDefault());

    private TextView clockView, dateView, titleView;
    private SunView sunView;
    private ProgressBar progressBar;
    private GradientDrawable sky;
    private ValueAnimator animator;
    private String mode = AlarmScheduler.MODE_SUNRISE;
    private int theme = SunTheme.HILLS;

    private final Runnable clockTick = new Runnable() {
        @Override public void run(){
            Date now = new Date();
            clockView.setText(timeFormat.format(now));
            dateView.setText(dateFormat.format(now));
            clockHandler.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState){
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1){ setShowWhenLocked(true); setTurnScreenOn(true); }
        else getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);

        setContentView(R.layout.activity_alarm);

        View root = findViewById(R.id.alarm_root);
        clockView = findViewById(R.id.alarm_clock);
        dateView = findViewById(R.id.alarm_date);
        titleView = findViewById(R.id.alarm_title);
        sunView = findViewById(R.id.alarm_sun);
        progressBar = findViewById(R.id.alarm_progress);
        Button stop = findViewById(R.id.btn_stop);
        Button snooze = findViewById(R.id.btn_snooze);

        if (getIntent() != null && getIntent().hasExtra(AlarmScheduler.EXTRA_MODE)){
            String e = getIntent().getStringExtra(AlarmScheduler.EXTRA_MODE);
            if (e != null) mode = e;
        }
        theme = Prefs.getTheme(this);
        final boolean sunset = AlarmScheduler.MODE_SUNSET.equals(mode);

        titleView.setText(sunset ? R.string.sunset_title_short : R.string.sunrise_title_short);
        sunView.setTheme(theme);
        sunView.setSunset(sunset);
        sunView.setAnimated(true);

        sky = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{SunTheme.nightTop(theme), SunTheme.nightBot(theme)});
        root.setBackground(sky);

        stop.setOnClickListener(v -> stopAlarm());
        snooze.setOnClickListener(v -> snoozeAlarm());

        startSimulation(sunset);
        clockHandler.post(clockTick);
    }

    private void startSimulation(final boolean sunset){
        long dur = Math.max(5, Prefs.getDurationSeconds(this)) * 1000L;
        final int nightTop = SunTheme.nightTop(theme), dayTop = SunTheme.dayTop(theme);
        final int nightBot = SunTheme.nightBot(theme), dayBot = SunTheme.dayBot(theme);
        final float brStart = sunset ? 1.0f : 0.01f;
        final float brEnd   = sunset ? 0.05f : 1.0f;

        WindowManager.LayoutParams lp = getWindow().getAttributes();
        lp.screenBrightness = brStart; getWindow().setAttributes(lp);

        animator = ValueAnimator.ofFloat(0f, 1f);
        animator.setDuration(dur);
        animator.setInterpolator(new LinearInterpolator());
        animator.addUpdateListener(a -> {
            float f = (float) a.getAnimatedValue();
            float daylight = sunset ? (1f - f) : f;
            int top = SunTheme.lerpColor(nightTop, dayTop, daylight);
            int bot = SunTheme.lerpColor(nightBot, dayBot, daylight);
            sky.setColors(new int[]{top, bot});
            WindowManager.LayoutParams p = getWindow().getAttributes();
            p.screenBrightness = Math.max(0.01f, Math.min(1f, brStart + (brEnd - brStart)*f));
            getWindow().setAttributes(p);
            sunView.setProgress(f);
            progressBar.setProgress((int)(f*100));
        });
        animator.start();
    }

    private void stopAlarm(){ stopService(new Intent(this, AlarmService.class)); if (animator!=null) animator.cancel(); finish(); }
    private void snoozeAlarm(){
        stopService(new Intent(this, AlarmService.class));
        if (animator!=null) animator.cancel();
        AlarmScheduler.scheduleSnooze(this, mode, 5);
        Toast.makeText(this, R.string.snoozed, Toast.LENGTH_SHORT).show();
        finish();
    }

    @Override protected void onDestroy(){ clockHandler.removeCallbacks(clockTick); if (animator!=null) animator.cancel(); super.onDestroy(); }
}
EOF

echo "gen9: OK"
