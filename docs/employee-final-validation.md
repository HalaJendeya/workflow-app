# Employee — final validation of the six remaining features (2026-11-19)

| | |
|---|---|
| Branch | `feat/m01-batch2-emulator-fixes`, 11 commits ahead of `origin` before this pass (base `fff3983`) |
| Contract | Postman `WorkFlow` (uid `56083386-d0da80f4-…`), `updatedAt` **2026-11-14T11:14:33Z**. Re-read on 2026-11-19 and unchanged since the 2026-11-18 audit. |
| Backend | `https://api.workflownets.com` (production). This pass sent **only read-only GETs**: My report, timesheets and their details, and one timesheet CSV export of the signed-in employee's own data. No notification was marked read, no chat was opened, and nothing was joined, withdrawn, created or edited. |
| Not started | M08, the first-launch onboarding walkthrough |

## 1. Feature review against the collection

| # | Feature | Verdict | Notes |
|---|---|---|---|
| 1 | Timesheet records and details | OK | Routes, `month`/`status`/`page` and the details shape follow the contract. The live labels "Pay type" and "Logged time" from `36b44d8` are now asserted in tests. |
| 2 | Employee Reports | OK, plus 1 fix | The meetings section was headed with the module title "Meetings Management" (emulator, both languages). It is now "Meetings" (`890ba4c`). |
| 3 | Notification navigation | OK | Only `task`, `conversation` and `meeting` subjects with a numeric id open anything. Only unread items are written. |
| 4 | Join by code and own join request | OK | The by-code path is encoded. A 404 on the join request means none. Withdrawing asks for confirmation before the ⚠️ DELETE. |
| 5 | CSV exports | **1 fix** | The Backlog's search box narrowed the visible rows, but the export ignored it. It now sends the documented `search` (`17d7446`). The tasks (`month=all` is documented), projects and timesheets parameters match the collection. |
| 6 | Project-member assignees | OK | Members are loaded per chosen project and only for projects the user leads. The assignee is cleared when the project changes. A load failure shows an error with Retry. |

## 2. Test suite

| Run | Conditions | Result |
|---|---|---|
| 1 (start of pass, `4b39483` + 1 test being written) | Emulator stopped, `--concurrency=4`, about 2 GB free RAM | 1011 passed, 8 skipped, 1 failed. The failure was a new test that was being edited while the run loaded it; it was fixed before the commit. The earlier "Profile: rename…" timeout **did not recur**. |
| 2 (`317036e`) | Emulator stopped, `--concurrency=4`, about 4 GB free | **1037 passed, 8 skipped, 0 failed** (5 min 53 s) |
| Final (`HEAD`) | Emulator stopped | See §7 |

The "Profile: rename, password validation and delete gate" timeout from
2026-11-18 (emulator booting during the run) did not occur in either run.
The test has no timers or real delays. It was a load-related stall, not a
defect.

**Intentionally skipped (8), all in `test/live/employee_live_smoke_test.dart`**
(gated on `WF_LIVE_TOKEN`, which is never set in normal runs): profile;
dashboard, task figures and timesheets summary; tasks (mine, team, every
details screen); projects list, details and options; board and planning;
conversations, messages and available users; meetings, participants and
invitations; notifications and unread count.

New and extended tests in this pass:

- `test/features/csv_export_test.dart` (new, 18 tests). For each of the
  4 routes: filters, headers (Accept, Bearer, X-Company), no paging, the
  documented employee columns, row counts, and byte-for-byte pass-through
  of fixtures with commas, quotes, line breaks, Arabic and the BOM. Also:
  header-only and 0-byte files, file names (path parts dropped), network,
  timeout, 5xx and HTML errors, and the real `file_picker` save path
  faked at the platform interface (the saved file holds exactly the
  server bytes; on cancel nothing is written). Chip messages are checked
  for saved, cancelled, dialog failure, offline and 422, plus a single
  request per tap and Arabic.
- `m07_employee_work_test.dart`: the Tasks, Projects and Backlog chips,
  in the full app, send exactly the list's current filters.
- `notification_navigation_test.dart`: 5 new tests. A deleted task (404)
  and a refused meeting (403) show friendly messages, never the server's
  text, and Back returns Home. A conversation that 404s shows the
  friendly message. A failed mark-read is reported and the item still
  opens. Unsupported subjects don't crash and only unread items are
  written.
- `employee_report_test.dart`: every section heading, plus "Logged time"
  (and no "LOGGED HOURS"). `employee_completion_test.dart`: "Pay type".
- `more_screen_actions_test.dart`: the + button clears More's last rows
  for a regular employee too (EN/AR, 360/320 px).

## 3. CSV export verification

| Check | How | Result |
|---|---|---|
| Tasks, Projects, Timesheets, Backlog routes and filters | Repository tests and full-app chip tests | Pass (the Backlog search was fixed) |
| Headers and row counts | Fixtures with the documented employee columns, parsed per RFC 4180 | Pass. No Cost, Currency (tasks) or Budget (projects) columns. |
| Commas, quotes, line breaks | Quoted fields in fixtures | Pass. The app never parses or rewrites a CSV; escaping is the server's job. |
| UTF-8, BOM, Arabic | Fixtures, and the file saved on the device | Pass |
| Empty results | Header-only and 0-byte replies | Saved as received |
| Download failures | 403, 422, 5xx, HTML 502, offline, timeout, non-CSV 200 | A friendly "Couldn't export: …" message. Nothing is saved. |
| Android save dialog: cancel | Emulator, live timesheets export | Returned to the app with no message and the chip ready; no file in Downloads |
| Android save dialog: save | Emulator, same export | `timesheets-2026-11-19.csv`, 143 bytes. Valid UTF-8 with a BOM, the 9 documented columns, 1 row (matching the 1 record in the list). **Values were not read or printed.** The file was deleted from the emulator afterwards. |
| Live read-only GET | The collection marks every export `READ_ONLY`; it is the user's own data | Only the timesheets export was used live |

## 4. My report: design review (no Figma frame, decisions for approval)

Checked on the Android 16 emulator in API mode (live, read-only) in
English and light at 411 dp, and in Arabic and dark at 360 and 320 dp.

- **Works as intended:**
  - Month and Year switching, and Previous/Next. Next is disabled at the
    current period, and an earlier month shows "No tasks are dated in this
    period".
  - Server values and units: time comes from minutes ("160h 0m"); money
    comes from the server's currency.
  - All four sections are present: tasks, projects, timesheets, meetings.
  - The RTL mirroring and the arrows are correct.
  - Dark theme.
  - No overflow at 320 dp; logcat is clean.
  - Offline shows the friendly message with Retry, and Retry recovers.
  - Android Back and masthead Back both return to More.
- **Fixed:** the meetings section heading (see §1).

Decisions for the owner (current behaviour first):

| # | Topic | Today | Option |
|---|---|---|---|
| R1 | Space above the figures | The Month/Year chips and the period stepper take two rows. At 320 dp the first figure starts about halfway down the screen. | Put Month/Year as a segmented control inside the stepper card (one row, about 70 dp saved). |
| R2 | Money in the summary | Six metrics, including "Earnings" and "Approved" | Rename "Approved" to "Approved pay", or move both into the Timesheets section |
| R3 | Tasks by status | A 2×3 grid; zeros take as much room as real counts | One compact row of status chips with counts, or hide zero statuses |
| R4 | Rows that open something | Task and meeting rows open details but show no chevron. Timesheet and project rows open nothing. | Add a chevron to openable rows. Let timesheet rows open Timesheet details. |
| R5 | Arabic digits | Month names use Arabic-Indic digits (`نوفمبر ٢٠٢٦`); figures, dates and "160h 0m" use Western digits and Latin h/m. This is app-wide, not specific to this screen. | Pick one convention for the whole app |
| R6 | Unknown server values | An undocumented project association or meeting status is shown as the raw server word | Keep (it is visible and honest), or show a generic "Other" |

## 5. Role-specific navigation

| Check | Result |
|---|---|
| Regular employee: only authorized actions | Emulator (live regular-employee session): More's + menu offers **Join by Code only**, with no Add Task. Widget tests: no Add Task and no Edit for non-leads. |
| Project Lead keeps Add Task | Widget tests: "API, lead: Add task and Join by Code". No lead session was available on the emulator. |
| + never covers controls | Test extended to regular employees (EN/AR, 360/320 px). On the emulator the last More rows clear the + button. |
| Back behaviour | Matches `docs/android-emulator-acceptance.md` §6: report → Back → More; More → Back → Home (previous tab); timesheet details → Back → list. |
| Duplicate routes | My report: one entry (More → Overview). Timesheets: one entry. Join by Code: **two entries** (see N1). |
| Onboarding walkthrough | Not started |

**N1 (decision):** Join by Code is reachable from the Meetings list chip,
which is the Figma placement, and from More's + menu. For a regular
employee that + menu holds this single item, so a "create" button only
opens a join form. Options:
(a) keep both;
(b) keep the + menu only for leads, so regular employees join from Meetings
and More has no + for them;
(c) for a regular employee, make + open Join by Code directly.
Recommendation: **(b)**. It is less misleading and keeps More uncluttered,
and the Meetings chip remains the discoverable entry.

## 6. Notification routing

Mock tests (13 in `notification_navigation_test.dart`) cover:

- Task, conversation and meeting targets from the Home card and the bell
  panel.
- Back to Home or to the panel.
- 404 and 403 targets, with friendly messages.
- A failed mark-read (reported; the item still opens).
- Unknown types, non-numeric ids and missing subjects (nothing opens,
  nothing crashes).
- Read items are never re-written, and clients never open tasks.

On the emulator, the bell panel's Read filter lists only chat
notifications near the top. Opening a chat writes its read state, so no
live notification was tapped. The single unread item was not touched.

App-side observation (not changed, older than these features): the chat
screen asks the server to mark a conversation read as it opens, in
parallel with loading it, so a conversation that 404s still gets a
refused `POST …/read`. The server refuses it, so nothing changes.

## 7. Final regression gate

| Step | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | Clean |
| `flutter analyze` | No issues found |
| Full suite (emulator stopped) | Run 2: 1037 passed, 8 skipped, 0 failed. Final run at `HEAD`: see the delivery report. |
| `flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock` | Built |
| `flutter build apk --debug` (API mode, `api.workflownets.com`) | Built at `317036e`; rebuilt at `HEAD` for the device check |
| Android 16 emulator (Medium Phone API 36.1), live, read-only | §3–§6 above. No Flutter errors in logcat. Language, theme, density and airplane mode were restored afterwards. |

## 8. Still open (unchanged by this pass)

| # | Item | Owner |
|---|---|---|
| **S1** (HIGH) | `GET /employee/sprints/{id}` exposes task `cost` to employees. Release blocker. | Backend |
| **S2** (HIGH) | Non-members read other projects' client and user data. Release blocker. | Backend |
| Q1 / O1 | May an assignee change their own task's status (`can.update` is false for the regular member)? | Backend/product |
| O2 | WhatsApp settings route not deployed (404). Confirm `WHATSAPP_NOTIFICATIONS_ENABLED` before any assignment test. | Backend/owner |
| O3 | Two "Active tasks" definitions | Contract |
| Contract | E22 the collection's "List Timesheets" test is out of date; E23 the report's `task_completion_rate` unit; E24 join-request `status` values; E25 a task opened by id has no `can`; E26 the report needs a design (§4). Also undocumented: the `project-employees` rows and the notification `subject` shape (both modelled from live reads). | Backend (collection) / owner |

No backend authorization rule is worked around in Flutter; hiding
controls in the client is not a fix for S1 or S2.
