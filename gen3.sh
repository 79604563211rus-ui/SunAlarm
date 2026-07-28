#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/com/example/sunalarm

cat > app/src/main/java/com/example/sunalarm/SunView.java <<'EOF'
package com.example.sunalarm;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;

public class SunView extends View {

    private float progress = 0f;
    private boolean sunset = false;

    private final Paint glowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint corePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint horizonPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public SunView(Context context) { super(context); init(); }
    public SunView(Context context, AttributeSet attrs) { super(context, attrs); init(); }
    public SunView(Context context, AttributeSet attrs, int defStyleAttr) { super(context, attrs, defStyleAttr); init(); }

    private void init() {
        horizonPaint.setColor(0x40FFFFFF);
        horizonPaint.setStrokeWidth(2f);
    }

    public void setSunset(boolean sunset) { this.sunset = sunset; }

    public void setProgress(float progress) {
        this.progress = Math.max(0f, Math.min(1f, progress));
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        int w = getWidth();
        int h = getHeight();
        if (w == 0 || h == 0) return;

        float horizonY = h * 0.78f;

        float t = sunset ? (1f - progress) : progress;
        float startY = h * 1.05f;
        float endY = h * 0.16f;
        float sunY = startY + (endY - startY) * t;
        float sunX = w / 2f;

        float radius = Math.min(w, h) * 0.09f;
        float glowRadius = radius * 4.5f;

        float denom = horizonY - endY;
        float warmth = 1f - Math.max(0f, Math.min(1f, (horizonY - sunY) / denom));
        int coreColor = lerpColor(0xFFFFF3C4, 0xFFFFB74D, warmth);
        int glowColor = lerpColor(0x66FFD54F, 0x8CFF7043, warmth);

        glowPaint.setShader(new RadialGradient(sunX, sunY, glowRadius,
                new int[]{glowColor, withAlpha(glowColor, 0.3f), 0x00000000},
                new float[]{0f, 0.45f, 1f}, Shader.TileMode.CLAMP));
        canvas.drawCircle(sunX, sunY, glowRadius, glowPaint);

        corePaint.setColor(coreColor);
        canvas.drawCircle(sunX, sunY, radius, corePaint);

        canvas.drawLine(0f, horizonY, w, horizonY, horizonPaint);
    }

    private static int lerpColor(int c1, int c2, float f) {
        return Color.argb(
                (int) (Color.alpha(c1) + (Color.alpha(c2) - Color.alpha(c1)) * f),
                (int) (Color.red(c1) + (Color.red(c2) - Color.red(c1)) * f),
                (int) (Color.green(c1) + (Color.green(c2) - Color.green(c1)) * f),
                (int) (Color.blue(c1) + (Color.blue(c2) - Color.blue(c1)) * f));
    }

    private static int withAlpha(int color, float scale) {
        return Color.argb((int) (Color.alpha(color) * scale),
                Color.red(color), Color.green(color), Color.blue(color));
    }
}
EOF

cat > app/src/main/java/com/example/sunalarm/AlarmActivity.java <<'EOF'
package com.example.sunalarm;

import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
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

    private final Runnable clockTick = new Runnable() {
        @Override
        public void run() {
            Date now = new Date();
            clockView.setText(timeFormat.format(now));
            dateView.setText(dateFormat.format(now));
            clockHandler.postDelayed(this, 1000);
        }
    };

    private TextView clockView;
    private TextView dateView;
    private TextView titleView;
    private SunView sunView;
    private ProgressBar progressBar;
    private GradientDrawable sky;
    private ValueAnimator animator;
    private String mode = AlarmScheduler.MODE_SUNRISE;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);

        setContentView(R.layout.activity_alarm);

        View root = findViewById(R.id.alarm_root);
        clockView = findViewById(R.id.alarm_clock);
        dateView = findViewById(R.id.alarm_date);
        titleView = findViewById(R.id.alarm_title);
        sunView = findViewById(R.id.alarm_sun);
        progressBar = findViewById(R.id.alarm_progress);
        Button stopButton = findViewById(R.id.btn_stop);
        Button snoozeButton = findViewById(R.id.btn_snooze);

        if (getIntent() != null && getIntent().hasExtra(AlarmScheduler.EXTRA_MODE)) {
            String extra = getIntent().getStringExtra(AlarmScheduler.EXTRA_MODE);
            if (extra != null) mode = extra;
        }

        final boolean sunset = AlarmScheduler.MODE_SUNSET.equals(mode);
        titleView.setText(sunset ? R.string.sunset_title_short : R.string.sunrise_title_short);
        sunView.setSunset(sunset);

        sky = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                sunset ? new int[]{Color.parseColor("#7EC3E0"), Color.parseColor("#FFD180")}
                       : new int[]{Color.parseColor("#061024"), Color.parseColor("#23304F")});
        root.setBackground(sky);

        stopButton.setOnClickListener(v -> stopAlarm());
        snoozeButton.setOnClickListener(v -> snoozeAlarm());

        startSimulation(sunset);
        clockHandler.post(clockTick);
    }

    private void startSimulation(final boolean sunset) {
        int durationSeconds = Prefs.getDurationSeconds(this);
        long durationMs = Math.max(5, durationSeconds) * 1000L;

        final int topStart = sunset ? Color.parseColor("#7EC3E0") : Color.parseColor("#061024");
        final int topEnd   = sunset ? Color.parseColor("#061024") : Color.parseColor("#7EC3E0");
        final int botStart = sunset ? Color.parseColor("#FFD180") : Color.parseColor("#23304F");
        final int botEnd   = sunset ? Color.parseColor("#23304F") : Color.parseColor("#FFD180");
        final float brStart = sunset ? 1.0f : 0.01f;
        final float brEnd   = sunset ? 0.05f : 1.0f;

        WindowManager.LayoutParams lp = getWindow().getAttributes();
        lp.screenBrightness = brStart;
        getWindow().setAttributes(lp);

        animator = ValueAnimator.ofFloat(0f, 1f);
        animator.setDuration(durationMs);
        animator.setInterpolator(new LinearInterpolator());
        animator.addUpdateListener(animation -> {
            float f = (float) animation.getAnimatedValue();

            int top = (int) new ArgbEvaluator().evaluate(f, topStart, topEnd);
            int bot = (int) new ArgbEvaluator().evaluate(f, botStart, botEnd);
            sky.setColors(new int[]{top, bot});

            WindowManager.LayoutParams p = getWindow().getAttributes();
            p.screenBrightness = Math.max(0.01f, Math.min(1f, brStart + (brEnd - brStart) * f));
            getWindow().setAttributes(p);

            sunView.setProgress(f);
            progressBar.setProgress((int) (f * 100));
        });
        animator.start();
    }

    private void stopAlarm() {
        stopService(new Intent(this, AlarmService.class));
        if (animator != null) animator.cancel();
        finish();
    }

    private void snoozeAlarm() {
        stopService(new Intent(this, AlarmService.class));
        if (animator != null) animator.cancel();
        AlarmScheduler.scheduleSnooze(this, mode, 5);
        Toast.makeText(this, R.string.snoozed, Toast.LENGTH_SHORT).show();
        finish();
    }

    @Override
    protected void onDestroy() {
        clockHandler.removeCallbacks(clockTick);
        if (animator != null) animator.cancel();
        super.onDestroy();
    }
}
EOF

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
import java.util.Date;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final int REQUEST_NOTIFICATIONS = 1;

    private final Handler clockHandler = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("EEEE, d MMMM", Locale.getDefault());

    private final Runnable clockTick = new Runnable() {
        @Override
        public void run() {
            Date now = new Date();
            mainClock.setText(timeFormat.format(now));
            mainDate.setText(dateFormat.format(now));
            clockHandler.postDelayed(this, 1000);
        }
    };

    private TextView mainClock;
    private TextView mainDate;
    private TextView statusText;
    private TextView durationText;
    private Button sunriseTimeButton;
    private Button sunsetTimeButton;
    private Button testSunriseButton;
    private Button testSunsetButton;
    private Button permissionsButton;
    private Switch sunriseSwitch;
    private Switch sunsetSwitch;
    private SeekBar durationSeekBar;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

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

        durationSeekBar.setMax(9);

        sunriseSwitch.setChecked(Prefs.isSunriseEnabled(this));
        sunsetSwitch.setChecked(Prefs.isSunsetEnabled(this));
        int durationSeconds = Prefs.getDurationSeconds(this);
        durationSeekBar.setProgress(Math.max(0, Math.min(9, durationSeconds / 60 - 1)));

        sunriseTimeButton.setOnClickListener(v -> showTimePicker(true));
        sunsetTimeButton.setOnClickListener(v -> showTimePicker(false));

        sunriseSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            Prefs.setSunriseEnabled(this, isChecked);
            if (isChecked) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNRISE);
            else AlarmScheduler.cancel(this, AlarmScheduler.MODE_SUNRISE);
            updateUi();
        });

        sunsetSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            Prefs.setSunsetEnabled(this, isChecked);
            if (isChecked) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNSET);
            else AlarmScheduler.cancel(this, AlarmScheduler.MODE_SUNSET);
            updateUi();
        });

        durationSeekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                int minutes = progress + 1;
                Prefs.setDurationSeconds(MainActivity.this, minutes * 60);
                durationText.setText(getString(R.string.duration_minutes, minutes));
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        testSunriseButton.setOnClickListener(v -> startAlarmTest(AlarmScheduler.MODE_SUNRISE));
        testSunsetButton.setOnClickListener(v -> startAlarmTest(AlarmScheduler.MODE_SUNSET));
        permissionsButton.setOnClickListener(v -> checkAndOpenPermissions());

        requestNotificationPermissionIfNeeded();
        clockHandler.post(clockTick);
    }

    @Override
    protected void onResume() {
        super.onResume();
        AlarmScheduler.scheduleAll(this);
        updateUi();
    }

    @Override
    protected void onDestroy() {
        clockHandler.removeCallbacks(clockTick);
        super.onDestroy();
    }

    private void updateUi() {
        sunriseTimeButton.setText(getString(R.string.sunrise_time,
                formatTime(Prefs.getSunriseHour(this), Prefs.getSunriseMinute(this))));
        sunsetTimeButton.setText(getString(R.string.sunset_time,
                formatTime(Prefs.getSunsetHour(this), Prefs.getSunsetMinute(this))));

        int minutes = Math.max(1, Prefs.getDurationSeconds(this) / 60);
        durationText.setText(getString(R.string.duration_minutes, minutes));

        String status = AlarmScheduler.getNextAlarmText(this);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
            if (!am.canScheduleExactAlarms()) {
                status += "\n⚠️ " + getString(R.string.exact_alarm_warning);
            }
        }
        if (Build.VERSION.SDK_INT >= 34) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (!nm.canUseFullScreenIntent()) {
                status += "\n⚠️ " + getString(R.string.full_screen_intent_warning);
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            status += "\n⚠️ " + getString(R.string.notification_warning);
        }
        statusText.setText(status);
    }

    private String formatTime(int hour, int minute) {
        return String.format(Locale.getDefault(), "%02d:%02d", hour, minute);
    }

    private void showTimePicker(final boolean sunrise) {
        int hour = sunrise ? Prefs.getSunriseHour(this) : Prefs.getSunsetHour(this);
        int minute = sunrise ? Prefs.getSunriseMinute(this) : Prefs.getSunsetMinute(this);

        new TimePickerDialog(this, (view, selectedHour, selectedMinute) -> {
            if (sunrise) {
                Prefs.setSunriseTime(this, selectedHour, selectedMinute);
                if (Prefs.isSunriseEnabled(this)) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNRISE);
            } else {
                Prefs.setSunsetTime(this, selectedHour, selectedMinute);
                if (Prefs.isSunsetEnabled(this)) AlarmScheduler.schedule(this, AlarmScheduler.MODE_SUNSET);
            }
            updateUi();
        }, hour, minute, true).show();
    }

    private void startAlarmTest(String mode) {
        Intent serviceIntent = new Intent(this, AlarmService.class);
        serviceIntent.putExtra(AlarmScheduler.EXTRA_MODE, mode);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(serviceIntent);
        else startService(serviceIntent);

        Intent activityIntent = new Intent(this, AlarmActivity.class);
        activityIntent.putExtra(AlarmScheduler.EXTRA_MODE, mode);
        activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(activityIntent);
    }

    private void requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},
                    REQUEST_NOTIFICATIONS);
        }
    }

    private void checkAndOpenPermissions() {
        requestNotificationPermissionIfNeeded();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
            if (!am.canScheduleExactAlarms()) {
                try {
                    Intent intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                    return;
                } catch (ActivityNotFoundException ignored) {
                    Toast.makeText(this, R.string.settings_not_found, Toast.LENGTH_SHORT).show();
                }
            }
        }

        if (Build.VERSION.SDK_INT >= 34) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (!nm.canUseFullScreenIntent()) {
                try {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                    return;
                } catch (ActivityNotFoundException ignored) {
                    Toast.makeText(this, R.string.settings_not_found, Toast.LENGTH_SHORT).show();
                }
            }
        }

        Toast.makeText(this, R.string.permissions_checked, Toast.LENGTH_SHORT).show();
        updateUi();
    }
}
EOF

echo "gen3: OK"
