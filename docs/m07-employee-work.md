# M07 — Employee Projects, Tasks, Sprints & Kanban

| | |
|---|---|
| Baseline | `d4636ea` on `feat/m01-batch2-emulator-fixes` (accepted on the owner's Redmi 8) |
| Contract | Postman `WorkFlow`, uid `56083386-d0da80f4-f067-42e4-9b96-9e021769e55e`, **updatedAt 2026-11-14T11:14:33Z** — re-read 2026-11-16, unchanged since the last audit |
| Backend | `https://api.workflownets.com` (treated as production) |
| Live verification | **None this milestone.** Both configured employee QA tokens answered **401 Unauthenticated** on 2026-11-16 (revoked or expired). No request beyond that single read-only check was sent. Everything below marked "mock" is verified only with test doubles shaped from the collection. |

## 1. Endpoint-to-feature coverage

Employee permissions (collection): `projects.view`, `sprints.view`,
`tasks.view|create|update`, `kanban.manage_status`. Every request sends
`Authorization: Bearer` and `X-Company` (from the session).

Status: **complete** = implemented and reachable · **partial** · **missing**
(documented, not built) · **blocked** = refused to employees or undocumented.

### Projects (`02 Projects`, `projects.view`)

| Method & path | Request / response used | Flutter | Reached from | Tests | Status |
|---|---|---|---|---|---|
| `GET /employee/projects` | `search`, `status`, `page`, `per_page=10` → paginator + required `stats {total,pending,in_progress,completed}`; row `id,title,status,completion_percentage,currency`; no `budget` for employees | `ProjectsRepository.list`, `apiProjectsProvider` (now keyed to user **and company**) | Projects tab: search, status filter, pager; Dashboard | `m01_employee_smoke`, `employee_api`, `m07` | complete |
| `GET /employee/projects/{id}` | `data.id` (test); same row fields | `ProjectsRepository.show`, `apiProjectProvider` | Project card → View Details | `m04`, `m07` | complete |
| `GET /employee/projects/options` | `[{id,title,company_id,leader_id,client,currency}]`; `led=1` = projects the caller leads | **new** `WorkOptionsRepository.projects`, `projectOptionsProvider`, `ledProjectsProvider` | Tasks project filter; lead detection for Add/Edit task and board scope | `m07` | complete |
| `GET /employee/projects?sort=…`, `client_id`, `leader_id` | documented | — | — | — | missing (low value on mobile; `led=1` covers "my led projects") |
| `GET /employee/projects/export` | CSV attachment | — | — | — | missing (no CSV share flow yet) |
| `GET /employee/projects/clients · company-data · currencies · employees` | create-form helpers; **response shapes undocumented** | — | — | — | blocked (form helpers for a create the employee may not use) |
| `POST/PUT/DELETE /employee/projects…`, `GET /project-data/{id}` | Permission Boundary (403) | — | **Add Project is no longer shown to employees** | `m07` | blocked (by design) |

Project members and roles: the live row carries `leader {id,name}` and
`members[]`, neither documented; the app shows the leader's name and the
member **count** only. No member-role field exists in the collection.

### Tasks (`05 Tasks`)

| Method & path | Request / response used | Flutter | Reached from | Tests | Status |
|---|---|---|---|---|---|
| `GET /employee/tasks` | `month=all`, `page`, `per_page`, `search`, `status`, `priority`, `assigned_to` (My Tasks), **new:** `project_id`, `sprint_id`, `sort` (`-task_date`, `title`) | `BoardRepository.tasks`, `apiTasksProvider(TaskQuery)` | My/Team Tasks; project filter; sort; project details preview; sprint task lists | `my_tasks`, `sprint_board_api`, `m07` | complete |
| `GET /employee/tasks` `stats` | `{total, by_status, active, logged_minutes}` | `EmployeeWorkRepository.taskStats` | Tasks figures and chip counts | `my_tasks`, `m01` | complete (E2: separate `per_page=1` request remains) |
| `GET /employee/tasks/{task}` | object (no example) | `BoardRepository.task` | Task Details (fresh on open; stale row + Retry on failure) | `my_tasks`, `m07` | complete (E8) |
| `POST /employee/tasks` | `project_id`\*, `title`\*, `task_date`\*, `sprint_id`, `assigned_to` (`users.id`), `description`, `story_points`, `priority`, `status`, `start_time`/`end_time` (`H:i`) → **201 `data.id`** | **new** `BoardRepository.createTask`, `ApiTaskFormScreen` | Tasks **Add Task** (leads only), More → Create → Add Task (leads only), Project details **Add task** (lead of that project) | `m07` (body, 201, missing `data.id`, 403, 409, 422) | complete (mock) |
| `PUT /employee/tasks/{task}` | same fields, all optional → `data.id`; **only changed fields are sent** | **new** `BoardRepository.updateTask` | Task Details → ⋮ → Edit (lead of the task's project, row not `can.update:false`, details freshly loaded) | `m07` | complete (mock) |
| `GET /employee/sprints/options?project_id=` | `[{id,name,status}]` | **new** `sprintOptionsProvider` | Task form sprint picker; project details sprint list | `m07` | complete |
| `GET /employee/employees/options` | `[{user_id,name,image}]` | **new** `peopleOptionsProvider` | Task form assignee picker | `m07` | complete (see E12) |
| `GET /employee/tasks-data/{company}` · `/tasks/project-employees/{project}` | shapes undocumented (`data.projects`, `data.employees` presence only; list) | — | — | — | blocked (E12) |
| `GET /employee/tasks/export` | CSV | — | — | — | missing (no CSV share flow) |
| `DELETE /employee/tasks/{task}` | Permission Boundary (403) | — | never shown | `my_tasks`, `m07` | blocked (by design, E10) |

### Sprints & Kanban (`03 Sprints`, `04 Kanban`)

| Method & path | Request / response used | Flutter | Reached from | Tests | Status |
|---|---|---|---|---|---|
| `GET /employee/kanban` | `project_id`, **new** `scope=all` (lead only) → `{projects, selected_project, sprint, tasks, stats…}` | `BoardRepository.kanban`, `kanbanProvider(BoardKey)` (now keyed to session) | Sprints tab → Kanban; Project details → **Open board** | `sprint_board_api`, `kanban_drag`, `m07` | complete (E11) |
| `POST /employee/kanban/update-status` | `{task_id, status}` (backlog, todo, in_progress, in_review, completed) → `data {id, status}` | `BoardRepository.updateStatus` | drag & drop, move sheet, Task Details → Change status (`can.update: true`) | `sprint_board_api`, `kanban_drag`, `my_tasks` | complete; after a move **every** list, figure, board and backlog is re-read |
| `GET /employee/sprints` | `project_id` → `{projects, selected_project, sprints[{…,stats}], backlog{…}, backlog_stats}` | `BoardRepository.planning`, `planningProvider` (now keyed to session) | Sprints tab → Backlog; sprint rows **now open their tasks** | `sprint_board_api`, `m07` | complete (backlog first page only — no page parameter documented; E11) |
| `GET /employee/sprints/{sprint}` | `data.id`, `data.tasks` | — (deliberately **not** called) | sprint tasks come from `GET /tasks?sprint_id=` | `m07` asserts it is never requested | blocked by S1 (cost exposure) |
| `GET /employee/sprints/by-project/{p}` · `employees-by-project/{p}` · `data-by-company/{c}` | shapes undocumented | — | — | — | blocked (undocumented) |
| `GET /employee/sprints/backlog/export` | CSV | — | — | — | missing |
| `POST /sprints`, `PUT/DELETE /sprints/{id}`, `POST /sprints/{id}/start · complete`, `POST /sprints/move-task` | **Permission Boundary (403)** | — | **Create Sprint button removed** (it only showed "unavailable") | `sprint_board_api` | blocked (by design) |

## 2. Implemented or repaired in M07

1. **Task create for project leads** (`POST /employee/tasks`): a form with
   only documented fields: project (the projects the user leads), sprint,
   assignee (`users.id`), title, description, story points, priority,
   status, planned work date, optional start/end time. The documented time
   rules (end after start, ≤ 4 h, end needs start) are checked before
   sending. 403, 409 (approved timesheet month) and 422 field messages are
   shown in the form; nothing is shown as saved unless the server answers
   with `data.id`.
2. **Task edit for project leads** (`PUT /employee/tasks/{id}`): offered
   only after the task's details are freshly loaded, on a project the user
   leads, and not when the row says `can.update: false`; sends only the
   fields that changed, so values the row did not carry are never wiped.
3. **Lead-only controls are hidden, not "unavailable"**: Add Task (Tasks,
   More → Create, project details) appears only for leads; Add Project and
   Create Sprint are gone for employees (both are 403 routes).
4. **Tasks filters**: project filter (`project_id`, from
   `projects/options`) and sort (`sort=-task_date | title`) are sent to the
   server; empty states use one rule for every filter.
5. **Project details for employees**: "You lead this project" badge, the
   project's sprints (each opens its tasks), the latest 3 tasks with "View
   all tasks", **Open board** (Sprint & Backlog on that project) and **Add
   task** for the lead.
6. **Sprint & Backlog**: a lead can switch the board between *My tasks*
   and *Team tasks* (`scope=all`); sprint rows show status and points and
   open their task list.
7. **Consistency after writes**: one `invalidateTaskData` after a create,
   edit, status change or board move re-reads task lists, task figures,
   dashboard figures, every board and every backlog. Before M07 a board
   move left My Tasks and the dashboard showing the old status until they
   were reopened.
8. **Isolation**: the board, backlog and project list are now keyed to the
   account **and** company (the board and backlog were keyed to neither;
   the project list only to the user).

## 3. Backend-blocked or missing

| Item | Why |
|---|---|
| Sprint create/start/complete/edit/delete, move task between sprints | Permission Boundary (403) for employees |
| Task delete, project create/update/delete | Permission Boundary (403) |
| Sprint details screen with tasks from `GET /sprints/{id}` | S1: the route returns `tasks[].cost` to employees; the app uses `GET /tasks?sprint_id=` instead |
| Due date, subtasks, attachments, comments, actual time on tasks (E9) | Not in the API |
| Precise assignee list for a lead (project members only) | `tasks/project-employees/{p}` has no documented row shape (E12) |
| Project members with roles | `members[]` undocumented, no role field (E13) |
| Backlog beyond the first page | No documented page parameter for the planning backlog |
| CSV exports (projects, tasks, backlog) | Documented, not built: needs a save/share decision for CSV on mobile |

## 4. Verification

| Kind | Result |
|---|---|
| Live API (read-only) | **Not possible**: both employee QA tokens → 401 (2026-11-16). No writes were attempted, and none would be without explicit approval. |
| Mock / contract tests | `test/features/m07_employee_work_test.dart` (28 tests) plus updated `sprint_board_api_test.dart`; see §7. |
| Physical Android | Not done by Claude; see the Redmi 8 checklist (§8). |

## 5. Security and permissions

- **S1 (HIGH, backend)** — still open, unverified this session (no valid
  token). The app does not request `GET /employee/sprints/{id}` at all, so
  no cost value reaches the device through the app; the route itself still
  needs a server fix.
- **S2 (backend)** — employee access to projects they are not on: still
  unverifiable (no token, no second project).
- Lead-only UI is derived from the documented `projects/options?led=1`;
  as a second check, a row whose `leader_id` is someone else is ignored.
  This only decides what is **offered**; the server's 403 remains the
  authority and is shown as such.
- Kanban `scope=all` is requested only on a project the user leads.
- Session/company isolation: every new provider rebuilds on account or
  company change; a test switches accounts and checks the new requests
  carry the new token and `X-Company`, and lead-only controls disappear.
- WhatsApp side effect: with `WHATSAPP_NOTIFICATIONS_ENABLED=true` a task
  **assignment** may send a real WhatsApp message (collection note). The
  form defaults to *Unassigned* when creating.
- No token, id or amount is logged by the new code.

## 6. Performance

- Opening Tasks: **4 requests, no duplicates** (rows, figures, project
  options, led projects), asserted by a test. The led-projects list is
  shared with More and not re-read when Tasks opens.
- Project details load only 3 task rows (`per_page=3`), not the whole list.
- Option lists are cached while their screen is open (`autoDispose`), and
  dropped on account/company change.
- E2 (a separate `per_page=1` request for `stats`) is unchanged: whether
  `stats` follows every filter is undocumented, so merging it could show
  wrong counts.

## 7. Tests and builds

| Step | Result (2026-11-16, Windows, local) |
|---|---|
| `dart format --set-exit-if-changed lib test` | clean |
| `flutter analyze` | No issues found |
| `test/features/m07_employee_work_test.dart` | 28 passed (repository contract, lead/non-lead flows, 403/409/422, filters, project details, board scope, isolation, request count, Arabic dark and 320×640 ×1.3 layouts) |
| Full suite | **871 passed** (baseline 843 at `d4636ea`; 2 old tests rewritten because Add Project / Add Task / Create Sprint are no longer shown to employees who cannot use them) |
| `flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock` | built |

## 8. Redmi 8 acceptance checklist (API mode, employee)

Needs a QA employee who **leads** one project (with ≥ 2 members, ≥ 1 sprint
and tasks in several statuses) and is a member of another project they do
not lead. Writes on `api.workflownets.com` need the owner's go-ahead.

1. Tasks opens on **My tasks**; cards show title, short description and
   status only; tap opens details; back returns.
2. Tasks → project filter → pick each project; list and counts follow.
   Sort by **Planned date** and **Title A–Z**.
3. As a **non-lead** account: no Add Task button on Tasks, none under
   More → Create, no ⋮ Edit in details, no Team switch on the board.
4. As the **lead**: Add Task → the led project is preselected → title →
   Save → "Task created." → the task appears in Team tasks (and in My
   Tasks if assigned to yourself), the board/backlog and project details.
5. Try an end time 5 h after the start → the form refuses before sending.
6. Edit a task on the led project → change only the title → Save → details
   and lists show the new title; other fields unchanged on the web admin.
7. Open a task on a project you don't lead → no Edit.
8. Projects → View Details → sprints listed → tap one → its tasks; back →
   **Open board** → the board on that project; **Add task** visible only
   on the led project.
9. Board as lead → **Team tasks** → other members' cards appear; switch
   back to **My tasks**.
10. Move a card (drag and the sheet) → snackbar → My Tasks, the dashboard
    count and the backlog reflect the new status without reopening.
11. Switch Arabic + Dark → repeat 1, 4 and 8: layout mirrors, nothing
    clipped, form scrolls with the keyboard up.
12. Sign out → sign in as the other employee → no data or lead controls
    from the first account remain.
