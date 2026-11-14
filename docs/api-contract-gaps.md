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
| E1 | `GET /employee/tasks` `facets`. | Open | **Live:** `facets {projects: [], assignees: []}` — keys confirmed, element shape unknown (empty for the QA account). New `GET /employee/employees/options` may serve assignees (not yet read). API mode offers search, priority and status filters only. | A documented facet element (`id`, `label`?) or a QA account with tasks. |
| E2 | Two `GET /employee/tasks` calls per Tasks screen (`stats` then rows). | Deferred (performance) | Both return `stats`. | Whether `stats` ignores the filters; then one request is enough. |
| E3 | `GET /employee/timesheets` row shape. | Open | Prose only (`hours_minutes`, `payment_type`, `rate`, `total`, `currency`, `can{approve,reject}`). **Live:** top-level `stats`, `totals`, `available_months`, `facets {employees}`; the paginator also carries `links`/`meta`; **no rows** for the QA account. Rows are not shown in the app. | A documented row example or a QA account with timesheets. |
| E4 | Employee timesheet approve / reject / delete → 403 (Permission Boundary). Unchanged. | Handled | Cards are view-only. | — |
| E5 | Task status sets were inconsistent (create/update used `waiting_review`, `done`). | **Resolved** | WorkFlow: create/update accept `backlog, todo, pending, in_progress, in_review, completed` plus legacy aliases `waiting_review` → `in_review`, `done` → `completed`. The app's list filter already used the canonical set. | — |
| E6 | Employee dashboard keys the app requires (`myTasks`, `myHours`, `myMinutes`, `totalEarned`, `paidSalary`, `unpaidSalary`). | Handled | **Live:** exactly these six keys. | Documenting them in the collection. |

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

## Design / API clarifications

| # | Item | Decision |
|---|---|---|
| D1 | The employee Dashboard frame (731:47939) shows Financial Summary & Escrow, Latest Invoices & Receipts and "New Milestone Request". The employee role gets 403 on invoices, payments and wallets and has no milestone-request route (unchanged in WorkFlow). | Not implemented (owner decision, 2026-11-14). A design/API clarification, not a Flutter defect. |

## Security — backend release blockers

A collection change does not prove a backend fix. Rechecked 2026-11-14 with
read-only GETs inside the QA employee's own company only.

| # | Issue | Result |
|---|---|---|
| S1 | **HIGH PRIORITY — task cost exposed to employees in sprint details.** The collection says employee task rows never carry `cost`/`currency` (planning page) and that an employee reaches only sprints of projects they are on. | **Still present.** `GET /employee/sprints/{id}` returns `data.tasks[].cost` with non-null values (4 of 4 tasks). The planning page (`GET /employee/sprints`) and the task list carry no cost. The app never reads `cost`; hiding it in Flutter is not a fix. **Release blocker.** |
| S2 | **Employee access to projects they are not on.** | **Not verifiable with this account.** The list returns only the one project the QA user belongs to, and no `budget` key (list and detail), as documented. Proving direct access is refused needs an in-company project the user is not on; IDs were not guessed. **Remains a release blocker until retested.** |
| S3 | Role-specific restrictions. | The `role:` prefix gate holds live (employee → 403 on `/client/account`). Permission-boundary routes were not exercised (they are writes). |

Known backend authorization and sensitive-data issues must be fixed on the
server; hiding fields in the app is not a fix.
