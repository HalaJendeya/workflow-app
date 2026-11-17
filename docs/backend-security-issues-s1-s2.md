# Backend security issues S1 and S2 — employee role

For: WorkFlow backend owners · From: mobile app QA · Date: 2026-11-17
Environment: `https://api.workflownets.com/api/v1` (production)
Contract: Postman `WorkFlow` (updatedAt 2026-11-14T11:14:33Z)

All evidence comes from **read-only GET requests** made with two QA accounts in
company 1. Both hold the backend role `employee` with the same 18 permissions.

| Account | Membership |
|---|---|
| Team Lead | leader of projects 1 and 2 |
| Regular Employee | member of project 2 only; **not** a member of project 1 |

This report contains no values of sensitive fields, no credentials and no
personal data: only routes, status codes, key names and value types. Hiding
fields in the mobile app does **not** fix either issue, because any holder of
an employee token can call these routes directly.

---

## S1 — Task cost exposed to employees in sprint details (HIGH)

### Affected endpoint

`GET /api/v1/employee/sprints/{sprint}`
- Permission: `sprints.view`.
- Controller (per the collection): `Api\Admin\SprintController@show`.

### Expected behaviour

The collection states that employee task rows never carry `cost` or
`currency`. The employee task list does follow this: `GET /employee/tasks`
rows have no `cost`, and `series.cost` is `null`.

An employee is not authorized to read task cost. Sprint details for the
employee role must not include `cost`, or any other monetary task or rate
field.

### Observed behaviour

| Caller | Request | Status | Result |
|---|---|---|---|
| Regular Employee (member of the sprint's project) | `GET /employee/sprints/2` with `X-Company: 1` | **200** | `data.tasks[]`: 4 rows, **4 of 4 with a non-null `cost`**. None of the rows is assigned to the caller. |
| Regular Employee | same request, no `X-Company` | **200** | same |
| Team Lead | `GET /employee/sprints/1`, `/sprints/2` | **200** | `cost` non-null on every row (3/3, 4/4) |
| Regular Employee | `GET /employee/sprints/1` (not a member) | 403 | correctly refused |
| Regular Employee | `GET /employee/tasks?sprint_id=2` | 200 | rows carry **no** `cost` key (correct) |

Shape of `data.tasks[]` returned to the employee (types only):

| Key | Type |
|---|---|
| `id`, `project_id`, `sprint_id`, `assigned_to` | number |
| `title`, `description`, `priority`, `status` | string |
| `story_points`, `completed_by`, `duration` | number |
| `completed_at`, `task_date`, `start_time`, `end_time` | string |
| **`cost`** | **string (decimal)** |
| `created_at`, `updated_at` | string |
| `assigned_user` | object (a user record) |

The `assigned_user` object is the full user record of a colleague (see
"Related exposure" under S2).

This was first observed on 2026-11-14 and was **still present on
2026-11-17**.

### Recommended server-side fix

1. Serialize employee-role sprint details through the same employee task
   resource used by `GET /employee/tasks`, which already omits `cost` and
   `currency`. Do not return raw `Task` models.
2. Hide `cost`, and any rate or amount field, for any caller without a
   finance permission. Enforce this in the resource layer, not per
   controller, so new routes inherit it.
3. Replace `assigned_user` with `{id, name, image}`.
4. Add a feature test. As an employee, `GET /employee/sprints/{id}` must
   return no `cost` key in any `tasks[]` row (assert key absence, not
   null).

---

## S2 — Employees can read projects they are not a member of (HIGH)

### Affected endpoints

| Endpoint | Permission | Controller (collection) |
|---|---|---|
| `GET /api/v1/employee/projects/{project}` | `projects.view` | `Admin\ProjectController@show` |
| `GET /api/v1/employee/tasks/project-employees/{project}` | `tasks.view` | `Admin\TaskController@projectEmployees` |
| `GET /api/v1/employee/sprints/employees-by-project/{project}` | `sprints.view` | `Admin\SprintController@sprintProjectEmployees` |

### Expected behaviour

The employee role should reach only projects where the caller is the leader
or a member. Requests for any other project in the same company should get
**403**, or 404 to avoid confirming existence. The project list already
behaves this way: it returns only the caller's projects.

### Observed behaviour

Caller: the Regular Employee, who is **not** on project 1. All requests sent
`X-Company: 1`.

| Request | Status | Expected |
|---|---|---|
| `GET /employee/projects/1` | **200**, full project details | 403/404 |
| same, without `X-Company` | **200** | 403/404 |
| `GET /employee/tasks/project-employees/1` | **200**, the project's members (2 rows `{id, name}`) | 403/404 |
| `GET /employee/sprints/employees-by-project/1` | **200**, `{employees: [{id, name}]}` (2 rows) | 403/404 |
| `GET /employee/projects?…` (list) | 200, project 1 **not** listed | correct |
| `GET /employee/tasks/8` (a task in project 1) | 403 "Unauthorized access to this task" | correct |
| `GET /employee/sprints/1` | 403 | correct |
| `GET /employee/sprints/options?project_id=1` | 403 | correct |
| `GET /employee/sprints/by-project/1` | 403 | correct |
| `GET /employee/kanban?project_id=1`, `GET /employee/sprints?project_id=1` | 422 "The selected project is invalid." | correct (refused) |
| `GET /employee/tasks?project_id=1` | 200, 0 rows | correct (filtered) |
| `GET /employee/projects/9999` (nonexistent) | 404 | — |

The project-scoped task, sprint and board routes enforce membership.
`projects/{id}` and the two member-list helpers do not.

### Data exposed by `GET /employee/projects/1` to the non-member (key names and types only)

| Object | Keys (type) |
|---|---|
| project | `id, company_id, client_id, leader_id, currency_id` (number), `title, status` (string), `description` (null), `completion_percentage` (number), `created_at, updated_at` (string) |
| `client` | `id, user_id, is_primary` (number), `name` (string), **`credit_limit`** (nullable), `joined_at` (nullable), timestamps |
| `currency` | `id, company_id` (number), `code, name, symbol, status` (string), **`rate`** (string), `is_default` (bool), timestamps |
| `leader` | `id, company_id, is_active` (number), `name` (string), **`email`** (string), **`email_verified_at`** (string), **`must_set_password`** (bool), `image`, timestamps |
| `users[]` (every member) | same keys as `leader`, including **`email`**, `email_verified_at`, `is_active`, `must_set_password`, plus `pivot {project_id, user_id}` |
| `company` | `id` (number), `name, email, domain` (string), `logo`, timestamps |

No `budget` key was returned. That matches the documented employee rule.

**Related exposure, S4 (MEDIUM, data minimization):** members get the same
user records, with email, verification and activation flags, for their
**own** projects. Sprint details (S1) embed the same records as
`assigned_user`. An employee needs at most `{id, name, image}` for a
colleague.

### Recommended server-side fix

1. In `ProjectController@show`, for the employee role, authorize with a
   policy: the caller is the project's `leader_id` or is in its members
   pivot. Otherwise return 403 (or 404). Use the **same** policy in
   `TaskController@projectEmployees` and
   `SprintController@sprintProjectEmployees`.
2. Treat `X-Company` as a tenant selector only, never as authorization.
   The leak occurs both with and without the header.
3. Return employee-facing project details through a dedicated resource:
   - **Leader and members:** `{id, name, image}`.
   - **Client:** `{id, name}`.
   - **Currency:** `{id, code, symbol}`.
   - **Company:** `{id, name}`.
   Leave out `credit_limit`, `rate`, emails, verification and activation
   flags.
4. Add feature tests. As an employee who is not a member of project P:
   - `GET /employee/projects/P` → 403/404.
   - `GET /employee/tasks/project-employees/P` → 403/404.
   - `GET /employee/sprints/employees-by-project/P` → 403/404.
   - As a member: 200, with none of the keys removed in step 3.

---

## Not tested (and why)

- Write routes, such as task update by a non-lead and task delete: they need
  explicit approval on production.
- Cross-company access (`X-Company` naming another company): no second company
  or approved foreign ids were available, and ids were not guessed.
- The `can.delete: true` flag on task rows for a project lead, while
  `DELETE /employee/tasks/{id}` is a documented 403 (S5, low). This is
  misleading metadata, not verified by a delete.

Please reply with the deployed fix version. The mobile QA will re-run these
exact read-only requests and report the status codes.
