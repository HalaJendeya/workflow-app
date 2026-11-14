# M06b — Android compatibility and Redmi 8 acceptance

Prepared 2026-11-14. No Android SDK exists in the cloud session, so **no
Android build has been run**; everything below the "Build" line must be run
on the owner's machine and Redmi 8.

## 1. Compatibility review

| Item | Project | Requirement found | Result |
|---|---|---|---|
| Flutter / Dart | 3.47.9 / 3.13 | `livekit_client` 2.13.2 and `file_picker` 13.3.3 need Flutter ≥ 3.38, Dart ≥ 3.10 | OK |
| `minSdk` | `flutter.minSdkVersion` = **24** (Android 7.0) | flutter_webrtc 21, livekit_client 21, file_picker 21, permission_handler_android **24** | OK — not raised. Redmi 8 ships Android 9 (API 28), upgradable to 10 (API 29). |
| `compileSdk` | was `flutter.compileSdkVersion` = 36 | `permission_handler_android` 14.x (required by `permission_handler` 13) compiles against **37** and its changelog says the app must too | **Fixed:** `compileSdk = maxOf(flutter.compileSdkVersion, 37)`. `targetSdk` stays 36; runtime behaviour is unchanged. |
| AGP / Gradle / Kotlin | AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, JDK 17 target; `android.newDsl=false`, `android.builtInKotlin=false` (Flutter template compatibility flags) | Plugins declare AGP 8.1–9.0 and Kotlin 2.1 in their own buildscripts; the app's root versions are used. flutter_webrtc and livekit compile Java/Kotlin for 1.8, the others for 17. | Expected to work with the template flags; **unverified**. If AGP warns that API 37 is newer than it was tested with, that is a warning, not a failure. |
| Permissions | Manifest | Microphone, camera, audio settings, network state, Bluetooth (≤ API 30) and `BLUETOOTH_CONNECT` (API 31+) | Declared. Camera features `required="false"`. Runtime: microphone (required), camera (optional), "Nearby devices" on Android 12+ (optional, for Bluetooth headsets; added in this pass). Redmi 8 (Android 9/10) has no runtime Bluetooth prompt. |
| File picker | — | System picker (SAF), no storage permission | Nothing to declare. |
| Release (R8) | Flutter enables minify + resource shrinking for release | flutter_webrtc ships keep rules; livekit_client ships none | **Added** `android/app/proguard-rules.pro` keeping `io.livekit.**` and `com.twilio.audioswitch.**` (precaution, unverified). |
| Background | — | Android 9+ blocks microphone/camera for apps in the background | Known limitation: the call keeps going only while WorkFlow is in the foreground (a foreground service would need another dependency). |
| Release signing | Debug key (template) | — | Unchanged; a release keystore is outside this milestone. |

### Build machine prerequisites

1. Android Studio → SDK Manager → install **Android SDK Platform 37**
   (and build tools it proposes), accept licences.
2. JDK 17 or newer for Gradle.
3. `flutter doctor` shows the Android toolchain ✓.

```bash
flutter clean
flutter pub get
flutter build apk --debug --dart-define=APP_MODE=api --dart-define=API_BASE_URL=https://api.workflownets.com
flutter build apk --release --dart-define=APP_MODE=api --dart-define=API_BASE_URL=https://api.workflownets.com
```

Report the first failing line of either build if one fails.

## 2. Redmi 8 tests — no backend writes

Install the API build and sign in with the client QA account. These steps
send only reads (GET) or nothing at all.

| # | Step | Expected |
|---|---|---|
| A1 | Meetings → open a waiting/live meeting → **Join meeting**. When Android asks for the **microphone**, tap **Don't allow**. | "WorkFlow needs microphone access…" with Retry. **No join request is sent** (permission comes first). |
| A2 | Retry → deny again (Android then stops asking). | "Microphone access is off… Turn it on in Settings" with **Open settings**; the button opens WorkFlow's app settings. |
| A3 | Back from the room. | Meeting details again; no camera/microphone indicator. |
| A4 | Chat → a conversation → 📎 → pick 3 images. | 3 chips above the input; nothing uploaded yet. |
| A5 | Remove one chip (✕). | It disappears. |
| A6 | 📎 again → pick 3 more (6 total). | "You can attach up to 5 files…"; the earlier chips stay. |
| A7 | Pick a file over 10 MB. | "Each file must be 10 MB or smaller." — refused before it is read. |
| A8 | Rename a `.zip` to `.png` on the phone and pick it. | "Only JPEG, PNG, GIF, WebP, PDF and plain-text files…". |
| A9 | Remove every chip without sending. | Nothing was sent (no message appears). |
| A10 | Put WorkFlow in the background for more than 1 minute, reopen. | The bell badge reloads (one notifications GET). |

## 3. Redmi 8 tests — need approval and QA resources

Each step below writes to `api.workflownets.com`. Run them only after the
owner approves the live operation and the QA resources exist (§5).

| # | Step | Expected |
|---|---|---|
| B1 | Join meeting → allow microphone, **deny camera**. | Connecting → room; you join with audio only; camera button off. |
| B2 | Tap camera → deny. | "Camera access is off. You can still take part with audio." |
| B3 | Leave → Join again → allow microphone and camera. | Your tile shows your video; status "● LIVE". |
| B4 | Second device joins the same meeting. | Its tile appears with video/initials; muted badge when muted; "2 people". |
| B5 | Mute/unmute, camera off/on. | Others hear/see the change; icons and your tile follow. |
| B6 | Airplane mode 5–10 s, then off. | "Connection lost. Reconnecting…" banner, then live again. |
| B7 | **Leave**. | Back on details; the camera/microphone indicator in the status bar goes off; the host sees you leave. Repeat with the system Back gesture. |
| B8 | Approval meeting, not on the roster → Join. | Waiting for the host; after admission, "Try joining again" connects. |
| B9 | Chat → pick 2 images + type text → Send. | Progress bar, then the message with 2 attachment chips. |
| B10 | Airplane mode → send a file. | "Not sent" with Retry/Discard; airplane off → Retry → sent once. |
| B11 | Open a received image and a text file. | In-app preview. |
| B12 | Open a received PDF → **Save to device** → choose Downloads. | "Saved."; the PDF opens from the Files app. |

## 4. Backend verification (2026-11-14)

All four client media routes are `POST` and marked MUTATING; there is no
read-only way to test them, so **none was called**.

| Route | Confirmed in the collection | Not verified on `api.workflownets.com` |
|---|---|---|
| `POST /client/meetings/{id}/media/join` `{device_id}` | 200 `data.participant.id`, `data.media.{token,url,room}`; 202 `{join_request, media: null}` in approval meetings; 422 without `device_id`; 500 when LiveKit is not configured | Whether LiveKit is configured; the `url` value; that it fully replaces `POST …/join` |
| `POST …/media/state` | `{microphone_enabled, camera_enabled}` → `data.participant.id`; 409 when not connected | Behaviour on production |
| `POST …/media/leave` `{device_id}` | → `data.id`; closes only that device's session | Behaviour on production |
| `POST …/media-token` | → `data.{token,url,room}` | Not used by the app |

## 5. What the backend team must confirm

LiveKit:
1. LiveKit is configured on `api.workflownets.com` (URL, key, secret), and
   which LiveKit server `media.url` points to (must be `wss://`).
2. `media/join` performs the meeting join itself (the app no longer calls
   `POST …/join` before it), and its 202 rule matches `join`.
3. Token lifetime, and whether a long meeting needs a new token
   (`media-token`) — the app does not refresh it today.
4. What the server does with a device session left open (app killed): does
   it time out, and after how long?
5. A client route to read or withdraw its own join request (employees have
   `GET/DELETE …/join-request`).

Notifications:
1. The list of `type` (and `category`) values.
2. For each type, the target: `subject {type, id}` or an equivalent route,
   and which resources a client may open from it.
3. Remove the outdated "no Notifications API" line (collection §7).

Attachments:
1. The attachment object in message rows (`file_name`, `mime_type`,
   `size`) — today only `id` is implied.

## 6. QA resources needed

- A client QA account **in a company** with: a group conversation with
  attachments (image, text, PDF); an `approval` meeting with a host on a
  second device; a live meeting the client may join.
- Owner approval for the live writes in §3 on `api.workflownets.com`, or a
  staging host with LiveKit configured.
