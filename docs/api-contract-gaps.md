# WorkFlow API contract gaps

The Flutter app integrates only what the Postman collection **WorkFlow**
(Hala's Workspace) documents. This file records what the collection leaves
open, how the app handles it today, and what is needed to close it.

| | |
|---|---|
| Contract source | Postman collection `WorkFlow`, uid `56083386-d0da80f4-f067-42e4-9b96-9e021769e55e`, created/updated 2026-11-14 11:14 UTC · 1096 requests (968 method+path pairs) |
| Superseded | `WorFlowNets` (uid `56083386-3bd0b0e2-…`, 991 requests) and `https://work.isradev.shop` — not authoritative any more |
| Backend | `https://api.workflownets.com` (`API_BASE_URL`, host only; routes are under a single `/api/v1`) |
| Live verification | 2026-11-14, read-only GETs with a QA **employee** token (injected by the session proxy, never printed). No client token was available. No logins, registrations or other writes. |

Status: **Open** = needs backend or product input · **Handled** = the app
works around it without inventing anything · **Deferred** = planned for a
later milestone · **Resolved** = closed by the new collection.

## What changed from WorFlowNets to WorkFlow

- Route table re-synced 2026-11-12. 102 method+path pairs added, 6 removed,
  72 changed in description, body, query, headers or tests (all roles).
- `01 Auth`: the 12 user-facing requests are unchanged. Only the LiveKit
  webhook moved to the new folder `06 Integrations & Webhooks`.
- Employee/Client additions relevant to this app: paged conversation
  messages (`GET /{role}/conversations/{id}/messages`), employee
  `GET /meetings/by-code/{code}`, meeting join requests, admission mode,
  cancel and media state, `GET /employee/employees/options`, WhatsApp
  notification settings (employee), and a Claude Connector module.
- Removed for the employee: `GET /employee/conversations/conversations/available-users`
  (replaced by `/employee/conversations/available-users`) and
  `POST /employee/meetings/{id}/guests`. The app used neither.
- Task create/update now accept the same status values as the list filter.
- Both collections' safety gate names `workflow.aliservice.site` as the
  production host; it does not recognise `api.workflownets.com`, so the
  collection's own "never run destructive requests on production" guard does
  not fire there. **Backend team should update the gate.** Until they confirm
  otherwise, **`api.workflownets.com` is treated as production**: no
  Collection Runner, no request trusted because it is labelled safe, and
  every write needs the owner's explicit approval
  (see `docs/m03-live-auth-test-plan.md`).

## M03 — Authentication & session

| # | Gap | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| A0 | Login credentials travel in the JSON body; the session's secure credential handling injects headers only. | Handled | Live login/logout is a device step for the owner; Claude verifies with injected bearer tokens (`docs/m03-live-auth-test-plan.md`). | — |
| A1 | `POST /api/v1/login` documents only `data.token`, `data.token_type`, `data.user.id`, `data.user.company_id`. No role. Unchanged in WorkFlow. | Handled | The app confirms the chosen portal with `GET /api/v1/{portal}/account` before opening a session. **Live:** an employee token gets 200 on `/employee/account` and **403** "You are not authorized to access this resource" on `/client/account`. On 403 the token is revoked and nothing is stored. | The live profile returns undocumented `roles[].name`, `roles[].permissions`, `must_set_password`, `is_active`, `employee`, `client`. If the collection documented `roles[].name` (or a role on the login user), the app could route without the extra request. |
| A2 | Login 403 for deactivated / unverified / no-password accounts differs only by `message`. | Open | The server message is shown as given. | A machine-readable reason (e.g. `errors.reason`). The live profile's `must_set_password` / `is_active` / `email_verified_at` suggest the data exists. |
| A3 | OTP length undocumented (`verify-email-otp`: `otp` string; `verify-otp-forgot-password`: `otp` numeric). | Open | 4 boxes per Figma (137:26665). | Code length and alphabet. |
| A4 | `POST /api/v1/account/setup` (invited users, emailed `token`, password `min:8`) has no app flow. | Open | Not offered. | A Figma frame and a decision on how the token reaches the app (deep link vs. paste). |
| A5 | Link-based `GET /verify-email-token`, `POST /reset-password-form`. | Deferred | OTP flows are used. **Live:** `verify-email-token` without a token answers 404 in the envelope. | Only with deep links (A4). |
| A6 | No refresh endpoint; token lifetime undocumented. | Handled | A 401 ends the session and the sign-in screen says so. **Live:** unauthenticated role routes answer 401 `Unauthenticated.` in the envelope. | Token lifetime, to warn before expiry. |
| A7 | `POST /account/setup/resend` is Bearer-authenticated (admins only). | Handled | Sent with the token; the app never calls it. | — |
| A8 | Register: no Figma confirmation field; optional `image` has no control. | Handled | Single password sent as `password_confirmation`; no `image`. | — |
| A9 | Client company context: tenancy runs through the approved `client_company` pivot; login `company_id` may be null. Unchanged. | Open (product + backend) | `X-Company` only when known; otherwise the server falls back to the account's own company (SEC-006). **Live:** the QA client has `company_id = null` and the dashboard and lists answer without the header. Session switches are covered by tests: a new account never sees the previous account's data or headers. | How a client with several approved companies chooses the active one, and whether client routes should send `X-Company` at all. No switch is built until this is documented. |
| A10 | The employee role is documented with 17 permissions; the live QA employee holds 18. | Open (informational) | No app impact. | Backend to reconcile the seeder and the collection. |

## Employee API (later milestones)

| # | Gap | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| E1 | `GET /employee/tasks` `facets`. | Open (worked around, M07) | **Live (2026-11-14):** `facets {projects: [], assignees: []}` — element shape unknown. M07 builds the project filter from the documented `GET /employee/projects/options` (`[{id,title,…}]`) and sends the documented `project_id`; no assignee filter (its option list for a lead would need E12). | A documented facet element, or a QA account with tasks. |
| E2 | Two `GET /employee/tasks` calls per Tasks screen (`stats` then rows). | Deferred (performance) | Both return `stats`. | Whether `stats` ignores the filters; then one request is enough. |
| E3 | `GET /employee/timesheets` row shape. | Open | Prose only (`hours_minutes`, `payment_type`, `rate`, `total`, `currency`, `can{approve,reject}`). **Live:** top-level `stats`, `totals`, `available_months`, `facets {employees}`; the paginator also carries `links`/`meta`; **no rows** for the QA account. Rows are not shown in the app. | A documented row example or a QA account with timesheets. |
| E4 | Employee timesheet approve / reject / delete → 403 (Permission Boundary). Unchanged. | Handled | Cards are view-only. | — |
| E5 | Task status sets were inconsistent (create/update used `waiting_review`, `done`). | **Resolved** | WorkFlow: create/update accept `backlog, todo, pending, in_progress, in_review, completed` plus legacy aliases `waiting_review` → `in_review`, `done` → `completed`. The app's list filter already used the canonical set. | — |
| E6 | Employee dashboard keys the app requires (`myTasks`, `myHours`, `myMinutes`, `totalEarned`, `paidSalary`, `unpaidSalary`). | Handled | **Live:** exactly these six keys. | Documenting them in the collection. |
| E7 | My Tasks: `GET /employee/tasks?assigned_to={users.id}`. | Handled (mock-verified) | Documented query parameter (List Tasks; the collection's example uses `{{user_id}}`, the login `data.user.id`). The app sends the session's `userId` for My Tasks (the default) on both the rows and the `stats` request, and **still checks every row**: one whose `assignee.id` is not the user's — another person's, unassigned, or without an id — is left out and a notice says how many. Team tasks drops the filter (every task `tasks.view` lets the account see; the backend decides). **Not verified live:** the QA employee has no tasks, and whether `stats` follows `assigned_to` is not stated (the collection only says it ignores `status`). | A QA employee with tasks assigned to them and to others in one project; a row example with `assignee {id, name}`. |
| E8 | Task row and details shape. | Open | No row example for `GET /employee/tasks` or `GET /employee/tasks/{task}`. The app reads `description` (a create/update field) and `assignee.id` besides the fields listed in `ApiTask`. Details are read from `GET /employee/tasks/{task}`; on failure the list row stays on screen with a retry. | A response example for both routes. |
| E9 | Due date, subtasks, attachments, comments, actual time for tasks. | Not in the API | The collection: "there is no `due_date`" and `task_date` is the planned work date; no task subtask/checklist, attachment or comment routes; no time-actual field on tasks (time is logged through timesheets). The app shows none of them for API tasks (no due date on the card; planned date, start/end and duration in the details). | Backend fields/routes if the product wants them. |
| E10 | Task edit/delete for employees. | Handled (M07: create/edit for leads, mock-verified) | `POST /employee/tasks` and `PUT /employee/tasks/{task}` work only on projects the employee **leads** (403 otherwise); `DELETE` is a Permission Boundary route (403). M07: Add Task and Edit are offered only for projects in `GET /employee/projects/options?led=1` (rows naming another `leader_id` are ignored); Edit also requires freshly loaded details and a row without `can.update: false`; the update sends only changed fields. 403/409/422 are shown in the form. Delete is never shown. **Never sent live.** | Live check with a QA lead account (needs the owner's approval: creates/edits are real writes; assigning may send WhatsApp). |

## M07 — Employee projects, tasks and sprints (2026-11-16)

Collection re-read 2026-11-16: still **updatedAt 2026-11-14T11:14:33Z**.
**No live check was possible**: both configured employee QA tokens answer
401. Full matrix: `docs/m07-employee-work.md`.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| E11 | Planning and board key names differ between description and test script. | Open (informational) | Kanban: description `{…, sprint, …}`, test asserts `data.active_sprint`. Planning: description `backlog{…}`, test asserts `data.backlog_tasks`. The app reads `sprint` and `backlog` (both seen live 2026-11-07); a missing `backlog` is an invalid response, never an empty list. The planning backlog has no documented page parameter (first page only; "Showing N of M"). | Backend to align the description and the tests; a documented backlog page parameter. |
| E12 | Assignees a lead may choose. | Open | A lead may assign only project members (422 `assigned_to` otherwise). The documented `GET /employee/employees/options` (`[{user_id,name,image}]`) lists every active company employee, so the form shows that list with a hint and shows the server's 422. `GET /employee/tasks/project-employees/{project}` (list) and `GET /employee/tasks-data/{company}` (`projects`, `employees`) would be exact but have no documented row. | A documented row for `tasks/project-employees/{project}`. |
| E13 | Project members and roles. | Open | Live rows carry `leader {id,name}` and `members[]` (undocumented); no member role exists. The app shows the leader's name and the member count only. | Documented `members[]` element (and a role, if wanted). |
| E14 | Task relation ids. | Handled | Rows are documented as `{…, assignee, project, sprint, can{update,delete}}` without the relation's fields. The app reads `project.id`/`sprint.id` (as it already read `assignee.id`) only to decide whether a lead may edit and to open related lists; without them Edit is not offered. | Row example (E8). |
| E15 | CSV exports (`projects/export`, `tasks/export`, `sprints/backlog/export`). | Missing (product) | Documented for employees (cost/budget columns left out). Not built: needs a decision on saving/sharing CSV on Android. | Owner decision. |
| E16 | Sprint lifecycle for employees. | Blocked (by design) | Create, update, delete, start, complete and move-task are all in Permission Boundary (403). The "Create Sprint" button, which only explained this, was removed in API mode. | — |

## Employee E2E QA — live read-only (2026-11-17)

Two QA employee accounts (a project lead and a regular member), company 1,
read-only GETs. Full report: `docs/employee-e2e-qa-report.md`.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| E17 | `GET /employee/tasks/{id}` shape | Handled (F1) | Live: `data {task {…, project_id, sprint_id, assigned_to, assigned_user, project, sprint, work_logs}, duration_formatted, assigned_user_name, project_name, sprint_name}`; no `assignee`, no `can`. The app now reads `data.task` and keeps the list row's `can`. Before: Task Details always failed and Edit was never offered. | Document the response (and a `can` block). |
| E18 | Dashboard `myMinutes` | Handled (F3) | Live: total minutes (equals timesheets `stats.total_minutes`), not minutes past the hour. The app added both and doubled the hours. | Document the semantics. |
| E19 | Kanban `stats.by_status` ignores `scope` | Handled (F6) | Whole-sprint counts in both scopes; the app counts visible cards in the user's own scope. | — |
| E20 | Status rights of an assignee | Open (Q1) | The regular employee's own task says `can.update: false` although the role holds `kanban.manage_status`. The app offers no status change then. | Backend: may an assignee move their task on the board? |
| E21 | WhatsApp settings route | Open | `GET /employee/account/whatsapp-notifications` → 404 for both accounts (both have an employee row). | Deploy or document. |
| E3 | Timesheet rows | Now observable | Rows `{id, date, month, user, company, payment_type, rate, hours_minutes, total, currency, status, can{approve,reject}}`; `GET /timesheets/{id}` and `/details` 200. The app still shows only the summary. | Build the list (product). |
| M10 | Notification subject | Now observable | `subject {type: task\|conversation, id}`; types `task_assigned`/`tasks`, `chat_message`/`chat`. | Build tap → open (product). |
| S1 | Task cost in sprint details | **Still open** | `GET /employee/sprints/{id}` returns non-null `tasks[].cost` to the regular member as well. | Backend fix. |
| S2 | Projects outside membership | **Confirmed defect** | A non-member gets `GET /employee/projects/{id}` 200 with client, leader and member emails; `tasks/project-employees/{id}` 200. Tasks, sprints and boards of that project are refused (403/422). | Backend fix. |

## Client API, conversations and meetings (later milestones)

| # | Item | Status | Evidence |
|---|---|---|---|
| C1 | Client conversation permissions | Unchanged | The client folder still lists conversations as usable (list, show, create, update, delete, members, messages multipart, read, image) although the 9 client permissions name none: membership is the authorization. New: `GET /client/conversations/{id}/messages` (cursor-paged, `meta {has_more, oldest_id, newest_id}`, side-effect free; "static audit; not yet executed against a server"). |
| C2 | Conversation field names | Handled (employee) | The app reads fields the collection does not document. **Live (employee):** all of them are present on api.workflownets.com. Client side not re-checked (no client token). |
| C3 | Client dashboard keys (`projectsCount`, `projectsCompleted`, `projectsInProgress`) | Handled | **Live (client QA, 2026-11-14):** exactly these three integers. Still undocumented in the collection. No trend, growth or financial figures exist, so none are shown. |
| C4 | Client company endpoints | Partly handled (M04) | Only `GET /client/companies` ("List My Companies", test asserts `data`) and `POST /client/companies/{id}/join` (no body; 200/401/403/404/409). **Live:** `data` is a plain list. **2026-11-22 (Redmi 8 F1, read-only probe, no `X-Company` because the client's login has `user.company_id: null`):** HTTP 200, `{success: true, message: "Companies retrieved", data: [1 row]}`, and each row is the **membership**, not a company: `{status: "approved", client: {id, name, email, created_at, updated_at}, company: {id, name, email, domain, logo, created_at, updated_at}}`. The app read `id`/`name` from the row itself, so both were missing and every load ended in "Something went wrong" (`invalidResponse`) — a Flutter mapping defect, fixed: the company is read from `row.company` (a flat row is still accepted); test `client_companies_live_shape_test.dart`. `GET /client/dashboard` and `GET /client/account` answered 200 for the same token; the account has `company_id: null` and `company: null`. The membership still says `approved` although the account received a "Removed from company" notification — a backend question (see F2 in docs/redmi8-r1-r4-qa-report.md), not decided here. **Open:** (1) the row shape (now observed, still undocumented in the collection) and the membership `status` (`pending`/`approved`/`rejected` are documented only on the admin routes) — not shown until documented; (2) no route lists companies a client could join, so the app has no id for `join` and offers no Join button in API mode; (3) no leave or cancel route. The active-company switch is now handled through `X-Company` (C31). |
| C9 | Client projects | Handled (M04) | List: `search`, `status` (`pending`/`in_progress`/`completed`), `page`, `per_page`; `stats` is required (**live:** present, with `facets {statuses, clients}`, `totals`, `series`). Details: `GET /client/projects/{id}` (test asserts `data.id`) is loaded when details open; **live:** an unknown id answers 404 "Project not found". No client project write route exists (create/edit/delete are not offered; the Add Project button explains this). Row fields beyond the documented list fields (`description`, `users`) are not read. |
| C10 | QA data for M04 | Open | The client QA account has **no company and no project**, so company, project-list and project-details flows are verified only with mocked responses. Needed: an isolated QA company with the QA client **approved** in it (and ideally a second company with a **pending** request), ≥ 3 projects for that client in mixed statuses (`pending`, `in_progress`, `completed`) and > 10 projects for paging, one project with a leader and members. |
| C5 | Meeting creation | Unchanged (blocked) | `POST /employee/meetings` remains in Permission Boundary (403); the client has no create route. |
| C6 | Join by code | Partly new | Employee: `GET /employee/meetings/by-code/{code}` → `data {id}` only for meetings the caller may access, else 404. Client: no by-code route. Public guests: `GET /meeting-guest/preview/{code}`, `POST /meeting-guest/enter` (no account). All "static audit; not yet executed against a server". |
| C7 | Client join may now answer **202** `{join_request}` in an `approval` meeting (2026-11-04). | Deferred (meetings milestone) | The app does not call `POST /meetings/{id}/join` in API mode today; the join flow must handle 202 when it does. |
| C8 | Attachment upload | Unchanged | Upload exists only for conversation messages (multipart), conversation image and account image. Meeting attachments are download-only for client and employee. |

## M06 — Client communication (2026-11-14)

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| M1 | Conversation history | Handled | `GET /client/conversations/{id}/messages` (`limit`, `before_id`, `after_id`; `{data[], meta {has_more, oldest_id, newest_id}}`, "static audit; not yet executed against a server"). The chat loads the latest page, "Load earlier messages" pages back, and an open chat polls `after_id` every 10 s; messages merge by id. **Message row fields are undocumented**; the app reads the same fields as the conversation detail (live on the employee account). | A documented message row; live check with a QA conversation. |
| M2 | Create conversation | Handled (mocked) | `POST /client/conversations` `{users[], type, title?}` → 201 `data.id`. People and the type come from `GET …/available-users`, **response undocumented**; live shape (client): `{role, default_type: client_chat, can_create_group: false, users[{id, name, image}]}`. Groups are offered only when `can_create_group`. Never sent live. | Documented `available-users` response. |
| M3 | Conversation refresh | Handled | No realtime channel for conversations in the app: the list refreshes every 30 s, an open chat polls every 10 s; neither replaces the screen with a spinner. | A realtime channel, if wanted. |
| M4 | Conversation attachments, image, members | Handled (mocked) / Open | **Sending:** `file_picker` (system picker, no storage permission) → selected-file chips, removable before Send; ≤ 5 files and ≤ 10 240 KB checked **before reading** (size from the picker) and again by content (JPEG/PNG/GIF/WebP/PDF/text); `files[]` multipart with `type` image/file, progress, Not sent + Retry, no duplicate uploads; the picker's cached copies are deleted after reading. **Receiving:** ids from `messages[].attachments[].id`; `GET /api/v1/conversations/{c}/attachments/{a}` (`X-Company` added); images and text previewed from memory; **every file (PDF included) can be saved** through the system save dialog and opened from the Files app — the app keeps no copy. **Only `id` is documented** for an attachment (name/type come from the download headers). Members add/remove/role: not offered (no documented member role). Never sent live. | A documented attachment object (`file_name`, `mime_type`, `size`); documented member role; QA conversation with attachments. |
| M5 | Meeting join | Handled (mocked) | `POST /client/meetings/{id}/join`: 200 participant (`id`, `connection_status`) or **202** `{join_request}` in an approval meeting. Join is offered for waiting/live meetings; 202 shows "The host must admit you"; leave via `POST /client/meeting-participants/{id}/leave`. The client has **no** join-request status route: the pending state is kept per account and company (reopening the meeting never offers a fresh Join), and "Try joining again" is the only way to learn the outcome (200 joined, or the server's refusal shown in the card). Never sent live. | Client route to read/cancel its own join request (employees have `GET/DELETE …/join-request`). |
| M6 | Meeting media (LiveKit) | Implemented (mocked); **live unverified** | `livekit_client` + `permission_handler`. Join from the meeting details opens the room: microphone permission (required) and camera (optional — refused means audio only), `POST /client/meetings/{id}/media/join` `{device_id}` → `participant.id` + `media {token, url, room}` (`wss`/`https` only) → LiveKit room; 202 shows waiting for the host with "Try joining again"; mute/camera (room first, then `media/state`), remote participants with video, reconnecting banner, dropped-room handling; Leave, Back, account or company switch release camera/microphone/room and send `media/leave` for this device (also after a room fails to connect). LiveKit SDK logging is disabled (tokens never logged); the token is redacted and kept out of state. **`media/join` vs `join`:** the collection describes `media/join` as "Joins the meeting and returns participant + LiveKit media token", with the same 202 approval rule, so the room uses `media/join` alone; this is documentation evidence only, **not verified against the server**. The older `join` card remains only where no media engine exists. Open: whether LiveKit is configured on `api.workflownets.com` (500 otherwise), the media `url` per environment, token lifetime/refresh. | Backend confirmation of LiveKit configuration and `media/join` semantics; a QA approval meeting; separate approval for live joins. |
| M7 | Per-meeting invitations | Handled | `GET /{role}/meetings/{id}/invitations` exists for employees only; **live:** the client route does not exist. The app calls it only for employees. | — |
| M8 | Join by code (client) | Open | Employees have `GET /meetings/by-code/{code}`; clients do not. The client "Join by code" chip explains it is unavailable. | Client by-code route. |
| M9 | Notifications | Handled | `GET /client/notifications` (`status`, `per_page`, `page`), `unread-count`, `POST {id}/read`, `POST read-all`. `meta` counts, `is_read` and `unread_count` are now required (no guessed page or 0). The collection's §7 "no Notifications API" line is outdated. | — |
| M10 | Navigation from a notification | Open (rechecked M06b-2) | Collection re-read (updated 2026-11-14T11:14:33Z, unchanged): only the **presence** of `type`, `category`, `data`, `subject`, `actor` is asserted — no `type` values, no `subject`/`data` shape, no example, and §7 still says "no Notifications API" (outdated). Live client inbox: 0 items. Tapping marks read; no route or id is guessed. The badge reloads on resume after 60 s (one request for all bells). | Documented `type` values, `subject {type, id}` (or a route) per type, or an authorized QA notification to inspect. |
| M11 | Rename / delete for me | Handled (mocked) | `PUT /client/conversations/{id}` `{title}` (≤ 255) → `data.id`; offered for **group** conversations only (a direct chat is named after the person). `DELETE /client/conversations/{id}` ("Delete Conversation For Me" ⚠️) after a confirmation; the chat closes and the list refreshes. Who may rename is decided by the server; a refusal shows its reason. Never sent live. | Live check with a QA group conversation. |
| M12 | Send response | Handled | The send test asserts `data.message.id` and `data.message.conversation_id` only. When `data.message` is a full message row it is shown at once; otherwise the next poll (from the last **polled** id, so nothing between is skipped) brings it. | A documented send response. |

## Remaining Employee features — live read-only (2026-11-18)

Collection re-read in full: still **updatedAt 2026-11-14T11:14:33Z**.
Both QA employee tokens valid. Read-only GETs only. Full report:
`docs/employee-remaining-features.md`.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| E3 | Timesheet rows | **Handled** | Rows and `GET /timesheets/{id}/details` are shown (status/month filters, paging, details grouped by project). `hours_minutes` is total minutes (live 9600 = 160 h). Per-task `cost` of the details is not shown. | Document the row (the prose names only some keys). |
| E12 | Assignees a lead may choose | **Handled** | `GET /tasks/project-employees/{project}` rows `{id, name}`; `id` = `users.id` (live: the lead's row is the login user id). The form lists only these; the company-wide list is no longer used for assigning. | Document the row. |
| E15 | CSV exports | **Handled** | Tasks, projects, timesheets, backlog: one Export CSV chip with the list's filters; system save dialog (`file_picker`, as for attachments). Live: `text/csv; charset=UTF-8`, BOM, `attachment; filename="…-YYYY-MM-DD.csv"`, no Cost/Currency for employees. A 200 that is not CSV is never saved. | — |
| M10 | Navigation from a notification | **Handled (employee)** | Live `subject {type, id}`: `task`, `conversation`, `meeting`. Tap marks read and opens the task (by id), chat or meeting. Unknown types only mark read; clients never open a task. | Document `subject` types per notification `type`. |
| C6 | Join by code (employee) | **Handled** | `GET /employee/meetings/by-code/{code}` → details; 404 (live) reads "No meeting with this code that you can open". No room password is sent (not in the route). | — |
| E22 | `List Timesheets` test out of date | Open (contract) | The test asserts `data.timesheets.data`, `data.summary`; the server and the description put the paginator in `data` and `stats`/`totals`/`available_months` beside it. | Update the collection test. |
| E23 | Report `task_completion_rate` unit | Open | 0–1 or 0–100 undocumented (live 0). Not read: the app shows completed of total from the documented counts. | Document the unit. |
| E24 | Own join request `status` values | Open | Only `pending` is documented (admit/reject say "409 when no longer pending"). The app interprets `pending` only and shows other values as sent. `DELETE` never sent live. | Document the values. |
| E25 | Task opened by id has no `can` | Open (E17) | Task details carry no `can`; a task opened from a notification, the report or a timesheet offers **no** status change (Edit still follows leadership). | A `can` block on `GET /tasks/{id}`. |
| E26 | Employee report screen design | Open (design) | No Figma frame; built from existing components (masthead, chips, metric group, cards). | A Figma frame or design sign-off. |
| E21 | WhatsApp settings route | **Open (backend)** | Now answers 404 "The route api/v1/employee/account/whatsapp-notifications could not be found" — not deployed, not an employee-row problem. | Deploy the route. |

## Client C1 + C2 — home, CSV exports, payment details (2026-11-19)

Collection re-read: still **updatedAt 2026-11-14T11:14:33Z**. No live client
request was made with a token (no client QA token is stored; employee tokens
were not substituted). Route registration only, unauthenticated GET:
`client/invoices/export`, `client/payments/export`, `client/payments/{id}` →
401 (registered). Everything below is verified with mocked responses only.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| C11 | Client invoice CSV export | Handled (mocked) | `GET /client/invoices/export` with the list's `status`, `sort`, `search`, `from`, `to`, `project_id` and no `page`/`per_page` (one builder for list and export). `text/csv` + BOM saved byte for byte through the system save dialog; a non-CSV 200 is never saved; 422 (> 10 000 rows) says to narrow the filters; a cancelled save shows no message. `ids[]` and `client_id` are not sent (no row selection; the client is the caller). "↓ Export Report" placed as in Figma 643:36002. | Live export with QA invoices (C10). |
| C12 | Client payment CSV export | Handled (mocked) | `GET /client/payments/export` with the list's `status`, `search`, `from`, no paging; same file and error rules as C11. The list sends no `to`, `type`, `payment_method`, `wallet_id` or `invoice_id`, so the export does not either. Placed as in Figma 643:35269. | Live export with QA payments (C10). |
| C13 | Client payment details | **Blocked (contract)** | `GET /client/payments/{id}` (`Admin\PaymentController@show`) documents only `data.id`; there is no example in any role (super admin, company admin, client). The company-admin *list* example has `id, invoice_id, wallet_id, amount, payment_method, payment_date` (plus `direction` from the description), but `show` may add or rename fields (relations, status, currency). The QA client has no payment, so no live id exists to read. Details stay the list row; no field is guessed. The live client smoke prints the `show` key names once a QA payment exists. | A documented `show` response (fields, types, `status` values, currency, related invoice/wallet), or a QA payment (C10) to read once. |
| C14 | Client home (Figma 534:30390) | Handled | The frame shows a Tasks card, but the client role has no task route. In API mode a client's home is the masthead plus notifications; the employee home and demo mode keep the card. | — |
| C15 | Client live smoke | **Blocked (credentials)** | `test/live/client_live_smoke_test.dart` (tag `live`, `WF_LIVE_CLIENT_TOKEN`): GETs only, including both exports and a payment-details key probe; prints counts, flags and key names only. Skipped: no client token. | The owner runs the login helper for the client QA account. |

## Client C3 — meeting collaboration, read-only (2026-11-19)

Collection re-read: still **updatedAt 2026-11-14T11:14:33Z**. Every
collaboration route is `permission: meetings.view` and shares its controller
across roles. **Live access rule** (read-only GETs, employee QA lead token,
company 1, the 6 meetings it can list, 2026-11-19): `messages`, `polls`,
`notes`, `decisions` and `action-items` all answer **403** "You must be a
participant of this meeting to use its …" — the lead is invited/visible but
has not joined. No row could be observed, and joining is a mutation that
was not sent. This is shape/authorization evidence about the shared
controllers only; **no client request with a token was made**. All C3
behaviour is verified with mocked responses.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| C16 | Meeting chat history | Handled (mocked) — **row partly undocumented** | `GET …/meetings/{id}/messages` (`per_page`, `after_id`, `before_id`): paginator `data.data[]`. Documented: `id` (test), `message` (`StoreMeetingMessageRequest`), `attachments[].id` (send test). **No sender, time, reply or read field is documented**, so messages show text and files only, ordered by id; nothing is guessed. Older pages via `before_id` (paginator `last_page` > `current_page`); refresh via `after_id`. Sending: see C24. | Documented message row (`user {id, name}`, `created_at`, `type`, attachment `file_name`/`mime_type`/`size`); a QA meeting the client has joined. |
| C17 | Meeting attachments | Handled (mocked) | `GET …/meeting-attachments/{id}/download` streams the file; id from a chat message. Name from `Content-Disposition`; images/text previewed from memory; every file can be saved through the system dialog (same path as conversation attachments). Only `id` is documented. | Documented attachment object; a QA attachment. |
| C18 | Meeting polls | Handled (mocked) — **results blocked** | `GET …/meetings/{id}/polls` (`data` list, `id`), `GET …/meeting-polls/{id}` (requires `id`, `options`; option `{id, title}`). Question from `StoreMeetingPollRequest.question`. **Per-option counts, the caller's own vote, `show_results`/`anonymous` on read and poll `status` values are not documented**, so no result is shown and the panel says so. Voting: see C25. | Documented poll read model (option `votes_count`/percent, `my_vote`, `status` values, `show_results`, `multiple_choice`, `allow_change_vote`). |
| C19 | Meeting notes | Handled (mocked) | `GET …/meetings/{id}/notes` (`data` list). Fields from `StoreMeetingNoteRequest`: `title` (nullable), `content` (required — missing is an invalid response), `status` (`draft`/`published`; draft shows a badge), `is_shared`. Which notes a client receives (shared only? drafts?) is the server's rule; the app shows what it gets. | Documented note read model and visibility rule for clients. |
| C20 | Meeting decisions | Handled (mocked) | `GET …/meetings/{id}/decisions` with the documented `status` filter (`pending`/`approved`/`rejected`, else 422). Fields from `StoreMeetingDecisionRequest`: `title` (required), `description`; `assigned_to` is an id only and is **not shown** (no name documented). Unknown status values get no badge. No approve/reject (403 for clients). | Documented decision read model (assignee name, `status`, timestamps). |
| C21 | Meeting action items | Handled (mocked) | `GET …/meetings/{id}/action-items` with `status` (`pending`/`in_progress`/`completed`/`cancelled`). Fields from `StoreMeetingActionItemRequest`: `title`, `description`, `priority` (`low`/`medium`/`high`/`urgent`), `due_date`; `assigned_to` id not shown. `assigned_to` filter not used (no people list for clients). | Documented action-item read model (assignee name). |
| C22 | Whiteboard | Not built | `GET/PUT …/whiteboard`, elements, undo/redo: element schema undocumented and the frame (672:5264) is a drawing surface — out of the read-only scope. | Element schema; a decision on read-only whiteboard. |
| C23 | Decisions / action items design | Open (design) | Figma has room frames for chat (670:2505), polls (671:3024), notes (672:5044) only. Decisions and action items reuse the notes panel layout and the documented status vocabulary. | A frame or design sign-off. |

## Client C4 — meeting collaboration interactions (2026-11-20)

Collection re-read: still **updatedAt 2026-11-14T11:14:33Z**. The client
prefix (`05 Client / 07 Meetings`) documents exactly **two** collaboration
writes with `permission: meetings.view`: `Send Chat Message` and `Vote In
Poll`. Every other collaboration write registered under `/client` needs
`meetings.update`, which `RolePermissionSeeder` does not grant to clients;
the collection lists them in `08 Security & Negative Tests / 02 Permission
Boundary (expected 403)`. Approve/reject decision routes exist only for
super admin, company admin and employee. **Nothing was sent to a live
server**: no message, upload, vote, join or edit. All C4 behaviour is
verified with mocked responses (unit, contract and widget tests).

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| C24 | Send meeting chat message (+ one file) | Handled (mocked) | `POST /client/meetings/{id}/messages` (`Admin\MeetingMessageController@store`, expected 201, test requires `data.id`). Text alone: JSON `{message}` (≤ 5000, trimmed; the field limits input). With a file: multipart, single key `file` (BE-28), plus `message` when there is text. File checked on its content before upload: ≤ 10 240 KB and one of jpeg/png/gif/webp/pdf/txt/mp4/mp3/zip; refused files never cost a request. Attach button only when the meeting has `allow_file_share`. One send at a time (double tap = one request); text and file kept after a failure with Retry; after 201 the chat reads `after_id` and scrolls to the end. 403 → "only participants can send"; 422 → the server's field message when safe to show; 401 → the app-wide sign-out. The send bar appears only once the chat could be read (a non-participant sees the 403 notice instead). `reply_to_id` is documented but not offered (no reply design, and the read model has no reply field). | A client QA meeting the client has joined, and approval for one live send. Undocumented: the created message's full shape (sender, time) — the app re-reads the chat instead of trusting it. |
| C25 | Vote in a meeting poll | Handled (mocked) — **single choice only** | `POST /client/meeting-polls/{id}/vote` with `option_ids` (required array, min 1, integers from the poll's `options`); response test requires `data.id`, `data.total_votes`. The app sends **one** option id because `multiple_choice` is not on the poll read model (sending one is valid for both kinds). After 200: "Vote recorded · N votes in total" from `total_votes`, and the poll and poll list are read again. One vote at a time; the same choice is not re-sent. Whether a vote may be changed (`allow_change_vote`) or a closed poll refuses it is the server's rule: a 422/403 is shown and the Vote button retries. Per-option results are still not shown (C18). | Documented poll read model with `multiple_choice`, `allow_change_vote`, the caller's own vote and per-option results; a QA poll and approval for one live vote. |
| C26 | Create / edit / delete notes | **Blocked (permission)** | `POST /client/meetings/{id}/notes`, `PUT`/`DELETE /client/meeting-notes/{id}` require `meetings.update` → 403 for clients (Permission Boundary folder). No button or form is offered; the panel says the meeting's team manages notes. | A product decision to grant clients `meetings.update` (or a client-scoped permission) on the server. |
| C27 | Create / approve / reject decisions | **Blocked (permission / no route)** | Create/update/delete under `/client` need `meetings.update` → 403. `…/meeting-decisions/{id}/approve` exists only for super admin, company admin and employee; no client approve or reject route is registered, and no reject route is documented for any role. Not offered. | A client route and permission, if clients should approve decisions. |
| C28 | Create / assign / update action items | **Blocked (permission)** | Create/update/delete under `/client` need `meetings.update` → 403. Assigning also needs a people list with names, which clients do not have (C21). Not offered. | Server permission for clients, and a documented assignee read model. |
| C29 | Create / update / close polls | **Blocked (permission)** | `POST …/polls`, `PUT`/`POST …/close` need `meetings.update` → 403 for clients, although the polls frame (671:3024) shows "Create a poll" for the host. Not offered to clients. | — (host feature). |
| C30 | Live verification of C24/C25 | **Open (no live write)** | Per the C4 brief no live message, upload or vote was sent. The opt-in live smoke stays GET-only. | Owner-approved live run with a client QA account that has joined a QA meeting. |

## Client C5 — company, conversation and meeting-join flows (2026-11-20)

Collection re-read: still **updatedAt 2026-11-14T11:14:33Z**. Scope: `05 Client
/ 02 Companies`, `06 Conversations`, `07 Meetings / 02–03`, the collection's
§4 "Company context — X-Company", and the other roles' by-code / join-request
folders for comparison. **No live request was made** (no client token; no
mutation). Everything below is verified with mocked responses, and on the
emulator against a local mock server only.

**Already implemented before C5** (re-checked against the collection, no
change needed): List My Companies (C4); conversation list, detail, cursor
history, create (direct chats; groups only when `can_create_group`), rename
(groups), delete for me ⚠️, mark read, send with `files[]`, attachment
download (M1–M4, M11, M12); my meeting invitations + accept/decline (BE-17),
join with 200 participant / 202 `{join_request}`, leave (M5, M7).

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| C31 | Client company switching | Handled (mocked) | Collection §4: tenancy comes from `X-Company` only (canonical decimal id); omitted, it falls back to the actor's own company; "a request, not proof" — a company the actor may not use is **403** (SEC-005, "Unauthorized Company (X-Company) → 403" on `GET /client/dashboard`). There is no switch route: switching is sending another `X-Company`. Companies screen (Figma 673:14300 card layout): the session's company shows **Active**; every other listed company shows **Use this company** → confirm → `GET /client/dashboard` with that `X-Company` (read-only; the request's own header is kept by `ApiClient`) → only on 200 does the session move (stored only when "Remember me" stored it). 403 → "Your account can't work in {company} yet", nothing changes; other errors → the shared message. One switch at a time. Every data provider is keyed to (account, company) — the client dashboard and the company list were re-keyed in C5 — so dashboard, projects, meetings, chats, invoices, notifications and the LiveKit room reload/release for the new company. The membership `status` is still not on the list (C4), so a pending company is discovered by the 403. **Stale answers (fixed before push):** a request started in one company and answered after a switch, sign-out or A → B → A is dropped by every long-lived controller (conversation paging/polling, meeting chat, send/vote, meeting join, notifications, meeting media, the switch itself) and by the open chat screen: no state, message, follow-up or retry under the new company; `media/leave` goes to the company the room was joined in. | Live check with a client in ≥ 2 companies (one approved, one pending) (C10); documented membership `status` on `GET /client/companies`. |
| C32 | Request to join a company | **Blocked (contract)** | `POST /client/companies/{id}/join` (no body; 200/401/403/404/409) is documented, but no client route lists companies one could join, so the app has no id to send. The Figma "Available Companies" Join Request buttons stay demo-only. | A client route listing joinable companies (with the caller's request status). |
| C33 | Group members: add / remove ⚠️ / change role | **Blocked (contract)** | Routes exist (`POST …/members {user_id}`, `DELETE …/members/{user}` ⚠️, `PUT …/members/{user}/role {role: admin\|member}`, "admin members only"), but no conversation response documents member ids or roles, so the app cannot tell whether the client is a group admin or which member to act on. Not offered (owner decision 2026-11-20: no dead-end button). A client cannot create groups (`can_create_group` false live). | Documented `users[] {id, name, role}` (or `my_role`) on the conversation detail. |
| C34 | Group image | **Blocked (backend)** | `POST …/conversations/{id}/image` (multipart `image`): groups only; "the creator or a group admin (**401** otherwise, the Chat contract)". The app treats every 401 as an ended session, so a refused non-admin would be signed out; with no documented role (C33) the app cannot avoid that. Not offered. | Backend: answer a non-admin with 403, not 401; documented member role. |
| C35 | Client Join by Code | **Blocked (no route)** | `GET /meetings/by-code/{code}` exists for super admin, company admin and employee only. The public `meeting-guest/preview` + `enter` routes are for guests without an account and are not used for a signed-in client. The client chip keeps explaining it is unavailable (M8). | A client by-code route. |
| C36 | Client join-request status / withdraw | **Blocked (no route)** | `GET`/`DELETE /meetings/{id}/join-request` exist for super admin, company admin and employee only. A client's 202 join keeps the pending state per account and company; "Try joining again" is the only way to learn the outcome (M5). | Client routes to read and withdraw its own join request. |

## Feature completion — Client Finance and remaining features (2026-11-20)

Contract re-read: Postman `WorkFlow`, **updatedAt 2026-11-14T11:14:33Z**
(unchanged since C1–C5). Figma page `534:30389` searched for invoice,
payment, pay/checkout and Claude frames: only "Payment Records"
(643:35269, 643:36002), "Add Payment" (643:35666) and "Create Invoice"
(643:36437) exist — **no invoice-details, Pay, checkout or Claude
Connector frame**. No live request of any kind was sent.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| C37 | Payments recorded against an invoice | Handled (mocked) | `GET /client/payments` documents `invoice_id` ("only this invoice"). Invoice details (`GET /client/invoices/{id}`) now end with **Payments for this invoice**: `?page=&invoice_id=` only, one page at a time with Load more, empty notice, error + Retry that leaves the invoice shown; not requested when the invoice itself is refused (403/404). Rows show only documented list fields (`id`, `payment_date`, `payment_method`, `amount`); the amount carries a currency only when that answer's `totals` names exactly one. A payment summary with an `invoice_id` offers **View invoice** (`GET /client/invoices/{id}`; amounts without a currency there, since no list `totals` names its `currency_id`). Still no `GET /client/payments/{id}` request (C13). Commit `d79c242`. | Live check with QA invoices and payments (C10). |
| C38 | Pay an invoice (Stripe Checkout) | **Blocked (approval + design + backend)** | Contract is complete: `POST /client/invoices/{id}/pay {payment_gateway: "stripe"}` → `data {payment_url, session_id}`; ⚠️ creates a real Checkout Session. Not built: (1) no Figma Pay control or checkout/return frame; (2) opening `payment_url` needs `url_launcher` — a new dependency, not approved; (3) `api.workflownets.com` is treated as production and its Stripe mode is unconfirmed, so no test-mode host exists for the owner-approved single run. | Owner approval of `url_launcher`; a Pay design; a staging host with Stripe test keys. |
| C39 | Confirm a Stripe payment (`GET …/{id}/success?session_id=`) | **Blocked (contract)** | Responses documented (200 `{invoice_id, status: paid\|unpaid}`, idempotent; 400/403/404/409/422). The `session_id` is the one "Stripe appends to the success URL", but the server-configured success URL — and whether it can return to the app (deep link) — is not documented. Without it the app could only re-read the invoice. | Documented success/cancel URLs and a return path to the app. |
| C40 | Payment `payment_method`, `type`, `wallet_id` filters | **Blocked (contract)** | `payment_method` needs the values in `facets.methods`, whose element shape is undocumented (empty live). `type` is `invoice\|employee` (staff payouts, not a client concept); clients have no wallet route to choose a `wallet_id` from. The documented `to` bound is not needed: the date chips are open-ended (`from` only). | Documented `facets.methods[]` shape. |
| C41 | Claude Connector (client and employee) | **Blocked (design + product)** | Documented: `GET …/claude/connections` (`connections[] {id, client_name, company {id, name}, created_at, last_used_at}`, `mcp_url`), `…/activity` (`data.items` + `meta`), `…/requests[/{id}]`, `approve` ⚠️ (**executes** the prepared action — may delete tasks/sprints/projects), `reject`, `DELETE …/connections/{id}` ⚠️, OAuth consent (website half of a browser flow). Routes exist only while `CLAUDE_CONNECTOR_ENABLED=true` (live: 401 without a token, so registered). No Figma frame; approvals are described as decided "on the website". Not built. | A product decision to offer it in the app, and a design. |
| C42 | Realtime notifications | Not built (by choice) | `POST /broadcasting/auth` authorizes the user's private channel; using it needs a Pusher/WebSocket client dependency. Notifications keep polling, which works. | A decision to add a realtime dependency. |

Employee: the report's documented custom range is now built (E27 in
`docs/employee-remaining-features.md`).

## F03 — Employee meeting collaboration (2026-11-20)

Contract: Postman `WorkFlow`, updatedAt 2026-11-14 (unchanged). Employee
folder `08 Meetings`: chat (`GET`/`POST …/meetings/{id}/messages`), polls
(`GET …/polls`, `GET meeting-polls/{id}`, `POST …/vote`), notes, decisions,
action items (lists and single reads) and `GET meeting-attachments/{id}/download`
all need **`meetings.view`** — the same participant routes and rules as the
client's (403 "must be a participant" for a meeting the caller has not
joined). Figma: the employee room copies 729:22436 (polls) and 729:22662 show
the same Chat / Polls / Notes / Participants tabs as the client frames.
**No meeting permission or route distinguishes a project lead from a regular
employee**; meeting roles (creator, host, co-host) decide host actions.
Nothing was sent to a live server.

| # | Item | Status | Evidence / app behaviour | Needed to close |
|---|---|---|---|---|
| F03-1 | Employee chat history, attachments, polls, notes, decisions, action items | Handled (mocked) | The client C3 screens now serve employees too: meeting details → **Meeting records** (both roles) and the live room's tool tabs. The shared repository already builds `/api/v1/{portal}` paths; no repository or provider was duplicated. Panels read "View only in the app." for employees (the client wording says the meeting's team manages them). | A QA meeting the employee has joined (live read). |
| F03-2 | Employee send (text or one `file`) and poll vote | Handled (mocked) | Same C4 send bar and vote flow and rules: one request at a time, file checked before upload, 422 field message with Retry, 403 "only participants", 401 ends the session, after-send `after_id` refresh, poll re-read after a vote. Stale answers after an account or company change are dropped (shared C5 scope guard; tested for employees). | Owner-approved live send and vote (C30 applies to both roles). |
| F03-3 | Create / update / close polls; create / update / delete ⚠️ notes, decisions, action items; approve decision; complete action item; convert to task | **Not offered (host/product)** | Employee routes exist with `meetings.update`; the polls frame's "Create a poll" is the **host** view, and decisions/action items have no write frame (C23). The server's host check for these writes is not documented. | A product decision on which employees (host/co-host) may manage records in the app, and frames for the forms. |
| F03-4 | Host controls: start, end, cancel ⚠️, admission mode, invitations send/cancel ⚠️, mute/unmute (all), participant role, guests admit/reject/revoke, join requests admit/reject/admit-all, whiteboard edit | **Not offered (host/product)** | `meetings.manage_status` / `meetings.update` plus `canManageMeeting()` (creator, host, co-host — 403 otherwise). Employees cannot create meetings (Permission Boundary), so they are hosts only when an admin makes them one. | Product decision (O4: host-side tools) and a QA meeting with an employee host. |

**Emulator (2026-11-20, Medium_Phone_API_36.1, Android 16, debug API build
against a local mock server on 127.0.0.1 — not the backend):** employee
More → Meetings → meeting details show **Meeting records** (Chat, Polls,
Notes, Decisions, Action items) beside Participants and Invitations; chat
history, older-page link and `agenda.txt` preview with Save; a double tap
on Send made **one** `POST …/employee/meetings/41/messages` (201) followed by
an `after_id` refresh; a double tap on Vote made **one** `POST
…/employee/meeting-polls/5/vote` and the poll was re-read ("Vote recorded ·
9 votes in total"); notes read "View only in the app."; Android Back returned
to the details; a meeting with chat off offers no Chat chip; a meeting the
employee has not joined shows the participants-only notice after one
request; Arabic (per-app locale) right-to-left tabs and send bar above the
docked keyboard. The mock logged exactly those two writes. Not covered: the
LiveKit room's tool tabs on a device (no media server; widget-tested).

## Design / API clarifications

| # | Item | Decision |
|---|---|---|
| D1 | The employee Dashboard frame (731:47939) shows Financial Summary & Escrow, Latest Invoices & Receipts and "New Milestone Request". The employee role gets 403 on invoices, payments and wallets and has no milestone-request route (unchanged in WorkFlow). | Not implemented (owner decision, 2026-11-14). A design/API clarification, not a Flutter defect. |

## Security — backend release blockers

A collection change does not prove a backend fix. Rechecked 2026-11-14 with
read-only GETs inside the QA employee's own company only.

| # | Issue | Result |
|---|---|---|
| S1 | **HIGH PRIORITY — task cost exposed to employees in sprint details.** The collection says employee task rows never carry `cost`/`currency` (planning page) and that an employee reaches only sprints of projects they are on. | **Still present on 2026-11-18** (regular member, sprint 2: 4 of 4 tasks with a non-null `cost`). Earlier: **still present as of 2026-11-14** (not rechecked 2026-11-16: no valid employee token). `GET /employee/sprints/{id}` returned `data.tasks[].cost` with non-null values (4 of 4 tasks). **M07: the app no longer needs that route** — sprint task lists come from `GET /employee/tasks?sprint_id=`, and a test asserts `/sprints/{id}` is never requested. Hiding or avoiding it in Flutter is not a fix: anyone with an employee token can still call it. **Release blocker.** |
| S2 | **Employee access to projects they are not on.** | **Confirmed 2026-11-17 and still present 2026-11-18**: the regular member (not on project 1) gets `GET /employee/projects/1` 200 with the client record (`credit_limit`) and users' emails, and `tasks/project-employees/1` 200. The app asks for member lists only on projects the user leads — not a fix. Earlier (2026-11-14): **not verifiable with this account.** The list returns only the one project the QA user belongs to, and no `budget` key (list and detail), as documented. Proving direct access is refused needs an in-company project the user is not on; IDs were not guessed. **Remains a release blocker until retested.** |
| S3 | Role-specific restrictions. | The `role:` prefix gate holds live (employee → 403 on `/client/account`). Permission-boundary routes were not exercised (they are writes). |

Known backend authorization and sensitive-data issues must be fixed on the
server; hiding fields in the app is not a fix.
