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
| Observed | **404 for both QA accounts** with `X-Company: 1`. Both have an `employees` row in company 1 (`GET /employee/account` returns `data.employee`). **2026-11-18:** the 404 message is "The route api/v1/employee/account/whatsapp-notifications could not be found" — the route is **not deployed**, not an employee-row problem. |
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

**2026-11-19 (root-cause audit A):** confirmed live under identical conditions; the server is consistent and the shared label was the bug. The Dashboard now shows "MY TASKS" (`a5c844f`). Exact definitions remain a documentation question (`docs/backend-action-items.md`).

## O4 — Documented Employee features (updated 2026-11-18)

Built on 2026-11-18 (local commits, mock-tested; not yet on a device in
API mode). Details: `docs/employee-remaining-features.md`.

| Feature | Contract | Status |
|---|---|---|
| Employee Reports | `GET /employee/report` | **Built** — More → Overview → My report. **No Figma frame**: needs design review (E26). |
| Timesheet rows and details | `GET /employee/timesheets`, `/timesheets/{id}/details` | **Built** — record cards, filters, paging, details by project. |
| Notification tap → open subject | `subject {type, id}` (observed) | **Built** — task, chat, meeting. A task opened by id offers no status change (E25). |
| Meetings: join by code | `GET /employee/meetings/by-code/{code}` | **Built** — Meetings chip (not in More → Create since 2026-11-19). |
| Meetings: own join request status/cancel | `GET/DELETE /employee/meetings/{id}/join-request` | **Built** — status, Check again, Withdraw (confirmed). Never run live. |
| CSV exports | `projects`, `tasks`, `sprints/backlog`, `timesheets` `/export` | **Built** — Export CSV chip, system save dialog. |
| Assignee list limited to project members | `GET /employee/tasks/project-employees/{p}` | **Built** (E12 closed). |
| WhatsApp settings | see O2 | Not built; route not deployed (O2). |
| Host-side join requests (admit/reject) | `…/join-requests`, `meeting-join-requests/{id}/admit\|reject` | Not built: employees cannot create meetings; needs a product decision. |
| Company switching | none for employees | — |
| Meeting creation / scheduling | `POST /employee/meetings` is a 403 boundary | By design. |

## O8 — Found while building O4 (2026-11-18)

- E22: the collection's `List Timesheets` test asserts keys the server
  does not send (`data.timesheets.data`, `data.summary`).
- E23: report `task_completion_rate` unit undocumented (not used).
- E24: join-request `status` values other than `pending` undocumented.
- E25: task details have no `can` block, so a task opened by id cannot
  offer a status change.
- S1 and S2 re-checked read-only: **both still present**.

## O5 — Minor UI notes (not fixed)

- Group conversation avatar shows a clipped "#Tea".
- The sprint card says "0 Days left" after the sprint's end date. The server
  `days_remaining` is 0 while the sprint is still `active`.
- Four meetings are still `live` 2–15 days after they started. This is stale
  server state, but it inflates "Live Now".

## O6 — Found on the Redmi 8 (run 1, 2026-11-17)

F8 (notification filter leaks into the Home card), F9 (RTL punctuation of server text), U1 (More **+** overlaps the Appearance row), U2 (unusable meeting actions offered to non-leads), U3 (Arabic date comma). Details: `docs/employee-device-acceptance.md` §3. **Fixed locally, not pushed or device-verified:** F8 `54e7055`, F9 `50a6cdd` (+ `85c925a`), U1 `5f4291f`, U2 `575e4f0`, U3 `2aae5e5`, tests `35bac2e`. Re-check F8, F9 and the More screen on the Redmi 8. Mutation readiness: `docs/employee-mutation-readiness.md`.

## O7 — Android 16 emulator acceptance (2026-11-18)

The Team Lead and Regular Employee were tested in API mode (read-only), and
the Client in mock mode only. Four emulator-only defects were fixed:
filter choices lost (`f6d3bc0`), predictive Back closing the app
(`4691964`), tab re-tap (`dd08c75`) and the Arabic Back arrow (`ae1aaf7`).
These fixes are **still pending verification on the Redmi 8**.
Cross-account mutation workflows were not executed, S1/S2 remain
unresolved, and overall E2E is not complete. Details:
`docs/android-emulator-acceptance.md` §11.

## Already fixed in `a662c3a` (for reference)

- F1: task details parse.
- F2: session-scoped summaries.
- F3: dashboard hours.
- F4: dashboard distribution scope.
- F5: Home Tasks card.
- F6: board counts.
- F7: time labels.

The Android acceptance checklist is `docs/employee-device-acceptance.md`.
