#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/com/example/sunalarm
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/values

cat > settings.gradle <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "SunAlarm"
include ':app'
EOF

cat > build.gradle <<'EOF'
plugins {
    id 'com.android.application' version '8.1.0' apply false
}

tasks.register('clean', Delete) {
    delete rootProject.buildDir
}
EOF

cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
android.enableJetifier=false
EOF

cat > app/build.gradle <<'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.example.sunalarm'
    compileSdk 34

    defaultConfig {
        applicationId "com.example.sunalarm"
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
}
EOF

cat > app/proguard-rules.pro <<'EOF'
# empty
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

    <application
        android:allowBackup="true"
        android:icon="@android:drawable/ic_dialog_time"
        android:label="@string/app_name"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <activity
            android:name=".AlarmActivity"
            android:exported="false"
            android:excludeFromRecents="true"
            android:launchMode="singleInstance"
            android:taskAffinity=""
            android:showWhenLocked="true"
            android:turnScreenOn="true"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:theme="@android:style/Theme.Material.NoActionBar" />

        <receiver
            android:name=".AlarmReceiver"
            android:exported="false" />

        <receiver
            android:name=".BootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>

        <service
            android:name=".AlarmService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback" />

    </application>

</manifest>
EOF

cat > app/src/main/java/com/example/sunalarm/Prefs.java <<'EOF'
package com.example.sunalarm;

import android.content.Context;
import android.content.SharedPreferences;

public final class Prefs {
    private static final String NAME = "sun_alarm_prefs";

    private static final String KEY_SUNRISE_HOUR = "sunrise_hour";
    private static final String KEY_SUNRISE_MINUTE = "sunrise_minute";
    private static final String KEY_SUNRISE_ENABLED = "sunrise_enabled";

    private static final String KEY_SUNSET_HOUR = "sunset_hour";
    private static final String KEY_SUNSET_MINUTE = "sunset_minute";
    private static final String KEY_SUNSET_ENABLED = "sunset_enabled";

    private static final String KEY_DURATION_SECONDS = "duration_seconds";

    private Prefs() {
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(NAME, Context.MODE_PRIVATE);
    }

    public static int getSunriseHour(Context context) {
        return prefs(context).getInt(KEY_SUNRISE_HOUR, 7);
    }

    public static int getSunriseMinute(Context context) {
        return prefs(context).getInt(KEY_SUNRISE_MINUTE, 0);
    }

    public static boolean isSunriseEnabled(Context context) {
        return prefs(context).getBoolean(KEY_SUNRISE_ENABLED, false);
    }

    public static void setSunriseTime(Context context, int hour, int minute) {
        prefs(context).edit()
                .putInt(KEY_SUNRISE_HOUR, hour)
                .putInt(KEY_SUNRISE_MINUTE, minute)
                .apply();
    }

    public static void setSunriseEnabled(Context context, boolean enabled) {
        prefs(context).edit()
                .putBoolean(KEY_SUNRISE_ENABLED, enabled)
                .apply();
    }

    public static int getSunsetHour(Context context) {
        return prefs(context).getInt(KEY_SUNSET_HOUR, 21);
    }

    public static int getSunsetMinute(Context context) {
        return prefs(context).getInt(KEY_SUNSET_MINUTE, 0);
    }

    public static boolean isSunsetEnabled(Context context) {
        return prefs(context).getBoolean(KEY_SUNSET_ENABLED, false);
    }

    public static void setSunsetTime(Context context, int hour, int minute) {
        prefs(context).edit()
                .putInt(KEY_SUNSET_HOUR, hour)
                .putInt(KEY_SUNSET_MINUTE, minute)
                .apply();
    }

    public static void setSunsetEnabled(Context context, boolean enabled) {
        prefs(context).edit()
                .putBoolean(KEY_SUNSET_ENABLED, enabled)
                .apply();
    }

    public static int getDurationSeconds(Context context) {
        return prefs(context).getInt(KEY_DURATION_SECONDS, 60);
    }

    public static void setDurationSeconds(Context context, int seconds) {
        prefs(context).edit()
                .putInt(KEY_DURATION_SECONDS, seconds)
                .apply();
    }
}
EOF

cat > app/src/main/java/com/example/sunalarm/BootReceiver.java <<'EOF'
package com.example.sunalarm;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            return;
        }

        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
            AlarmScheduler.scheduleAll(context);
        }
    }
}
EOF

echo "gen1: OK"
