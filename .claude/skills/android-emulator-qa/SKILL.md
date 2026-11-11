---
name: android-emulator-qa
description: Drive the WorkFlow app on a real Android emulator or device through adb - install, launch, tap through flows, capture screenshots and logcat, and report defects. Detects first whether adb, an emulator, and KVM exist; when they don't (cloud sessions), says so plainly and falls back to widget tests plus a headless-Chromium render of the web build, never claiming emulator coverage. Use when asked to test on an emulator, device, or phone.
argument-hint: "<flows to exercise, e.g. 'employee tasks + sprint'>"
allowed-tools: Bash(.claude/skills/android-emulator-qa/scripts/env_check.sh), Bash(adb *), Bash(flutter devices*), Bash(flutter emulators*)
---

# Android emulator QA

Flows to cover: **$ARGUMENTS**. English, light mode.

## 0. Detect: never assume or fake

```bash
.claude/skills/android-emulator-qa/scripts/env_check.sh
```

- Exit 0 means a device is available. Go to section 1.
- Exit 2 means no device. Go to section 2, and the final report must say: "Emulator testing not performed: <reason from env_check>."

Don't install the Android SDK or create AVDs without the owner's approval. They're multi-GB downloads, and the cloud container has no `/dev/kvm`, so an emulator can't boot there anyway.

## 1. With a device or emulator

```bash
flutter emulators                       # list AVDs
flutter emulators --launch <avd_id>     # boot (bounded: wait with adb wait-for-device, timeout 300)
flutter devices
flutter run -d <id> --dart-define=APP_MODE=mock          # demo data, no server
# api mode only with an .env the owner provided:  --dart-define-from-file=.env
```

Drive and capture:

```bash
adb shell wm size                                    # confirm the viewport under test
adb exec-out screencap -p > "${QA_OUT:-/tmp/workflow-qa}/emu/<step>.png"
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml "${QA_OUT:-/tmp/workflow-qa}/emu/"
adb shell input tap <x> <y>        # coordinates from the ui.xml bounds
adb shell input text 'hello'       # keyboard up: check the field and send button stay visible
adb shell input keyevent 4         # system back
adb logcat -d -s flutter:V *:E | tail -200
adb shell wm size 720x1440; adb shell wm density 320   # emulate a small phone; reset with `wm size reset`
```

For each flow, check:
- no overflow stripes or clipped text
- the keyboard doesn't cover the focused field
- the actions above the floating navigation are reachable
- system back behaves
- no red-screen errors and no `E/flutter` lines in logcat

Every defect found gets a regression widget test (pattern: `test/features/emulator_findings_test.dart`) before or with its fix.

**Safety:** in api mode, only read-only screens are tested against a real server. Don't submit forms, delete, pay, or send messages against a real server without explicit owner approval.

## 2. Fallback without a device

1. Widget coverage through `/flutter-responsive-qa` (viewports, text scale, keyboard).
2. Web render check of the mock build in headless Chromium:
   ```bash
   timeout 900 flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock
   node .claude/skills/android-emulator-qa/scripts/web_render.mjs build/web "${QA_OUT:-/tmp/workflow-qa}/web" /
   ```
   This screenshots each route at the four phone viewports and fails on page or console errors. Look at the PNGs with Read.
3. Report the remaining risk: native keyboard, system back gesture, status-bar insets, and real-device performance were **not** verified. List the exact checks the owner should run on their phone (Redmi 8).
