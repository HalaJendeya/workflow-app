# Employee device acceptance — Regular Employee (Redmi 8)

| | |
|---|---|
| Source | `origin/feat/m01-batch2-emulator-fixes` @ `048ac6a` (fixes F1–F7 in `a662c3a`) |
| Device | Redmi 8 `972ae5b70706`, Android 10 |
| Backend | `https://api.workflownets.com` (production) |
| Account | the **Regular Employee** QA account (not a project lead) |
| Writes | **None.** Every step below is read-only except the sign-in and sign-out you perform yourself. Steps that would write are marked ⛔ and must be skipped. |

## 1. Update and run the API-mode build (PowerShell)

Run from `C:\Users\pc\StudioProjects\workflow-app`. Turn on **Do Not Disturb**
on the phone first, so screenshots carry no personal notifications.

```powershell
# 1. Exact source: app code identical to the pushed commit 048ac6a.
git fetch origin
git switch feat/m01-batch2-emulator-fixes
git status --short                      # must print nothing (pubspec.lock may show; keep it)
git merge-base --is-ancestor 048ac6a HEAD; "contains 048ac6a: $?"   # must print True
git diff --stat 048ac6a HEAD -- lib pubspec.yaml android   # must print nothing (later commits are docs only)
$sha = git rev-parse --short HEAD       # 048ac6a, or a later docs-only commit (e.g. the local docs commit)
"BUILD_SHA = $sha"

# 2. Device present.
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices -l                       # 972ae5b70706 ... device

# 3. Release build in API mode with the BUILD_SHA marker.
flutter pub get
flutter build apk --release --dart-define=APP_MODE=api --dart-define=API_BASE_URL=https://api.workflownets.com --dart-define=BUILD_SHA=$sha

# 4. Clean install: uninstall drops the stored Team Lead session, so the
#    Regular Employee starts from the sign-in screen with nothing cached.
& $adb -s 972ae5b70706 uninstall app.workflow.workflow_app
& $adb -s 972ae5b70706 install build\app\outputs\flutter-apk\app-release.apk

# 5. Cold start with timing (record TotalTime).
& $adb -s 972ae5b70706 shell am start -W -n app.workflow.workflow_app/.MainActivity
```

Marker check (step L2 below): the account sheet must show
`API · api.workflownets.com · build <sha>`, where `<sha>` is exactly the
`BUILD_SHA` value printed in step 1. Record it in the results. `local` means
`BUILD_SHA` was not passed. A different SHA means a different source was
built. No DEMO banner may appear.

Notes:
- Uninstalling also resets language and theme to their defaults; that is
  intended for this run.
- If you prefer to keep the device's current data, replace step 4 with
  `& $adb -s 972ae5b70706 install -r build\app\outputs\flutter-apk\app-release.apk`
  and sign the Team Lead out first (step I1).
- Signing out in the app revokes **only that device's token**. Claude's
  separate QA tokens are unaffected.

## 2. Checklist — Regular Employee

Expected values were read live (GET only) on 2026-11-17 and may drift if
someone changes data. Record **Pass / Fail / Note** and a screenshot per step.

### Login and session

| Id | Step | Expected |
|---|---|---|
| L1 | Account Type → **Employee** → sign in with the Regular Employee (type the password yourself) | Home opens; no error; no DEMO banner |
| L2 | Tap the avatar (top left) | Account sheet: your account, `Employee`, and `API · api.workflownets.com · build <BUILD_SHA from step 1>` |
| L3 | Close the app from Recents, reopen ("Remember me" on) | Still signed in, Home with data |

### Home and Dashboard

| Id | Step | Expected |
|---|---|---|
| H1 | Home → **Tasks** card | Pill **Projects 1**; one row "testing mobile" with status **To do**; no "isn't available yet" text, no "Projects 0" |
| H2 | Tap that row | Task Details opens (see T3) |
| H3 | Home → Notifications card | **All 134**; items read "New message …" / task assignment. ⛔ Do not tap an item (tapping marks it read) |
| D1 | More → **Dashboard** | Active tasks **1**; Logged hours **160.0** (not 320); earned/paid/unpaid shown without errors |
| D2 | Dashboard → Task Distribution | Backlog 0 · To do **1** · Pending 0 · In Progress 0 · In review 0 · Completed 0 (your task only, not the team's) |

### Tasks

| Id | Step | Expected |
|---|---|---|
| T1 | More → **Tasks** | Opens on **My tasks**; figures: Active tasks **0**, Logged hours **0.0** (see note N1); chips All 1 · In Progress 0 · Under Review 0 · Completed 0 |
| T2 | List | One card "testing mobile", **To do**; no **+ Add Task** button (you lead no project) |
| T3 | Open the card | Task Details loads **without** a "couldn't load" banner or Retry. Project **#2** (the only project you are on), Sprint **—** (backlog), Priority **Medium**, Story points **1**, Task date **2026/11/16**, no start/end time rows |
| T4 | Same screen | **No ⋮ / Edit** and **no Change status** (the server says `can.update: false`; see Q1) |
| T5 | Back → **Team tasks** | Same single task (you can see only your project's tasks assigned to you) |
| T6 | Search "zzz" | Empty state; clear it → the task returns |
| T7 | Project filter → **project #2**; sort → **Title A–Z** | Task stays; no error |

### Projects

| Id | Step | Expected |
|---|---|---|
| P1 | **Projects** tab | One project **#2**, **Pending**, team **5**, progress **80%**; no Add Project |
| P2 | View Details | Details open; no "You lead this project" badge; **no Add task**; sprint **Dashboard UI** listed; latest task "testing mobile" |
| P3 | Status filter **Completed** | Empty state, no error; back to All |

### Sprints

| Id | Step | Expected |
|---|---|---|
| S1 | **Sprints** tab → Kanban | Project **#2**, sprint **Dashboard UI** (2026-11-02 → 2026-11-15); **no My/Team switch**; every column count **0** with "No tasks in this column" (your task is in the backlog, not the sprint) |
| S2 | **Backlog** | One backlog task "testing mobile" |
| S3 | Tap the backlog task | ⛔ If a "Move to" sheet opens, **cancel** — choosing a status is a write |

### Timesheets, Chat, Meetings

| Id | Step | Expected |
|---|---|---|
| TS1 | More → **Timesheets** | Approved **0**, Pending **1**, Total Hours **160.0**; Total Salaries shown. The old "endpoints not published" banner is a known gap (O4) |
| C1 | **Chat** tab | One conversation **Team**; filter **Unread (0)**. ⛔ Do **not** open it (opening sends a read receipt) |
| M1 | More → **Meetings** | Total **6**, Live Now **4**, Waiting 0, Ended **2**; My invitations: **1** (accepted) |
| M2 | Open one meeting | Details and participants load. ⛔ Do not press **Join** |

### Arabic, dark mode, RTL

| Id | Step | Expected |
|---|---|---|
| A1 | More → Preferences → Language **العربية**, Appearance **Dark** | Whole app switches; tab bar and back arrows mirrored |
| A2 | Repeat H1, T1–T4, P1–P2, S1, D1 in Arabic | Text right-aligned, nothing clipped or overlapping, numbers and dates readable, Task Details labels "وقت البدء/وقت الانتهاء" only if times exist |
| A3 | Close and reopen the app | Arabic + Dark persist |
| A4 | Back to English + **System** theme | Switches back without restart |

### Logout and account isolation

| Id | Step | Expected |
|---|---|---|
| I1 | Avatar → **Log out** | Account Type screen; reopening the app stays signed out |
| I2 | Sign in as the **Team Lead** | Home Tasks card shows **QA Task 1**; Tasks shows **+ Add Task**; nothing from the Regular Employee (no "testing mobile" in My tasks, notifications **All 136 / unread 0**) |
| I3 | Sign out, sign in as the **Regular Employee** again | No lead controls (no Add Task, no Edit, no Team switch on the board); Home shows "testing mobile"; Dashboard 160.0 h |
| I4 | Back button from Home after sign-out | Never shows the previous account's screens |

### Notes

- **N1 — two "Active tasks" figures.** Dashboard shows the server's
  `myTasks` (all tasks assigned to you = 1); Tasks shows `stats.active`
  (in-progress work = 0 for a To do task). Both are server values; the labels
  read the same. Logged as O5; not a regression of F1–F7.
- Startup: record `TotalTime` from step 5 and the time until Home shows data.
- Any FAIL: note the step id, the on-screen message only (no personal data),
  and whether it repeats after pull-to-refresh.
