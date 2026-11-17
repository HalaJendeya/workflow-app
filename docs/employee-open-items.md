# Employee portal — open items after the read-only E2E QA

Date 2026-11-17 · Source `048ac6a` · Evidence: read-only GETs against
`api.workflownets.com`, plus the Redmi 8 (Team Lead session). The Employee E2E
is **not complete**; see `docs/employee-e2e-qa-report.md`.

## O1 (Q1) — May an assignee change the status of their own task?

| | |
|---|---|
| Observed | The Regular Employee's only assigned task (project 2, backlog, `todo`) returns `can: {update: false, delete: false}` on both `GET /employee/tasks` and the details route. The Team Lead's rows return `can.update: true`. |
| Role | Both accounts hold `kanban.manage_status` and `tasks.update`. |
| Contract | `POST /employee/kanban/update-status` is documented with permission `kanban.manage_status` and validation only (`task_id`, `status` ∈ backlog, todo, in_progress, in_review, completed). It does not say whether the caller must be the assignee, the project lead, or either. `can.update` is not defined anywhere. |
| App today | Follows `can.update`. A `false` value hides **Change status** in Task Details and blocks dragging on the board, so a regular employee cannot move their own task in the app. |
| Impact | If assignees are meant to update their own status, the backend `can.update` is wrong and the core employee workflow (Scenario B) is blocked. If only leads may, the app is right and the permission name is misleading. |
| Needed | Backend answer: (a) who may call `update-status` on a task, and (b) what `can.update` means (all fields, or status too). Optionally add `can.update_status`. Then run the approved probe M-B1 in `docs/employee-mutation-plan.md`. |
| Status | **Open — backend/product decision.** No app change until it is answered. |

## O2 — WhatsApp notification settings answer 404

| | |
|---|---|
| Route | `GET /api/v1/employee/account/whatsapp-notifications` (documented; `PUT` exists for opting in or out) |
| Documented | 200 with the caller's settings when the caller has an `employees` row in the company. 404 "No employee record for your account in this company" only when there is none. |
| Observed | **404 for both QA accounts** with `X-Company: 1`. Both have an `employees` row in company 1 (`GET /employee/account` returns `data.employee`). |
| Impact | The app does not use this route. The QA team cannot confirm opt-in state before mutation tests. The collection warns that task assignment may send a real WhatsApp message to an opted-in employee when `WHATSAPP_NOTIFICATIONS_ENABLED=true`. Both accounts have no phone number, and opt-in requires one. |
| Needed | Backend: deploy the route, or correct the contract. Owner: confirm the production value of `WHATSAPP_NOTIFICATIONS_ENABLED` before any assignment test. |
| Status | **Open — backend.** |

## O3 — Two different "Active tasks" figures

Dashboard "Active tasks" shows the server's `dashboard.myTasks`. The Tasks
screen "Active tasks" shows `GET /employee/tasks` `stats.active`. For the
Regular Employee these are **1** and **0**: one `todo` task is counted by
`myTasks` but not by `active`. The values are correct server data under the
same label. The definitions are undocumented. Needed: the meaning of each from
the backend, then rename one label (copy change in both ARB files). **Open —
contract/product.**

## O4 — Documented Employee features not built in the app

| Feature | Contract | Live check | Notes |
|---|---|---|---|
| Employee Reports | `GET /employee/report` (`year`, `month` or `from`/`to`, paged tasks) | 200 for both accounts: `{employee, period, summary, projects, tasks, timesheets, meetings}` | No screen. Needs a Figma frame and an owner decision. |
| Timesheet rows and details | `GET /employee/timesheets` rows; `GET /timesheets/{id}`, `/timesheets/{id}/details` | 200; row and details shapes observed (E3) | The screen shows only the summary and an outdated "endpoints not published" banner. |
| Notification tap → open subject | Rows carry `subject {type, id}` | Live: `task`, `conversation` | Tapping only marks the item read (M10). |
| Meetings: join by code | `GET /employee/meetings/by-code/{code}` | not called | The chip says "unavailable" in API mode. |
| Meetings: own join request status/cancel | `GET/DELETE /employee/meetings/{id}/join-request` | 404 when there is none (expected) | Only the 202 "waiting for host" state is handled. |
| WhatsApp settings | see O2 | 404 | Not built; blocked by O2. |
| CSV exports | `projects/export`, `tasks/export`, `sprints/backlog/export`, `timesheets/export` | not called | Needs a save/share decision (E15). |
| Assignee list limited to project members | `GET /employee/tasks/project-employees/{p}` | 200 `[{id, name}]` | The form still lists all company employees (E12). The row shape is now observed, so this can be closed. |
| Company switching | none for employees | — | Employees have one company. |
| Meeting creation / scheduling | `POST /employee/meetings` is a 403 boundary | — | By design. |

## O5 — Minor UI notes (not fixed)

- Group conversation avatar shows a clipped "#Tea".
- The sprint card says "0 Days left" after the sprint's end date. The server
  `days_remaining` is 0 while the sprint is still `active`.
- Four meetings are still `live` 2–15 days after they started. This is stale
  server state, but it inflates "Live Now".

## O6 — Found on the Redmi 8 (run 1, 2026-11-17)

F8 (notification filter leaks into the Home card), F9 (RTL punctuation of server text), U1 (More **+** overlaps the Appearance row), U2 (unusable meeting actions offered to non-leads), U3 (Arabic date comma). Details: `docs/employee-device-acceptance.md` §3. **Fixed locally, not pushed or device-verified:** F8 `54e7055`, F9 `50a6cdd` (+ `85c925a`), U1 `5f4291f`, U2 `575e4f0`, U3 `2aae5e5`, tests `35bac2e`. Re-check F8, F9 and the More screen on the Redmi 8. Mutation readiness: `docs/employee-mutation-readiness.md`.

## Already fixed in `a662c3a` (for reference)

- F1: task details parse.
- F2: session-scoped summaries.
- F3: dashboard hours.
- F4: dashboard distribution scope.
- F5: Home Tasks card.
- F6: board counts.
- F7: time labels.

The Android acceptance checklist is `docs/employee-device-acceptance.md`.
