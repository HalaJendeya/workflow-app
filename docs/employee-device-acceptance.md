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

## 3. Results — run 1 (2026-11-17, Regular Employee)

Build `3dbf648` (release, API mode; app code identical to `048ac6a`),
clean install, signed in by the owner. Claude drove the phone over adb and
read results from screenshots (kept local: they show personal data). After
the run, read-only API checks confirmed that no server state changed (unread
notifications still 1, conversation unread 0, task #13 still `todo`).

| Id | Result | Notes |
|---|---|---|
| L1 | PASS | No DEMO banner |
| L2 | PASS | `API · api.workflownets.com · build 3dbf648` |
| L3 | PASS | Session kept after force-stop; first frame 820–830 ms, Home with data ≈ 4.8 s |
| H1 | PASS | "Projects 1", "testing mobile · To do" |
| H2 | PASS | |
| H3 | PASS | All 134, 1 unread (task assignment) |
| D1 | PASS | Active tasks 1, Logged hours **160.0** |
| D2 | PASS | To do 1, all others 0 |
| T1 | PASS | Active 0, Logged 0.0, All 1 / 0 / 0 / 0 |
| T2 | PASS | No Add Task |
| T3 | PASS | No banner; #13, Medium, 1 pt, 2026/11/16, description shown. Note: no Sprint row (backlog), not "—" |
| T4 | PASS | No ⋮/Edit, no Change status |
| T5 | PASS | Same single task |
| T6 | PASS | "No records match these filters"; note: status chips keep the overall count while searching |
| T7 | PASS | Only the user's project offered |
| P1 | PASS | One project, Pending, team 5, 80% |
| P2 | PASS | No lead badge, no Add task; sprint and project task listed |
| P3 | PASS | Empty state; loaded slowly (see N2) |
| S1 | PASS | No My/Team switch; In Progress 0 and Completed 0 (whole sprint has 4 completed) |
| S2 | PASS | After one Retry (first attempt: "Can't reach the server", see N2) |
| S3 | NOT RUN | Skipped to avoid an accidental status write on an unstable connection |
| TS1 | PASS | Approved 0, Pending 1, 160.0 h; outdated banner (O4) |
| C1 | PASS | One conversation, Unread (0); not opened |
| M1 | PASS | 6 / 4 live / 0 / 2; no "My invitations" card (the only invitation is accepted) |
| M2 | PASS | Details load; Join not pressed |
| Notifications panel | PASS | 1 unread; Unread filter shows exactly it; Mark all not touched |
| A1 | PASS | Arabic + Dark applied instantly, mirrored |
| A2 | PASS with defects | Home, Task Details, Dashboard, More correct in RTL/dark. Defects: F8 (below) and RTL punctuation of server text (F9) |
| A3 | PASS | Arabic + Dark persisted after force-stop |
| A4 | PASS | English + System default applied without restart |
| I1 | PASS | Owner logged out |
| I2 | PASS | Team Lead: Home "QA Task 1", All 136, no unread; My tasks only "QA Task 1"; **+ Add Task** on Tasks and in the More menu; nothing from the Regular Employee. Language/theme (device settings) kept |
| I3 | PASS | Regular Employee again: Home "testing mobile", All 134 + unread dot; More **+** without Add Task; board on project #2 without My/Team switch; Dashboard 160.0 h, To do 1 — nothing from the Team Lead |
| I4 | PASS | Back from Home exits to the launcher; no screen of a previous account shown |

**Run 1 summary:** 33 PASS (A2 with defects F8/F9), 1 NOT RUN (S3, skipped for safety), 0 FAIL. Read-only Regular Employee acceptance on the device is complete except S3. This does **not** complete the Employee E2E: the mutation scenarios (`docs/employee-mutation-plan.md`) are not approved or run, and F8/F9 are open.

### New findings in run 1

| # | Kind | Finding |
|---|---|---|
| F8 | Flutter defect | The bell panel's Unread/Read filter is global (`notificationFilterProvider`). The Home Notifications card shares the same inbox, so after choosing **Unread** in the panel, Home shows "All 1" with only unread items until restart. |
| F9 | Flutter defect (RTL) | English text from the server (notification messages) is laid out RTL in Arabic, so punctuation moves to the wrong end (`."… in "Team`). Server-text widgets need direction detection. |
| U1 | UI | On More, the **+** button overlaps the end of the Appearance row (LTR and RTL; "Dark" shows as "Da"). |
| U2 | UI / permissions | For a non-lead, the More **+** offers only "Schedule meeting" (shows "Meetings can't be created…") and "Join by Code" (not available in API mode). This contradicts the M07 rule that unusable actions are hidden. |
| U3 | Copy | Arabic date header uses a Latin comma (`الثلاثاء, نوفمبر ١٧`). |
| N2 | Environment | The phone's network was unstable: ping to the API host had 25% loss and 260–460 ms RTT, versus ≈150 ms from the PC. Some loads took 4–15 s; the backlog once failed and succeeded on Retry. The app's error and Retry handling worked. USB debugging also dropped four times. **Re-measure timings on a stable network** before any performance sign-off. |