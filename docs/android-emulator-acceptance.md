# Android emulator acceptance (2026-11-18)

The Redmi 8 was unavailable, so this round ran the real Android app on an
emulator, driven through adb (taps, swipes and the system Back key) and
checked with uiautomator dumps and screenshots. Widget tests and builds are
listed separately in section 10. They are not counted as acceptance
evidence.

## 1. Emulator

| | |
|---|---|
| Device ID | `emulator-5554` (AVD `Medium_Phone_API_36.1`, x86_64 Google Play image) |
| Android | 16 (API 36), gesture navigation, predictive Back active (the app targets API 36) |
| Panel | 1080×2400 px |
| Viewports tested | 360×800 dp (density 480) at text 1.0, and 320×711 dp (density 540) at text 1.3 |
| Acceleration | WHPX. The host had little free memory, and the first boot produced System UI "not responding" dialogs until Play services settled |
| Restored afterwards | density, size, font scale, error dialogs (`hide_error_dialogs` was set during testing and then deleted) |

## 2. Branch, builds, mode

The branch is `feat/m01-batch2-emulator-fixes`. All six commits from the
request were present (`e132ba9` … `b6259c6`).

| Build marker (account sheet) | Mode | Used for |
|---|---|---|
| `b6259c6` | API, `api.workflownets.com` | First Lead run. Found D1 and D2 |
| `4691964` | API | Re-test of D1 and D2, then the Lead flows |
| `dd08c75` | API | Re-test of D3, Arabic/dark, project and board flows |
| `ae1aaf7` | API | Re-test of D4, all Regular Employee flows. Left installed |
| `ae1aaf7` | **Mock (demo data)** | Client flows only. No Client QA account exists |

Sessions: the owner signed in on the emulator with the **Lead** QA account
and later with the **Regular Employee** QA account. Credentials were never
typed, logged or captured by the agent. Only GET requests were made: no
task edits, no status changes, no invitation Accept/Decline, no meeting
Join, no chat opened, no notifications read, no sign-out. Screenshots stay
outside the repository because they show account e-mail addresses.

## 3. Defects found on the emulator and repaired

| # | Found | Cause | Fix | Regression test |
|---|---|---|---|---|
| D1 | Tasks Filters sheet: tapping Status, Project or Sort chips changed nothing, so **Show results** applied nothing | The draft was a local variable inside `showModalBottomSheet`'s builder. Android sends new window metrics while the sheet is open, the builder runs again, and the draft resets | `f6d3bc0`: the draft is kept in a `State` | `task_filters_test`: "choices survive a metrics change" (failed before the fix) |
| D2 | **More → Tasks → Task Details → Back → Back closed the app**. Back on a tab opened from More also exited | With predictive Back (Android 13+), Android sends Back to Flutter only while the framework reports it can pop. After a root route popped, the root navigator reported "can't pop", unaware of the tab's own stack and `AppShell`'s tab history | `4691964`: the app always claims Back. When nothing handles it, Flutter exits the app itself (`SystemNavigator.pop`) | `navigation_flow_test` now models Android 13+ Back. 7 of 10 flows failed before the fix |
| D3 | Re-tapping the selected tab (More, with Meetings open) did nothing | `goBranch(initialLocation: true)` does not remove screens pushed with `Navigator.push`. This has been the case since the first shell | `dd08c75`: re-tapping pops that tab to its first screen | "re-tapping the current tab returns to its first screen" (failed before the fix) |
| D4 | Arabic: the masthead Back arrow pointed left | `arrow_forward` was chosen for RTL, but the icon already mirrors itself, so it was flipped twice | `ae1aaf7`: always `arrow_back` | "masthead Back points the reading way back" (ar failed before the fix) |

D1 and D2 explain why widget tests and the Redmi 8 (an older Android
version) did not show them.

## 4. Tasks filters: Lead (API)

| # | Check | Result |
|---|---|---|
| 1 | No always-visible status chips | PASS |
| 2 | One search field (masthead) | PASS |
| 3 | One Filters button | PASS |
| 4 | Status (with counts), Project, Priority, Sort inside the sheet | PASS |
| 5 | Choices apply together: In Progress + QA Test Project + Title A–Z → **Filters (3)**, three chips, "1 task" | FAIL on `b6259c6` (D1) → **PASS** on `4691964` |
| 6 | Closing the sheet with Back after choosing Completed leaves the list and count unchanged | PASS |
| 7 | Active filters are removable chips. Removing Title A–Z → Filters (2), the other two kept | PASS |
| 8 | Reset filters → "Filters", full list | PASS |
| 9 | My tasks is the default | PASS |
| 10 | Team tasks shown to the Lead, with the team's list | PASS |
| 11 | Cards show title, description and status, and open Task Details | PASS |
| 12 | Task Details → Back → Tasks with filters and scroll kept → Back → More | FAIL on `b6259c6` (D2: app closed) → **PASS** on `4691964` |

Regular Employee (API, `ae1aaf7`): no My/Team switch and no Add Task
button. The sheet's Project options show only the employee's project. To
do → Filters (1) → Task Details → Back keeps the filter → Back → More.
**PASS**.

## 5. Meeting Details (API)

| Check | Lead 360×800 | Lead 320×711 @1.3 | Employee 360×800 |
|---|---|---|---|
| Timing and Details as a compact grid (two columns; one label…value line per fact at 320) | PASS | PASS | PASS |
| Uses the width; no stacked empty blocks | PASS | PASS | PASS |
| Arabic title and description in their own direction; long values wrap | PASS | PASS | PASS |
| Participants on one line (badges wrap under the name at 320); refresh in the header | PASS | PASS | PASS |
| Scrolls; no overflow (0 "overflowed" lines in logcat) | PASS | PASS | PASS |
| Live meeting shows **Join Meeting** (not pressed); ended meeting shows none | PASS | — | PASS (ended) |
| Back → Meetings list at the same scroll position | PASS | PASS | PASS |

The pending invitation's Accept/Decline buttons were visible on the
Meetings list and were not touched.

## 6. Android Back navigation

Lead (API, `4691964` / `dd08c75`):

| Flow | Result |
|---|---|
| Home → More → Tasks → Back → More | PASS |
| More → Projects → Back → More | PASS (after D2) |
| More → Sprints → Back → More | PASS |
| More → Chat (Conversations) → Back → More | PASS |
| Tasks → Task Details → Back → Tasks | PASS |
| Meetings → Meeting Details → Back → Meetings | PASS |
| Tasks → Chat tab → Back → Tasks | PASS |
| Chat → Projects → Sprints → Projects → Chat, then Back ×5 → Projects, Sprints, More (Tasks), More, Home | PASS (each tab once, no loop) |
| Back on Home → app exits, no crash | PASS |
| Projects → Project Details sheet → QA Task 1 → Task Details → Back → sheet | PASS |
| Project Details → Open board (Kanban) → Back → sheet → Back → Projects → Back → previous tab | PASS |
| Re-tap More over Meetings → More's first screen | FAIL (D3) → **PASS** on `dd08c75` |

Regular Employee (API, `ae1aaf7`): More → Projects / Sprints / Chat → Back →
More; Tasks → Task Details → Back; Meetings → Meeting Details → Back;
Projects → Sprints → Chat → More (Meetings) → More → Home → exit. **PASS**.
No duplicate screens were seen in any flow.

Client (**mock only**, `ae1aaf7`): More → Companies / Invoices /
Conversations → Back → More; More → Dashboard → View All (Invoices tab) →
Back → Dashboard → Back → More → Home → exit. **PASS (mock)**. Live Client
acceptance is still open: there is no Client QA account.

## 7. Role coverage

| Role | Mode | Coverage |
|---|---|---|
| Team Lead | API (live, read-only) | Tasks + filters, Team tasks, Task Details, Meeting Details (ended + live), Projects → details → tasks, board, Back flows, languages/themes |
| Regular Employee | API (live, read-only) | Tasks + filters (no team/no add), Task Details, Meeting Details, Back flows, tab history, exit |
| Client | Mock only | Tab entries from More, Dashboard → Invoices, Back flows, exit |

## 8. Arabic and dark mode (Lead, API)

| Combination | Screens | Result |
|---|---|---|
| Arabic / Dark | More (mirrored bar, FAB on the left), Tasks, Filters sheet, applied chip, Meeting Details (grid mirrored, dates kept left-to-right, Join card, participants) | PASS, except D4 (fixed and re-checked) |
| English / Dark | Filters sheet | PASS |
| Arabic / Light | Tasks, Task Details (AppBar Back points right, English content left-to-right) | PASS |
| English / Light | All other flows above | PASS |

Preferences were reset to System default afterwards.

Minor (not fixed, pre-existing): Task Details shows the duration as `2h 0m`
in Arabic too. Meetings use localized units. The server's `active` count
read 0 for an employee whose only task is To do. This is server data and
was recorded, not changed.

## 9. Evidence

Screenshots (about 40) and uiautomator dumps are kept in the local session
scratchpad, not in the repository, because they show account e-mail
addresses. A redacted set can be produced on request. Logcat showed no
crash entries for the app in any run. The one app kill during setup was
caused by the agent tapping "Close app" on a system ANR dialog while the
emulator was starved; it was not an app crash.

## 10. Tests and builds

- `dart format --set-exit-if-changed lib test`: clean.
- `flutter analyze`: no issues.
- New and updated regression tests: `task_filters_test` (D1) and
  `navigation_flow_test` (D2, D3, D4; 13 tests).
- Full suite: 961 passed, 8 skipped (opt-in live tests).
- `flutter build apk --debug` (API mode, `BUILD_SHA=ae1aaf7`): built and
  installed on the emulator.

## 11. Still open

- Live **Client** acceptance (needs a Client QA account).
- Physical Redmi 8 re-check of D1 and D3 (D2 does not occur on its Android
  version).
- Keyboard-obstruction checks. The AVD has `hw.keyboard=yes`, which gives
  no docked keyboard.
- Backend security issues S1 and S2 remain open.
