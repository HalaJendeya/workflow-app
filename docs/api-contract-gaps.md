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
| C4 | Client company endpoints | Partly handled (M04) | Only `GET /client/companies` ("List My Companies", test asserts `data`) and `POST /client/companies/{id}/join` (no body; 200/401/403/404/409). **Live:** `data` is a plain list (empty for the QA client). The app lists the account's companies read-only, using the company fields the live server returns elsewhere (`id`, `name`, `domain`, `email`). **Open:** (1) the row shape and the membership `status` (`pending`/`approved`/`rejected` are documented only on the admin routes) — not shown until documented; (2) no route lists companies a client could join, so the app has no id for `join` and offers no Join button in API mode; (3) no leave, cancel or active-company switch. |
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
