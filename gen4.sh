#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/values

cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#F4F7FB">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:padding="20dp">

        <TextView
            android:id="@+id/main_clock"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans-serif-thin"
            android:includeFontPadding="false"
            android:textColor="#10233F"
            android:textSize="58sp" />

        <TextView
            android:id="@+id/main_date"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans-serif-medium"
            android:textColor="#5A6B85"
            android:textSize="15sp" />

        <TextView
            android:id="@+id/status_text"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="14dp"
            android:textColor="#33445E"
            android:textSize="16sp" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="22dp"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="@string/sunrise_label"
                android:textColor="#10233F"
                android:textSize="18sp"
                android:textStyle="bold" />

            <Button
                android:id="@+id/sunrise_time_button"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="@string/sunrise_time" />

            <Switch
                android:id="@+id/sunrise_switch"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="@string/sunset_label"
                android:textColor="#10233F"
                android:textSize="18sp"
                android:textStyle="bold" />

            <Button
                android:id="@+id/sunset_time_button"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="@string/sunset_time" />

            <Switch
                android:id="@+id/sunset_switch"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp" />
        </LinearLayout>

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="22dp"
            android:text="@string/duration_title"
            android:textColor="#10233F"
            android:textSize="18sp"
            android:textStyle="bold" />

        <SeekBar
            android:id="@+id/duration_seekbar"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp" />

        <TextView
            android:id="@+id/duration_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="4dp"
            android:textColor="#33445E"
            android:textSize="16sp" />

        <Button
            android:id="@+id/test_sunrise_button"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="22dp"
            android:text="@string/test_sunrise" />

        <Button
            android:id="@+id/test_sunset_button"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:text="@string/test_sunset" />

        <Button
            android:id="@+id/permissions_button"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:text="@string/check_permissions" />

    </LinearLayout>

</ScrollView>
EOF

cat > app/src/main/res/layout/activity_alarm.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/alarm_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <com.example.sunalarm.SunView
        android:id="@+id/alarm_sun"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center_horizontal"
        android:orientation="vertical"
        android:padding="28dp">

        <TextView
            android:id="@+id/alarm_title"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="44dp"
            android:letterSpacing="0.35"
            android:textColor="#B3FFFFFF"
            android:textSize="15sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/alarm_clock"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans-serif-thin"
            android:includeFontPadding="false"
            android:textColor="#FFFFFFFF"
            android:textSize="92sp" />

        <TextView
            android:id="@+id/alarm_date"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:fontFamily="sans-serif-medium"
            android:textColor="#CCFFFFFF"
            android:textSize="17sp" />

        <Space
            android:layout_width="0dp"
            android:layout_height="0dp"
            android:layout_weight="1" />

        <ProgressBar
            android:id="@+id/alarm_progress"
            style="?android:attr/progressBarStyleHorizontal"
            android:layout_width="240dp"
            android:layout_height="wrap_content"
            android:max="100"
            android:progress="0"
            android:progressBackgroundTint="#33FFFFFF"
            android:progressTint="#E6FFFFFF" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="24dp"
            android:layout_marginBottom="30dp"
            android:gravity="center"
            android:orientation="horizontal">

            <Button
                android:id="@+id/btn_snooze"
                android:layout_width="wrap_content"
                android:layout_height="52dp"
                android:background="@drawable/btn_snooze"
                android:paddingStart="22dp"
                android:paddingEnd="22dp"
                android:text="@string/snooze"
                android:textColor="#FFFFFFFF" />

            <Button
                android:id="@+id/btn_stop"
                android:layout_width="wrap_content"
                android:layout_height="52dp"
                android:layout_marginStart="14dp"
                android:background="@drawable/btn_stop"
                android:paddingStart="30dp"
                android:paddingEnd="30dp"
                android:text="@string/stop"
                android:textColor="#10233F"
                android:textStyle="bold" />
        </LinearLayout>

    </LinearLayout>

</FrameLayout>
EOF

cat > app/src/main/res/drawable/btn_stop.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FFFFFF" />
    <corners android:radius="26dp" />
</shape>
EOF

cat > app/src/main/res/drawable/btn_snooze.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#22FFFFFF" />
    <stroke android:width="1dp" android:color="#66FFFFFF" />
    <corners android:radius="26dp" />
</shape>
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
</resources>
EOF

echo "gen4: OK"
