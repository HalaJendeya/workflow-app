[README.md](https://github.com/user-attachments/files/35081535/README.md)
# WorkFlow

**WorkFlow** is a Flutter mobile application for organizing projects, tasks, team communication, meetings, and work tracking in one place. The app supports role-based experiences for **Clients** and **Employees**, including project leads.

> **Development status:** WorkFlow is under active development and testing. Implemented features should not be assumed production-ready until their role-specific API flows, permissions, and end-to-end scenarios have been verified.

## Overview

WorkFlow brings together day-to-day project collaboration and management through a unified mobile experience. The application supports English and Arabic, right-to-left (RTL) layouts, and light and dark themes.

### User experiences

| Role | Focus |
| --- | --- |
| **Client** | View company and project information, follow progress, and access relevant communication and financial workflows where authorized. |
| **Employee** | View assigned tasks, track work, access projects and sprints, communicate with teammates, and review meetings, timesheets, and reports. |
| **Project Lead** | Access team-scoped task views and task-management actions when authorized by the backend. |

Access to data and actions depends on the authenticated account's permissions and company/project membership.

## Features

### Shared experience

- Authentication and role-aware navigation
- Company-scoped API integration
- Dashboard and notification views
- Conversations and supported attachments
- Meeting information and supported participation flows
- Arabic and English localization, including RTL layouts
- System, light, and dark appearance options
- Responsive layouts and user-friendly loading, empty, and error states

### Employee experience

- **Tasks:** My Tasks, permission-aware Team Tasks, task details, search, and combined status/project/priority/sort filters
- **Projects and sprints:** Project information, sprint views, and task boards
- **Task management:** Project-member-based assignee selection and lead actions where permitted
- **Timesheets:** Monthly records, details, and work summaries
- **My Report:** Monthly and yearly summaries of tasks and work activity
- **Notifications:** Inbox filters and navigation to supported related content
- **Meetings:** Meeting details, join-by-code lookup, and join-request visibility
- **CSV exports:** Supported task, project, timesheet, and backlog exports

### Client experience

Client-facing modules include company and project information, dashboard views, communications, notifications, and relevant financial information. **Client live API acceptance is still in progress**; available screens and actions depend on the API and account permissions.

## Technology

- **Framework:** Flutter / Dart
- **State management:** Riverpod
- **Navigation:** go_router
- **Backend:** REST API
- **Real-time meetings:** LiveKit integration
- **Target platform:** Android, with Flutter web builds used in development and testing

## Getting started

### Prerequisites

- Flutter SDK and Dart (use versions compatible with `pubspec.yaml`)
- Android Studio or an Android SDK installation
- An Android emulator or connected Android device
- Access to a valid WorkFlow test account for API-mode workflows

### Clone and install

```bash
git clone https://github.com/HalaJendeya/workflow-app.git
cd workflow-app
git checkout feat/m01-batch2-emulator-fixes
flutter pub get
```

### Run the app

For the API-connected development environment:

```bash
flutter run \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=https://api.workflownets.com \
  --dart-define=BUILD_SHA=local
```

To select an Android device, list available devices and add the device ID:

```bash
flutter devices
flutter run -d <device-id> \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=https://api.workflownets.com \
  --dart-define=BUILD_SHA=local
```

> **Safety:** The configured API host may contain real records. Use approved test accounts. Avoid creating, editing, deleting, sending messages, or changing read states during read-only QA. Never commit access tokens, credentials, private exports, or user-data screenshots.

### Build an Android APK

```bash
flutter build apk --release \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=https://api.workflownets.com \
  --dart-define=BUILD_SHA=local
```

The generated APK is normally located at `build/app/outputs/flutter-apk/app-release.apk`.

## Quality checks

Run these commands before submitting changes:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Some opt-in integration tests require separately provided test credentials or environment variables. A passing unit/widget suite does **not** replace live role-based API tests or Android device acceptance.

---

**WorkFlow — Built with Flutter for collaborative project management.**
