# API integration root-cause audit (2026-11-19)

Every API issue reported so far, traced through three sources before
anyone is asked to change the backend:

1. The Postman collection `WorkFlow` (uid `56083386-d0da80f4-…`),
   `updatedAt` **2026-11-14T11:14:33Z**. Re-read on 2026-11-19; it is
   unchanged.
2. The live API at `https://api.workflownets.com/api/v1`. **Read-only
   GETs only**, sent with the two QA employee tokens (lead and regular
   member; company 1, which is each account's own `company_id`, sent as
   `X-Company`). Tokens, personal data and money amounts were not
   printed. Only field names, types, counts, equalities and ratios were
   recorded.
3. The Flutter branch `feat/m01-batch2-emulator-fixes`, starting at
   `29da0e5`: request, parsing, state and UI.

No task, meeting, join request, notification, chat or permission was
changed. No DELETE or POST was sent.

## Classification key

- **FLUTTER BUG:** wrong endpoint, mapping, calculation, cache,
  permission handling or label.
- **BACKEND BUG:** the server returns unauthorized, inconsistent or
  incorrect data.
- **CONTRACT GAP:** the documentation is outdated or does not specify the
  behaviour.
- **UX ISSUE:** correct data presented in a confusing way.
- **UNVERIFIED:** not enough evidence to decide.

## Summary

| Issue | Classification | Evidence | Flutter fix | Backend action |
|---|---|---|---|---|
| **A** "Active tasks" differ (Dashboard 1, Tasks 0) | **FLUTTER BUG** (label) + CONTRACT GAP | §A | `a5c844f`: Dashboard figure renamed "MY TASKS" | Define `dashboard.myTasks` and `tasks.stats.active` (documentation) |
| **B1** "Total salaries" shows 0 next to a non-zero timesheet | **FLUTTER BUG** (mapping) | §B | `b3d3007`: reads `totals[].total`, not `approved` | none |
| **B2** Timesheet list test expects `data.timesheets.data`, `data.summary` | CONTRACT GAP (E22) | §B | none needed (app follows the live shape and the description) | Update the collection test |
| **B3** Monthly payee: `total` = 100 × `rate` everywhere | CONTRACT GAP + **UNVERIFIED** possible backend unit bug | §B | none (no contract to correct against) | State the unit of `rate` for monthly pay, or fix the calculation |
| **B4** Details `timesheet.hours` / `calculated.hours` hold minutes | CONTRACT GAP | §B | none (app never reads `hours`) | Rename, or document as minutes |
| **C** `task_completion_rate` unit | CONTRACT GAP (E23) | §C | none needed (not read; app shows "x of y" from documented counts) | Document 0–1 or 0–100 |
| **D1** Meetings `live` for 12–17 days, `ended_at` null | **BACKEND** server state (data/lifecycle); not Flutter | §D | none (app shows the server's `status`; no cache) | End or clean up stale rooms; confirm whether an empty room should end |
| **D2** How a meeting ends | CONTRACT GAP | §D | none | Document manual vs automatic end (LiveKit webhook) |
| **E1** Active sprint past its end shows "0 days left" | **UX ISSUE** (Flutter) | §E | `58a7001`: "Past end date" warning badge | none (manual workflow state is valid) |
| **E2** `days_remaining` after the end date | CONTRACT GAP | §E | — | Document the clamp to 0 (or return a negative/overdue value) |
| **F1** Non-pending join request shows the raw server word | **FLUTTER BUG** (localization) | §F | `7f31098`: "No longer waiting", localized | none |
| **F2** Join-request status values and extra fields | CONTRACT GAP (E24) | §F | — | List every status; document `user`, `decided_by`, `decided_at` |
| **G1** Regular employee cannot change their own task's status (`can.update: false`) | CONTRACT GAP + **UNVERIFIED** Flutter assumption (Q1) | §G | none yet: needs Q1 or an approved probe | Say whether `update-status` follows `can.update` or only `kanban.manage_status` |
| **G2** Task details carry no `can` | CONTRACT GAP (E25) | §G | none (app reuses the list row's `can`; opened by id it offers no status change) | Add `can` to `GET /tasks/{id}` |
| **G3** Lead's rows say `can.delete: true`; the employee role has no `tasks.delete` | **BACKEND BUG** (inconsistent capability), not run | §G | none needed (app never offers Delete) | Make `can.delete` follow `tasks.delete` |
| **H** WhatsApp settings route answers 404 "route could not be found" | **BACKEND** (not deployed) + collection ahead of deployment | §H | none (app does not call it; no other route documented) | Deploy the route, or remove it from the collection |
| **I-S1** Sprint details expose task `cost` to the employee role | **BACKEND BUG: SECURITY** | §I | none (app never calls the route; hiding is not a fix) | Remove `cost` for employees |
| **I-S2** Non-member reads project details and member list | **BACKEND BUG: SECURITY** | §I | none (app asks only for led projects; hiding is not a fix) | Enforce project membership |

**Flutter bugs fixed: 4** (A, B1, E1, F1). **Confirmed backend defects:
3** (S1, S2, and the inconsistent `can.delete` flag), plus **2
server-state or deployment problems** (stale live meetings, WhatsApp
route). **Documentation gaps: 9.** **Unverified: 2** (B3, G1), each
needing a backend answer, not more client work.

---

## A. Active Tasks count mismatch

| | Dashboard | Tasks screen |
|---|---|---|
| Endpoint | `GET /employee/dashboard` | `GET /employee/tasks?per_page=1&month=all&assigned_to={me}` |
| Field | `data.myTasks` (int) | `stats.active` (int) |
| Computed in Flutter | no | no |
| Label before | "ACTIVE TASKS" | "ACTIVE TASKS" |

The collection gives no definition of either: `myTasks` is a "legacy
key", and `stats` is listed as `{total, by_status, active,
logged_minutes}`.

Live, same account, company and scope:

| Account | `myTasks` | `stats.total` | `by_status` | `stats.active` |
|---|---|---|---|---|
| Regular | 1 | 1 | todo 1 | **0** |
| Lead (own tasks) | 1 | 1 | in_progress 1 | 1 |
| Lead (team, no `assigned_to`) | — | 8 | todo 2, in_progress 2, completed 4 | **2** |

Changing `month` (all, current, none) or `assigned_to` does not change
the regular member's result.

Root cause: two different statistics. `active` leaves `todo` out;
`myTasks` counts the user's assigned tasks, `todo` included. The server
is consistent; the app gave both the same name. **Fixed in Flutter**
(the Dashboard shows "MY TASKS" / "مهامي"). Whether `myTasks` excludes
completed tasks, and whether `active` includes `in_review` or `pending`,
cannot be told from QA data (none in those states). Documentation
question.

## B. Timesheets

**Endpoints:** `GET /employee/timesheets` (`month`, `status`, `page`)
and `GET /employee/timesheets/{id}/details`.

| | Collection | Live (both accounts) | Flutter |
|---|---|---|---|
| Paginator | description: rows in `data`; **test**: `data.timesheets.data`, `data.summary` | `data` is the paginator (`data.data[]` plus `links`/`meta`) | reads `data.data` ✓ |
| Beside `data` | `stats`, `totals`, `available_months`, `facets` | same | reads `stats`, `totals`, `available_months` ✓ |
| Row fields | `hours_minutes, payment_type, rate, total, currency, can` | the same plus `id, date, month, user, company, status` (undocumented) | ✓ |
| `hours_minutes` | not stated | total **minutes** (equals `stats.total_minutes`; 160 h) | minutes ✓ |
| `totals[]` | `{currency_id, code, symbol, total, approved, pending}` | same | **read `approved` under "Total salaries"** ✗ |

- **B1 (FLUTTER BUG, fixed `b3d3007`):** with one pending timesheet,
  `totals[].approved` is 0 and `totals[].total` equals the row total. The
  metric labelled "Total salaries" showed 0. It now shows `total`.
- **B2 (CONTRACT GAP E22):** the collection's own test asserts
  `data.timesheets.data` and `data.summary`. Neither exists, and the
  description itself says the summary block was replaced.
- **B3 (CONTRACT GAP, possible backend unit bug, UNVERIFIED):** for both
  monthly-paid QA accounts (`payment_type: monthly`, `pay_basis:
  fixed_monthly_salary`), `total / rate` is **exactly 100**, the same in
  the list row, the details (`calculated.total = stored.total`,
  `in_sync: true`), the dashboard's `totalEarned` / `unpaidSalary`, and
  the report's `earnings.total`. Hourly arithmetic does not explain it
  (160 h × rate ≠ total). The collection documents `rate` only through
  an hourly example. Either `rate` is stored in another unit (e.g.
  hundredths) or the monthly total is mis-scaled. The app displays both
  as returned. It needs a backend answer before anyone changes the
  display.
- **B4 (CONTRACT GAP):** in the documented details example,
  `timesheet.hours: 270`, `rate: 30` and `total: 135` only agree if
  `hours` is minutes (270 min = 4.5 h × 30). Live, `timesheet.hours`
  equals the row's `hours_minutes`. The field name is misleading. The app
  does not read it.

## C. Employee Reports

**Endpoint:** `GET /employee/report` with `year` and `month`. The app
sends both for a month and only `year` for a year, and never a person or
company.

| Request | `period` (live) |
|---|---|
| no parameters | `type: month`, the current month |
| `year=2026&month=10` | `type: month`, 2026-10-01 → 2026-10-31 |
| `year=2026` | `type: year`, 2026-01-01 → 2026-12-31 |

- `summary.task_completion_rate` is a **number**. It was **0** in every
  period for both accounts (no completed assigned tasks), so 0–1 versus
  0–100 cannot be observed. The collection does not state the unit (E23).
  **CONTRACT GAP.**
- **Flutter:** it does not read the rate. It shows "x of y" from
  `completed_tasks_count` / `tasks_count`, reads `working_minutes`
  (live: equals `working_hours × 60`), `meetings_attended` /
  `meetings_count` and `earnings {total, approved, …}`. Every field it
  maps exists live with the expected type. **No Flutter bug.** The
  layout decisions were handled separately (R1 done; R2–R6 open in
  `docs/employee-final-validation.md`).

## D. Meeting lifecycle

**Endpoints:** `GET /employee/meetings`, `GET /employee/meetings/{id}`.
Flutter maps `status` directly: `live`, `ended` and `cancelled` come from
the server. It derives "overdue" only for meetings that have not started.
It reads `duration` and `elapsed_seconds` as **seconds**, as documented.
No cache: every screen reads again on open.

Live (both accounts see the same 6 instant meetings):

| id | `status` | started | `ended_at` |
|---|---|---|---|
| 1 | live | 17 days ago | null |
| 3 | live | 16 days ago | null |
| 4 | live | 15 days ago | null |
| 5 | live | 12.6 days ago | null |
| 2, 6 | ended | — | set |

- **D1:** the server itself says these four meetings are `live` with no
  `ended_at`, 12–17 days after they started. It is not caching or mapping
  on the app's side. One of them (5) also holds a real pending join
  request from the lead. **Server state.**
- **D2 (CONTRACT GAP):** ending is documented only as manual (`POST
  …/end`, permission `meetings.manage_status`). A LiveKit webhook route
  exists, but nothing documents that an empty room ends its meeting.
  Whether stale rows are expected (nobody pressed End) or a webhook
  failure cannot be told from the client.

## E. Sprint lifecycle

**Endpoints:** `GET /employee/kanban` (sprint, `stats.days_remaining`)
and `GET /employee/sprints` (planning). Sprint Details (`GET
/sprints/{id}`) is not used by the app (S1).

Live on 2026-11-19: sprints 1 and 2 are `status: active`, started 17
days ago, and their `end_date` was **4 days ago**. `days_remaining` is
**0**.

- The collection makes sprint status a **manual workflow**: created
  `planned` ("status is forced to planned"), then `POST …/start` and
  `POST …/complete` (with `move_to`). An `active` sprint past its end
  date is valid server data. **Not a backend bug.**
- `days_remaining` is computed by the server and clamped to 0 after the
  end date. That is not documented (E2).
- **E1 (UX ISSUE, fixed `58a7001`):** the app showed "0 Days left",
  hiding that the sprint is overdue. It now shows a "Past end date"
  warning when an unfinished sprint's last day has passed, using the
  server's `end_date` and `status`.

## F. Meeting join-request statuses

**Endpoints:** `GET /employee/meetings/{id}/join-request`, and
`DELETE` (⚠️, never sent).

| | Collection | Live (read-only) | Flutter before |
|---|---|---|---|
| Fields | `id, status, meeting_id`; 404 "No join request" when none | the same plus `user {id, name, avatar}`, `decided_by`, `decided_at`, `created_at`, `updated_at` | reads `id`, `status` ✓ |
| Status values | only `pending` ("409 when it is no longer pending") | `pending` (lead, meeting 5); 404 elsewhere | acts only on `pending` ✓; **prints any other value raw** ✗ |

The `approved`/`rejected` values in the collection belong to company
join requests, a different feature.

- **F1 (FLUTTER BUG, fixed `7f31098`):** an unknown status no longer
  shows the raw English server word. It shows "No longer waiting" /
  "لم يعد قيد الانتظار". Behaviour was already safe: no crash and no
  actions.
- **F2 (CONTRACT GAP E24):** document every status (after admit, reject,
  withdraw, expiry) and the extra fields.

## G. Task permissions

| | Collection | Live | Flutter |
|---|---|---|---|
| Status change | `POST /kanban/update-status`, permission `kanban.manage_status`, validation only; **no link to `can.update`** | regular member's own todo task: `can {update: false, delete: false}`; the lead's rows: `can {update: true, delete: true}` | board moves and the details "Change status" need `can.update` (≠ false or == true) |
| Task details | `GET /tasks/{id}` | `{task, duration_formatted, assigned_user_name, project_name, sprint_name}`, **no `can`** | reuses the opened row's `can`; when opened by id (notification, report) it offers no status change |
| Delete | `DELETE /tasks/{id}` ⚠️: **expected 403**, `tasks.delete` not granted to the employee role | rows say `can.delete: true` for the lead | `can.delete` is parsed but **never used**; no Delete action in API mode |

- **G1 (CONTRACT GAP + UNVERIFIED Flutter assumption, Q1):** the app
  treats `can.update` as permission to change status. The collection
  gives `update-status` its own permission, which both QA accounts'
  roles hold. If the server accepts a status change from an assignee
  whose row says `can.update: false`, the app is too strict. If it
  refuses, the app is right. Only a backend answer, or the approved
  mutation probe M-B1, can settle it. No client change was made on a
  guess.
- **G2 (CONTRACT GAP E25):** details should carry `can`.
- **G3 (BACKEND BUG, low):** `can.delete: true` contradicts the
  documented 403 for the whole employee role. The 403 itself was not
  exercised (destructive). The app is unaffected.

## H. WhatsApp notifications endpoint

- **Collection:** `GET`/`PUT /api/v1/employee/account/whatsapp-notifications`
  (also under `super_admin` and `company`). No other employee route is
  documented.
- **Flutter:** does not call it, and no alternative was invented.
- **Live:** `employee/account/whatsapp-notifications` answers 404 "The
  route … could not be found" for both accounts, with and without a
  trailing slash. The `company/...` variant answers the same 404, while
  an existing company route (`company/account`) answers **403** to the
  same token. The route is **not deployed for any role**. This is the
  Laravel route-miss 404, not the documented "No employee record" 404.

## I. Security (S1, S2)

Every request used the account's own `company_id` in `X-Company`, the
Bearer token, and documented paths, exactly as the app sends them.

- **S1 (still present):** `GET /employee/sprints/2`, a sprint of a
  project both accounts belong to, returns 4 task objects, **all with a
  non-null `cost`**, to both employee-role accounts. The same tasks
  through `GET /employee/tasks` carry no `cost` for the employee role, as
  the collection documents. The app never calls Sprint Details
  (test-enforced). That is **not** a fix.
- **S2 (still present):** the regular member's project list contains
  only project 2. Yet:
  - `GET /employee/projects/1` → **200**, including the client object
    with `credit_limit` and 4 `email` fields;
  - `GET /employee/tasks/project-employees/1` → **200**, 2 rows.

  The Sprint Details description says an employee "only reaches sprints
  of projects they are on"; projects do not follow the same rule. The
  app requests member lists only for projects the user leads. That is
  **not** a fix.

## Flutter changes from this audit

| Commit | Change | Regression test (fails before the fix) |
|---|---|---|
| `a5c844f` | Dashboard figure "MY TASKS" (`myTasks`), no longer "ACTIVE TASKS"; new strings in both languages | `employee_api_test`: label under `emp-dash-tasks` |
| `b3d3007` | "Total salaries" = `totals[].total`; `total` required | `employee_completion_test`: whole amount, not $0; repository test reads `total` |
| `58a7001` | "Past end date" warning on an unfinished sprint after its last day | `sprint_board_api_test`: past end, running, last day, completed |
| `7f31098` | Non-pending join request shown localized | `employee_meeting_join_test`: no raw word; Arabic, live shape |

Not changed: Client and Employee permissions, RTL and localization (new
strings are in both ARB files), and anything that would mask S1 or S2.

## Validation (2026-11-19)

| Step | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | clean |
| `flutter analyze` | no issues |
| Targeted tests (dashboard, timesheets, sprint board, join request, M07, session scope, layouts) | 97 passed |
| Full suite (emulator stopped) | **1047 passed, 8 skipped** (live smoke, `WF_LIVE_TOKEN`), **0 failed** |
| `flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock` | built |
| `flutter build apk --debug` (API mode) | built |
| Android emulator | **Not verified.** The APK installed and launched, but the host fell to 0.3 GB free RAM (Android Studio open) and the emulator stopped rendering. It was shut down to protect the machine. The four fixes are covered by widget tests built from the live response shapes; their live conditions (one to-do task, one pending monthly timesheet, sprints past their end date, a pending join request) were observed with the read-only GETs above. |

Raw live responses were kept only in a local scratch folder and deleted
after the audit.
