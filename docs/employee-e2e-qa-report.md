# Employee portal — end-to-end QA report (read-only phase)

| | |
|---|---|
| Date | 2026-11-17 |
| Branch / base | `feat/m01-batch2-emulator-fixes`, base `83be926` (accepted M07) |
| Contract | Postman `WorkFlow` `56083386-d0da80f4-f067-42e4-9b96-9e021769e55e`, **updatedAt 2026-11-14T11:14:33Z** (re-read today, unchanged; 1096 requests) |
| Backend | `https://api.workflownets.com/api/v1` — treated as production |
| Device | Redmi 8 `972ae5b70706`, Android 10, API-mode **debug** APK built from this branch |
| Overall status | **Employee E2E NOT complete**: Regular Employee device acceptance and all approved mutation scenarios are outstanding. |
| Scope of this phase | **Read-only.** Only GET requests were sent by Claude. No create, update, status change, message, read receipt, join or logout was sent. Phase 5 (mutations) waits for the owner's approval — see §10. |

Credentials: the owner typed both passwords into a local helper (masked prompt);
only the bearer tokens were kept, DPAPI-encrypted for the Windows user under
`%LOCALAPPDATA%\workflow-qa\` (outside the repo). No token, password, email or
amount appears in this report, the repo or the logs. On the phone the Team Lead
session was already stored by the app; Claude did not type any credential.

## 1. Accounts (verified live, not inferred from labels)

| | Team Lead account | Regular Employee account |
|---|---|---|
| `GET /employee/account` | 200 | 200 |
| Backend role | `employee` (18 permissions) | `employee` (18 permissions, identical set) |
| Company | id 1 "WorkFlow" (own company; `X-Company: 1` accepted) | id 1 "WorkFlow" |
| Active / password set | yes / yes | yes / yes |
| Leads projects (`projects/options?led=1`) | **2** (ids 1 "QA Test Project", 2) | **0** |
| Member of projects | 1, 2 | 2 only |
| Visible tasks | 8 (1 assigned to self) | 1 (assigned to self, task 13, project 2, backlog) |
| Timesheets / meetings / conversations | 1 / 6 / 1 | 1 / 6 / 1 |
| Unread notifications | 0 of 136 | 1 of 134 |
| Employee phone (WhatsApp consent needs it) | null | null |

"Team Lead" is not a backend role: it is project leadership (`projects.leader_id`).
Permissions held by both: `account.update account.view dashboard.view
employee_reports.view_own kanban.manage_status kanban.view meetings.manage_status
meetings.update meetings.view notifications.update notifications.view
projects.view sprints.manage_status sprints.view tasks.create tasks.update
tasks.view timesheets.view` (the collection documents 17; gap A10).

**There is no dedicated QA company.** Both accounts are in company 1, which also
holds non-QA records (project 2, the shared "Team" conversation, real
notifications). Records named "QA …" exist only in project 1.

## 2. Status matrix

PASS = verified end-to-end on the real backend (API + app on the device, or API +
the app's own repository code where noted) · PARTIAL · FAIL · BLOCKED · NOT TESTED.
"Repo-live" = the app's repository/parsing code run against the live API
(`test/live/employee_live_smoke_test.dart`, both accounts, 8/8 each).

| Module | Scenario | Team Lead | Employee | Evidence | Status |
|---|---|---|---|---|---|
| Auth | Token valid, role probe `/employee/account` 200 | ✓ | ✓ | probe | PASS (API) |
| Auth | Wrong role refused (`/client/account` 403) | — | — | covered in M03; not repeated | NOT TESTED |
| Auth | Login through the app UI | owner's earlier session restored on device | — | device | PARTIAL (login screen not exercised; credentials are the owner's to type) |
| Auth | Session persistence across app restart | ✓ (reinstall + cold start kept session) | — | device | PASS (lead) |
| Auth | Logout, expired/invalid token on device | — | — | needs approval (logout revokes the token) | BLOCKED (approval) |
| Auth | Company switching | — | — | not implemented; employees have one company | NOT TESTED (no feature) |
| Profile | View profile | ✓ | ✓ | repo-live; device header | PASS |
| Profile | Edit / image / password | — | — | writes | BLOCKED (approval) |
| Dashboard | Figures load | ✓ | ✓ | repo-live; device | PASS after fixes F3, F4 |
| Dashboard | Logged hours | **320 h shown, server 160 h** → 160.0 after fix | same API values | device before/after + API | FAIL → **fixed (F3)**; device re-check PASS (lead) |
| Dashboard | Task distribution = my tasks | team-wide shown → In Progress 1 after fix | — | device before/after | FAIL → **fixed (F4)**; device re-check PASS (lead) |
| Home | Tasks card | "Projects 0" + "API doesn't provide it" | — | device | FAIL → **fixed (F5)**; device re-check PASS (lead) |
| Projects | List, status, members count, leader | ✓ (2) | ✓ (1) | repo-live; device (lead) | PASS |
| Projects | Details | ✓ | ✓ | repo-live (every listed project) | PASS (API); device sheet NOT TESTED |
| Projects | Search / filter / pagination | — | — | only 1–2 projects: no second page exists | PARTIAL (no data for paging) |
| Tasks | My Tasks (`assigned_to` = me) | ✓ 1 | ✓ 1 | repo-live (0 rows hidden); device (lead) | PASS |
| Tasks | Team Tasks | ✓ 8 | ✓ 1 | repo-live | PASS (API) |
| Tasks | Figures (`stats`) vs rows | ✓ | ✓ | `stats` follows `assigned_to` and `project_id`, ignores `status` (as documented) | PASS |
| Tasks | Task Details | **error banner, Edit never offered** | same | device + API shape | FAIL → **fixed (F1)**; device re-check PASS (lead) |
| Tasks | Details matches row | ✓ 8/8 | ✓ 1/1 | repo-live asserts id/status/assignee/project/sprint | PASS |
| Tasks | Create / edit (lead) | Edit offered on device (not submitted) | not offered (leads none) | device; widget tests | PARTIAL (no write sent) |
| Tasks | Status change | offered on own task (not sent) | own task 13 says `can.update:false` → not offered | API + device | BLOCKED (approval; see Q1) |
| Sprints/Kanban | Board loads (mine) | ✓ | ✓ (0 cards) | repo-live; device (lead) | PASS |
| Sprints/Kanban | Column count = visible cards | **2 shown, 1 card** → 1 (mine) / 2 with 2 cards (team) after fix | — | device before/after + API | FAIL → **fixed (F6)**; device re-check PASS (lead) |
| Sprints/Kanban | Backlog / planning | ✓ | ✓ | repo-live | PASS (API) |
| Sprints/Kanban | Team scope (`scope=all`) | ✓ API; device: QA Sprint 1 shows the team's 2 in-progress cards | n/a | probe + device | PASS (lead) |
| Sprints/Kanban | Move card | — | — | write | BLOCKED (approval) |
| Timesheets | Summary figures | ✓ | ✓ | repo-live; device (lead: 0/1/160 h match) | PASS |
| Timesheets | Rows / details | not shown by the app | not shown | API now returns rows (E3) | PARTIAL (feature gap) |
| Timesheets | Submit / approve | — | — | no employee route (403 boundary) | NOT APPLICABLE |
| Meetings | List, details, participants, invitations | ✓ 6 | ✓ 6 | repo-live; device list (lead) | PASS (API) |
| Meetings | Join / media / leave | — | — | needs a dedicated live meeting + approval | BLOCKED |
| Meetings | Join by code | — | — | not implemented in API mode | NOT TESTED (no feature) |
| Chat | Conversation list | ✓ | ✓ | repo-live; device (lead) | PASS |
| Chat | Messages (paged, `has_more`) | ✓ 30 | ✓ 30 | repo-live | PASS (API) |
| Chat | Open chat on device | — | — | opening sends `POST …/read` (a write) | BLOCKED (approval) |
| Chat | Send / attachments / cross-account | — | — | writes | BLOCKED (approval) |
| Notifications | Inbox, meta, unread count | ✓ 0 | ✓ 1 | repo-live (`meta.unread_count` = `unread-count`) | PASS |
| Notifications | Mark read / all | — | — | writes | BLOCKED (approval) |
| Notifications | Tap → open subject | — | — | not implemented (M10); live `subject {type,id}` now seen | NOT TESTED (no feature) |
| Reports | Employee report | `GET /employee/report` 200 | 200 | probe | NOT TESTED (no app screen; documented feature missing) |
| Settings | WhatsApp notification settings | 404 | 404 | probe; documented route | FAIL (backend/contract) |
| Prefs | Language / theme / RTL | — | — | covered by widget tests only this round | NOT TESTED on device |
| Isolation | Account switch re-reads every employee figure | — | — | widget/unit tests (F2) | PARTIAL (device switch needs the owner's login) |

## 3. Endpoint verification (live, read-only)

All employee GETs the app uses answered **200** in the `{success, message, data}`
envelope for both accounts with `X-Company: 1`. Shapes the app depends on, as
observed (keys only):

| Route | Observation | App impact |
|---|---|---|
| `GET /employee/tasks/{id}` | `data {task {id, project_id, sprint_id, assigned_to, assigned_user{…}, project{…}, sprint, title, description, status, priority, story_points, task_date, start_time, end_time, duration, work_logs[]}, duration_formatted, assigned_user_name, project_name, sprint_name}` — **nested, no `assignee`, no `can`** | was unreadable → F1 |
| `GET /employee/tasks` | rows `{id, title, description, status, priority, story_points, task_date, start_time, end_time, duration_minutes, assignee{id,name,image}, project{id,title,company}, sprint, can{update,delete}}`; `stats {total, by_status{6}, active, logged_minutes}`; `series.cost: null` | matches the app (closes E8 for rows, E14) |
| `GET /employee/dashboard` | six keys; **`myMinutes` = total minutes** (= timesheets `total_minutes`), not the remainder | was doubled → F3 |
| `GET /employee/kanban` | `stats.by_status` is whole-sprint for both scopes | → F6 |
| `GET /employee/timesheets` | rows `{id, date, month, user, company, payment_type, rate, hours_minutes, total, currency, status, can{approve,reject}}` | rows not shown (E3 can now be closed) |
| `GET /employee/notifications` | `data {notifications[], meta{current_page,last_page,per_page,total,unread_count}}`; row `{id,type,category,title,message,data,subject{type,id},actor{id,name},…}`; types seen: `task_assigned/tasks`, `chat_message/chat` | M10: subject now observable |
| `GET /employee/report` | 200 `{employee, period, summary, projects, tasks, timesheets, meetings}` | no screen |
| `GET /employee/account/whatsapp-notifications` | **404** for both (documented 200 when an employee row exists; both have one) | not used by the app |
| `GET /employee/tasks/{id}` row `can.delete` | `true` for the lead, but `DELETE` is a Permission Boundary route | app never offers Delete |

## 4. Security findings (backend)

| # | Finding | Evidence (read-only) | Severity |
|---|---|---|---|
| **S1** | **Still open.** `GET /employee/sprints/{id}` returns `tasks[].cost` with non-null values — to the **Regular Employee** too (sprint 2: 4/4 rows), and to the lead (sprints 1 and 2). Values were not printed. | probe, 2026-11-17 | HIGH — release blocker. The app does not call this route (test enforced), but any employee token can. |
| **S2** | **Confirmed.** A Regular Employee who is **not a member** of project 1 gets `GET /employee/projects/1` → **200** with the client record (`credit_limit`, `user_id`, …), the full currency row, the leader's user record and every member's `email`, `email_verified_at`, `is_active`, `must_set_password`. `GET /employee/tasks/project-employees/1` → 200 lists that project's members. | probe | HIGH — authorization defect + personal data exposure. |
| S2-ok | Correctly refused for the non-member: `GET /tasks/8` 403, `GET /sprints/1` 403, `GET /sprints/options?project_id=1` 403, `kanban`/`sprints?project_id=1` 422, `tasks?project_id=1` → 0 rows. | probe | — |
| S4 | Project details (also for members) carry other users' emails and account flags (`users[]`, `leader`), not needed by an employee. | probe | MEDIUM (data minimisation) |
| S5 | `can.delete: true` on task rows for the lead while `DELETE /employee/tasks/{id}` is documented as 403. Not exercised (destructive). | probe | LOW (misleading flag) |

Hiding fields in Flutter is not a fix for S1/S2/S4; the app shows none of the
cost, client or member-email fields.

## 5. Performance (real API)

| Measure | Result |
|---|---|
| Server latency, warm, median of 3 (lead) | account 152 ms · dashboard 125 · projects 147 · my tasks 137 · task details 156 · kanban 154 · sprints 146 · conversations 170 · messages(30) 158 · notifications(20) 173 · meetings(100) 160 · timesheets 147. First request (TLS) ≈ 450–600 ms. Responses 0.1–9.3 KB. |
| Cold start, Redmi 8, **debug** APK | `am start -W` 10.96 s to first frame; Home with data ≈ 20 s. Debug (JIT) builds are not representative — measure a `--profile`/release build for acceptance. |
| Requests when opening Tasks | 4, no duplicates (widget test, unchanged) |
| Home | + 1 request (`tasks?per_page=3&assigned_to=me`) after F5 |
| Duplicate/failed calls | none seen in the live smoke; no client-side performance defect proven. E2 (separate `per_page=1` stats call) remains by design. |

## 6. Flutter fixes in this round

| # | Defect (reproduced) | Fix | Tests |
|---|---|---|---|
| F1 | **Task Details could not read the live response** (nested `data.task`): every open showed the stale row + "couldn't load" + Retry, and **Edit was never offered** to a lead. | `BoardRepository.task` reads `data.task`, maps `assigned_user`/`assigned_to`, `project_id`, `sprint_id` (keeps only id + name of the user); `ApiTask.withPermissionsFrom` keeps the list row's server `can` (details carry none). | m07: repository test on the live shape; 2 widget tests (no error, Edit offered; `can.update:false` respected). Fail without the fix (3/3). Device: lead opens QA Task 1 → full details, ⋮ Edit Task. |
| F2 | Dashboard figures, task figures and timesheet summary did not follow an account/company switch while mounted. | The three providers watch the session scope. | `employee_session_scope_test.dart` (fails without the fix). |
| F3 | **Dashboard logged hours doubled** (320 h vs 160 h). | `myMinutes` read as the total; a remainder-style answer (< 60) still works. | unit test with the observed values. |
| F4 | Dashboard "Task Distribution" mixed the team's tasks into the personal dashboard (8 team tasks next to "Active tasks 1"). | Uses My Tasks figures (`assigned_to` = me). | `employee_api_test` asserts every dashboard task request carries `assigned_to`. |
| F5 | Home "Tasks" card showed a fabricated **"Projects 0"** and "the API doesn't provide it" for employees. | Employee (API): latest 3 of My Tasks with the real count, tap → details; elsewhere no invented count. | m07 widget test. Device: lead Home shows QA Task 1. |
| F6 | Board column count (whole-sprint `stats`) disagreed with the cards and My Tasks in "My tasks" scope (2 vs 1). | Visible-card count in own scope; server `stats` only for Team scope. | `sprint_board_api_test` updated (old assertion encoded the previous rule). |
| F7 | Task Details labelled times "Start date"/"End date". | "Start time"/"End time" (both ARBs already had them). | m07 widget test. |

Live smoke harness added: `test/live/employee_live_smoke_test.dart` (tagged
`live`, skipped unless `WF_LIVE_TOKEN` is set for the run; GET only).

## 7. Remaining issues

Backend / contract:
1. S1, S2, S4, S5 (§4).
2. `GET /employee/account/whatsapp-notifications` 404 for employees who have an employee row.
3. Task details response is undocumented and shaped differently from the row (`assigned_user` vs `assignee`, no `can`); `myMinutes` semantics undocumented.
4. **Q1 — status rights:** the Regular Employee's own assigned task says `can.update:false`, yet the role holds `kanban.manage_status`. Whether `POST /kanban/update-status` accepts the assignee is undocumented; the app follows `can.update` and offers no status change. Needs a backend answer (and Scenario B).
5. Four meetings are still `live` 2–15 days after they started (stale state).
6. No dedicated QA company; project 1 is the only "QA" project and the Regular Employee is not a member of it.

Flutter gaps (documented features not built; not changed this round):
- Employee Reports (`GET /employee/report`) — no screen.
- Timesheet rows/details — the live rows exist now; the screen still shows only the summary and an outdated "endpoints not published" banner.
- Notification tap → task/conversation (subject now observable).
- Meetings join-by-code, join-request management; WhatsApp settings.
- Minor UI: group avatar shows clipped "#Tea"; sprint card says "0 Days left" after the end date.

## 8. Device coverage (Redmi 8, API mode)

Verified by Claude on the phone, **Team Lead only**, read-only: cold start with a
stored session, Home (Tasks card after F5, notifications 136), More, Tasks (My
tasks figures and list), Task Details + ⋮ Edit Task (not submitted), Sprints
board, Projects list, Chat list, Dashboard (before F3/F4), Timesheets summary,
Meetings overview. Not done on the device: the Regular Employee (needs the
owner to sign out and sign in), Arabic/RTL and themes, anything that writes.
Screenshots stay local (the phone showed personal notifications; nothing was
committed).

## 9. Builds and tests

| Step | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | clean (151 files) |
| `flutter analyze` | No issues found |
| Full suite | **877 passed, 8 skipped** (the 8 are the gated live smoke tests); baseline 871 at `83be926` |
| `flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock` | built |
| `flutter build apk --debug` (API mode) | built and installed on the Redmi 8 |
| Live smoke (both accounts) | 8/8 + 8/8 (with F1) |

## 10. Proposed mutation plan — superseded

**Superseded by `docs/employee-mutation-plan.md`** (2026-11-17, restricted to dedicated QA records, with exact operation IDs). The table below is kept for history only; do not approve from it.

Follow-up documents: `docs/employee-device-acceptance.md` (Redmi 8 build + Regular Employee checklist), `docs/backend-security-issues-s1-s2.md` (backend report), `docs/employee-open-items.md` (Q1, WhatsApp 404, missing features).

### Original proposal (superseded)

Preconditions (owner/admin, outside the employee portal):
- P1. Add the Regular Employee to **project 1 "QA Test Project"** (or name another project that is safe to write to). Without it, Scenario A must run in project 2, which holds non-QA data.
- P2. Confirm `WHATSAPP_NOTIFICATIONS_ENABLED` on api.workflownets.com, or confirm the Regular Employee has not opted in (phone is null, so consent should be impossible).
- P3. Create one dedicated QA meeting (Scenario G) — employees cannot create meetings (403).

| Step | Account | Request(s) | Creates / changes | Side effects | Cleanup |
|---|---|---|---|---|---|
| A1 | Lead (app) | `POST /employee/tasks` in project 1, title "QA E2E 2026-11-17", unassigned, status todo | 1 task | none | Employees cannot delete tasks (403): the record stays; owner/admin deletes it or it is marked completed and renamed "QA — disposable". |
| A2 | Lead (app) | `PUT /employee/tasks/{new}` `assigned_to` = Regular Employee | assignment | `task_assigned` in-app notification; WhatsApp only if P2 says enabled + consent | reassign to none |
| A3–5 | Employee (device, owner logs in) | GETs: My Tasks, details | — | — | — |
| B1 | Employee | `POST /kanban/update-status` todo→in_progress (if the app offers it; else via approved probe to answer Q1) | status | possibly notification | lead sets it back |
| B2 | both | GETs: Tasks, Dashboard, Project details, Board | — | — | — |
| C1 | Lead | `PUT /tasks/{new}` title/description | edit | none documented | — |
| C2 | Employee | `PUT /tasks/{new}` (approved negative test) | expected **403** (not a lead) | none if refused | — |
| D | — | Timesheets have no employee write route (view only; approve/reject 403) | — | — | NOT APPLICABLE |
| E1 | Lead | `POST /employee/conversations` direct with the Regular Employee | 1 conversation | chat notification | `DELETE …/{id}` (delete **for me**, ⚠️) by both |
| E2 | Lead → Employee → Lead | 2–3 text messages, 1 small PNG attachment | messages | `chat_message` notifications | messages cannot be deleted by employees (stay) |
| E3 | Employee | open chat → `POST …/read` | read state | — | — |
| F | Employee | `POST /notifications/{id}/read`, then `read-all` | read flags | — | irreversible (read state) |
| G | both | `POST /meetings/{qa}/media/join`, `media/state`, `media/leave` on the P3 meeting only | participant rows | LiveKit room join; mic/camera prompts | leave; host ends the meeting |
| H | owner | sign out on the device (`POST /logout`), sign in as the other account | revokes the stored token | — | the owner re-runs the login helper for Claude's token if needed |

Irreversible: E2 messages, F read state, the A1 task row (without an admin).
Nothing in the plan touches records outside project 1, the new conversation and the QA meeting.

## 11. Commits

| SHA | Content |
|---|---|
| `a662c3a` | Flutter fixes F1–F7, regression tests, opt-in live smoke test |
| (this commit) | This report and `docs/api-contract-gaps.md` (E17–E21, S1/S2 update) |

`a662c3a` and `048ac6a` were pushed (non-force) to `origin/feat/m01-batch2-emulator-fixes` on the owner's approval; remote head `048ac6a2d392301e4995f0b9e72563c30acc5872`. Not merged into `main`. M08 not started.
