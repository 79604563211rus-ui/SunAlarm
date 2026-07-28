#!/usr/bin/env bash
set -euo pipefail
mkdir -p app/src/main/res/values app/src/main/res/layout

cat > app/src/main/java/com/example/sunalarm/Prefs.java <<'EOF'
package com.example.sunalarm;

import android.content.Context;
import android.content.SharedPreferences;

public final class Prefs {
    private static final String NAME = "sun_alarm_prefs";
    private static final String K_SH = "sunrise_hour", K_SM = "sunrise_minute", K_SE = "sunrise_enabled";
    private static final String K_NH = "sunset_hour",  K_NM = "sunset_minute",  K_NE = "sunset_enabled";
    private static final String K_DUR = "duration_seconds";
    private static final String K_THEME = "theme";

    private Prefs() {}
    private static SharedPreferences p(Context c){ return c.getApplicationContext().getSharedPreferences(NAME, Context.MODE_PRIVATE); }

    public static int getSunriseHour(Context c){ return p(c).getInt(K_SH, 7); }
    public static int getSunriseMinute(Context c){ return p(c).getInt(K_SM, 0); }
    public static boolean isSunriseEnabled(Context c){ return p(c).getBoolean(K_SE, false); }
    public static void setSunriseTime(Context c, int h, int m){ p(c).edit().putInt(K_SH,h).putInt(K_SM,m).apply(); }
    public static void setSunriseEnabled(Context c, boolean e){ p(c).edit().putBoolean(K_SE,e).apply(); }

    public static int getSunsetHour(Context c){ return p(c).getInt(K_NH, 21); }
    public static int getSunsetMinute(Context c){ return p(c).getInt(K_NM, 0); }
    public static boolean isSunsetEnabled(Context c){ return p(c).getBoolean(K_NE, false); }
    public static void setSunsetTime(Context c, int h, int m){ p(c).edit().putInt(K_NH,h).putInt(K_NM,m).apply(); }
    public static void setSunsetEnabled(Context c, boolean e){ p(c).edit().putBoolean(K_NE,e).apply(); }

    public static int getDurationSeconds(Context c){ return p(c).getInt(K_DUR, 60); }
    public static void setDurationSeconds(Context c, int s){ p(c).edit().putInt(K_DUR,s).apply(); }

    public static int getTheme(Context c){ return p(c).getInt(K_THEME, SunTheme.HILLS); }
    public static void setTheme(Context c, int t){ p(c).edit().putInt(K_THEME,t).apply(); }
}
EOF

cat > app/src/main/res/values/strings.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Солнечный будильник</string>
    <string name="sunrise_label">Восход</string>
    <string name="sunset_label">Закат</string>
    <string name="sunrise_title_short">РАССВЕТ</string>
    <string name="sunset_title_short">ЗАКАТ</string>
    <string name="stop">Стоп</string>
    <string name="snooze">Отложить 5 мин</string>
    <string name="snoozed">Повторный сигнал через 5 минут</string>
    <string name="sunrise_alarm_title">Будильник: восход</string>
    <string name="sunset_alarm_title">Будильник: закат</string>
    <string name="sun_simulation">Имитация света восхода/заката</string>
    <string name="alarm_channel_name">Будильники</string>
    <string name="sunrise_time">Восход: %1$s</string>
    <string name="sunset_time">Закат: %1$s</string>
    <string name="duration_title">Длительность имитации</string>
    <string name="duration_minutes">Длительность: %1$d мин</string>
    <string name="status_none">Будильники выключены</string>
    <string name="status_next">Следующий: %1$s в %2$s</string>
    <string name="test_sunrise">Тест восхода</string>
    <string name="test_sunset">Тест заката</string>
    <string name="check_permissions">Проверить разрешения</string>
    <string name="exact_alarm_warning">Нет разрешения на точные будильники. Нажмите «Проверить разрешения».</string>
    <string name="full_screen_intent_warning">Нет разрешения на полноэкранные уведомления. Нажмите «Проверить разрешения».</string>
    <string name="notification_warning">Нет разрешения на уведомления. Нажмите «Проверить разрешения».</string>
    <string name="settings_not_found">Не удалось открыть настройки разрешений</string>
    <string name="permissions_checked">Проверка разрешений выполнена</string>
    <string name="theme_title">Тема сцены</string>
    <string name="theme_hills">Горы</string>
    <string name="theme_sea">Море</string>
    <string name="theme_desert">Пустыня</string>
    <string name="theme_polar">Полярный</string>
</resources>
EOF

cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#0E1626">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:padding="20dp">

        <com.example.sunalarm.SunView
            android:id="@+id/main_preview"
            android:layout_width="match_parent"
            android:layout_height="170dp"
            android:background="#061024" />

        <TextView
            android:id="@+id/main_clock"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="14dp"
            android:fontFamily="sans-serif-thin"
            android:includeFontPadding="false"
            android:textColor="#FFFFFF"
            android:textSize="56sp" />

        <TextView
            android:id="@+id/main_date"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans-serif-medium"
            android:textColor="#9FB0CC"
            android:textSize="15sp" />

        <TextView
            android:id="@+id/status_text"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="14dp"
            android:textColor="#C7D3E8"
            android:textSize="16sp" />

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="20dp"
            android:text="@string/theme_title"
            android:textColor="#FFFFFF"
            android:textSize="16sp"
            android:textStyle="bold" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:orientation="horizontal">

            <Button android:id="@+id/theme_hills"  android:layout_width="0dp" android:layout_height="44dp" android:layout_weight="1" android:text="@string/theme_hills"  android:textColor="#CCFFFFFF" />
            <Button android:id="@+id/theme_sea"    android:layout_width="0dp" android:layout_height="44dp" android:layout_weight="1" android:layout_marginStart="6dp" android:text="@string/theme_sea"    android:textColor="#CCFFFFFF" />
            <Button android:id="@+id/theme_desert" android:layout_width="0dp" android:layout_height="44dp" android:layout_weight="1" android:layout_marginStart="6dp" android:text="@string/theme_desert" android:textColor="#CCFFFFFF" />
            <Button android:id="@+id/theme_polar"  android:layout_width="0dp" android:layout_height="44dp" android:layout_weight="1" android:layout_marginStart="6dp" android:text="@string/theme_polar"  android:textColor="#CCFFFFFF" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="20dp"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="@string/sunrise_label" android:textColor="#FFFFFF" android:textSize="18sp" android:textStyle="bold" />
            <Button android:id="@+id/sunrise_time_button" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="@string/sunrise_time" />
            <Switch android:id="@+id/sunrise_switch" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginStart="8dp" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="@string/sunset_label" android:textColor="#FFFFFF" android:textSize="18sp" android:textStyle="bold" />
            <Button android:id="@+id/sunset_time_button" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="@string/sunset_time" />
            <Switch android:id="@+id/sunset_switch" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginStart="8dp" />
        </LinearLayout>

        <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginTop="20dp" android:text="@string/duration_title" android:textColor="#FFFFFF" android:textSize="16sp" android:textStyle="bold" />
        <SeekBar android:id="@+id/duration_seekbar" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" />
        <TextView android:id="@+id/duration_text" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginTop="4dp" android:textColor="#C7D3E8" android:textSize="16sp" />

        <Button android:id="@+id/test_sunrise_button" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="20dp" android:text="@string/test_sunrise" />
        <Button android:id="@+id/test_sunset_button"  android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:text="@string/test_sunset" />
        <Button android:id="@+id/permissions_button"  android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:text="@string/check_permissions" />
    </LinearLayout>
</ScrollView>
EOF

echo "gen8: OK"
