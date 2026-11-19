# Backend action items (2026-11-19)

Only issues that need a backend change or a backend answer. Each was
reproduced with **read-only GETs** against `https://api.workflownets.com`
using two QA employee accounts in company 1:

- **Lead:** leads projects 1 and 2.
- **Member:** a member of project 2 only.

Every request sent `Authorization: Bearer`, `X-Company: 1` (each
account's own company) and `Accept: application/json`. Flutter-side
causes were ruled out first; the evidence is in
`docs/api-integration-root-cause-audit.md`.

## Security vulnerabilities

### S1 — Sprint Details expose task costs to employees · **HIGH**

| | |
|---|---|
| Endpoint | `GET /api/v1/employee/sprints/{sprint}` |
| Incorrect | Returns each task with a non-null `cost` to the `employee` role (4 of 4 tasks in sprint 2, for both accounts). |
| Expected | No `cost` (or currency) for employees, as `GET /employee/tasks` already does and the collection documents for the employee role. |
| Reproduce | As the member: `GET /api/v1/employee/sprints/2` → 200; check `tasks[].cost`. Compare `GET /api/v1/employee/tasks?project_id=2&month=all` (no `cost`). |
| Change | Hide pay fields from the employee role in Sprint Details (and anywhere else tasks are serialized for employees). |

### S2 — Non-members read other projects' details and members · **HIGH**

| | |
|---|---|
| Endpoints | `GET /api/v1/employee/projects/{project}`, `GET /api/v1/employee/tasks/project-employees/{project}` |
| Incorrect | The member (not on project 1, which is absent from their `GET /employee/projects` list) gets **200** for project 1, including the client object with `credit_limit` and users' email addresses, and 200 with the member list for project 1. |
| Expected | 403 or 404 for projects the employee is not on, the rule Sprint Details already states ("an employee only reaches sprints of projects they are on"). |
| Reproduce | As the member: `GET /api/v1/employee/projects/1` and `GET /api/v1/employee/tasks/project-employees/1` → both 200. |
| Change | Enforce project membership (or leadership, for the member list) on both routes. |

## Defects (not security)

### Stale `live` meetings · **MEDIUM**

| | |
|---|---|
| Endpoint | `GET /api/v1/employee/meetings` (and `/{id}`) |
| Incorrect | Meetings 1, 3, 4 and 5 report `status: live` and `ended_at: null` 12–17 days after `started_at`. Meeting 5 also holds an undecided join request. |
| Expected | Meetings that have ended show `ended`, either automatically when the LiveKit room empties or by a documented clean-up. |
| Reproduce | `GET /api/v1/employee/meetings?per_page=50` as either account; compare `status`, `started_at` and `ended_at`. |
| Change | Close or clean up the stale rows. State whether an empty room should end its meeting (see D2), and check the LiveKit webhook if it should. |

### WhatsApp settings route not deployed · **MEDIUM** (blocks assignment QA)

| | |
|---|---|
| Endpoint | `GET /api/v1/employee/account/whatsapp-notifications` (documented with `PUT`) |
| Incorrect | 404 "The route api/v1/employee/account/whatsapp-notifications could not be found" for both accounts. The `company/…` variant gives the same 404, while an existing company route gives 403 to the same token, so the route is missing in every role. |
| Expected | 200 with the caller's settings, or the documented 404 "No employee record…". |
| Reproduce | `GET /api/v1/employee/account/whatsapp-notifications` → 404 route not found. |
| Change | Deploy the route, or remove it from the collection. Also confirm `WHATSAPP_NOTIFICATIONS_ENABLED` before any task-assignment test. |

### `can.delete: true` for a role without `tasks.delete` · **LOW**

| | |
|---|---|
| Endpoint | `GET /api/v1/employee/tasks` (rows' `can`) |
| Incorrect | Every row the lead sees has `can.delete: true`. The collection says the employee role is not granted `tasks.delete`, so `DELETE /employee/tasks/{id}` is a 403 (not executed here: destructive). |
| Expected | `can.delete` reflects what the route allows. |
| Reproduce | As the lead: `GET /api/v1/employee/tasks?month=all` → `can.delete: true`. |
| Change | Compute `can.delete` from the same permission and leader rule the route enforces. The app does not offer Delete, so no user is misled today. |

## Clarifications needed (documentation or product)

| # | Endpoint | Question | Why it matters |
|---|---|---|---|
| Q1 | `POST /employee/kanban/update-status` | May an assignee change their own task's status when their row says `can.update: false`? Is `update-status` governed by `can.update` or only by `kanban.manage_status`? | The app follows `can.update`, so a regular employee cannot move their own task. If the server allows it, the app will be changed to match. **MEDIUM** (core employee workflow). |
| B3 | `GET /employee/timesheets`, `/details`, `/dashboard`, `/report` | For `payment_type: monthly`, what is `rate`? In every place, `total` is exactly 100 × `rate` (both QA accounts). Is `rate` stored in another unit, or is the monthly total mis-scaled? | Pay amounts shown to employees. **MEDIUM** until answered. |
| A | `GET /employee/dashboard`, `GET /employee/tasks` | Define `myTasks` (completed included?) and `stats.active` (does it include `in_review`/`pending`?). Live: `active` leaves `todo` out; `myTasks` includes it. | The app now labels them differently. Exact definitions keep the copy honest. |
| C (E23) | `GET /employee/report` | Unit of `summary.task_completion_rate` (0–1 or 0–100). | Not displayed until documented. |
| D2 | Meetings | Is ending manual only (`POST …/end`), or automatic on an empty room? | Explains the stale `live` rows. |
| E2 | `GET /employee/kanban` | `stats.days_remaining` after the end date: clamped to 0 (observed)? | The app now shows "Past end date" itself. |
| F2 (E24) | `GET /employee/meetings/{id}/join-request` | List every `status` value; document `user`, `decided_by`, `decided_at`, `created_at`, `updated_at` (returned, undocumented). | Statuses other than `pending` are shown generically. |
| G2 (E25) | `GET /employee/tasks/{id}` | Add the `can` block that list rows have. | A task opened from a notification or report cannot offer actions. |
| B2 (E22) | `GET /employee/timesheets` (collection test) | The test asserts `data.timesheets.data` and `data.summary`, which no longer exist. | The collection's runtime test fails against a correct server. |
| B4 | `GET /employee/timesheets/{id}/details` | `timesheet.hours` and `summary.*.hours` hold **minutes** (example 270 → 4.5 h × 30 = 135; live equal to `hours_minutes`). Rename or document. | Misleading for every client. |

Not included: anything the app has fixed or can handle (A's labels,
the Total salaries mapping, the sprint badge, the join-request label).
None of the security items above is mitigated by the app hiding data.
