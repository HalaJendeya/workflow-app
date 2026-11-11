#!/usr/bin/env bash
# Reports which QA tools this machine really has. Never installs anything.
# Exit code: 0 when an Android device/emulator is usable, 2 when not.
set -u
[ -d /opt/fl/flutter/bin ] && export PATH=/opt/fl/flutter/bin:$PATH
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$sdk" ] && export PATH="$sdk/platform-tools:$sdk/emulator:$PATH"

say() { printf '%-16s %s\n' "$1" "$2"; }
say flutter "$(command -v flutter >/dev/null && flutter --version 2>/dev/null | head -1 || echo MISSING)"
say android-sdk "${sdk:-MISSING (ANDROID_HOME/ANDROID_SDK_ROOT unset)}"
say adb "$(command -v adb || echo MISSING)"
say emulator "$(command -v emulator || echo MISSING)"
say kvm "$([ -e /dev/kvm ] && echo present || echo MISSING)"
say chromium "$([ -x /opt/pw-browsers/chromium ] || ls -d /opt/pw-browsers/chromium* >/dev/null 2>&1 && echo present || echo MISSING)"

usable=0
if command -v adb >/dev/null; then
  devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  say adb-devices "${devices:-none}"
  [ -n "$devices" ] && usable=1
fi
if command -v emulator >/dev/null; then
  say avds "$(emulator -list-avds 2>/dev/null | paste -sd, - || true)"
fi
if [ $usable = 1 ]; then echo "RESULT: android device available"; exit 0; fi
echo "RESULT: no android device -- use widget tests + web render fallback, and say so in the report"
exit 2
