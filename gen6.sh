#!/usr/bin/env bash
set -euo pipefail

# Харденинг 1: не включать настройки будильника в системный/облачный бэкап.
sed -i 's/android:allowBackup="true"/android:allowBackup="false"/' \
  app/src/main/AndroidManifest.xml

# Харденинг 2: не писать стек-трейсы в logcat в релизной практике.
sed -i 's/e.printStackTrace();/\/\* stack trace suppressed for security \*\//g' \
  app/src/main/java/com/example/sunalarm/AlarmService.java

echo "gen6 hardening: OK"
grep -n 'allowBackup' app/src/main/AndroidManifest.xml || true
