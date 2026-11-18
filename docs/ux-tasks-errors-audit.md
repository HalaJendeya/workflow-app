# Employee Tasks filters and user-facing errors — audit (2026-11-18)

Source: `feat/m01-batch2-emulator-fixes` after `5dc8633`. Work is Flutter-only.
No API contract, auth rule or role permission changed, and no live request
was sent.

## 1. Employee Tasks screen (API mode)

### Controls before the change

| Control | Kind | What it did | Verdict |
|---|---|---|---|
| Masthead search | Search | `search` on `GET /employee/tasks`, debounced 400 ms | Kept: the only search |
| Inline search (second field) | Search | Same `_onSearch`, not synced with the masthead | **Redundant**: removed |
| My tasks / Team tasks | Scope | Mine sends `assigned_to=<me>` (rows checked client-side); Team drops it | For a non-lead the server returns only their own tasks, so both showed the same list. **Now shown only to a project leader** (same rule as Add Task) |
| Active tasks / Logged hours | Summary | `stats.active`, `stats.logged_minutes` | Kept: one compact card from Figma |
| All / In Progress / Under Review / Completed | Status filter | `status` param; counts from `stats.by_status` | Kept. **To do** added (most open employee work). Counts are scope totals, so they hide while a search or narrowing filter applies |
| All Projects ⌄ | Project filter | `project_id` (options from `GET /employee/projects/options`) | Moved into the Filters sheet |
| Priority Level ⌄ | Priority filter | `priority` | Moved into the Filters sheet |
| Newest first ⌄ | Sort | `sort` (`-task_date`, `title`; newest = default, not sent) | Moved into the Filters sheet |
| Pager | Pagination | `page` | Kept; every filter change returns to page 1 |

### After

1. Masthead search.
2. My / Team (project leaders only).
3. Summary card.
4. Status chips.
5. **Filters (n)** button, the active filters as removable chips, and
   **Reset filters**.
6. A result count over a filtered list, then the rows and the pager.

The sheet drafts project, priority, sort (and the assignee in the demo's team
view) and applies them together with **Show results**. Three choices send one
request; dismissing the sheet sends none. While a new filter loads, the
previous rows stay under a progress bar.

## 2. Error path, traced

1. Dio sends the request. `ApiClient` adds the Bearer token, and `X-Company`
   only on `/client/*` and `/employee/*`.
2. On failure, `ApiEnvelope.fromDio` / `fromBody` produce an `ApiException`
   with a typed `ApiFailureKind`. A 401 on a non-public route also signs the
   user out (`onUnauthorized`).
3. Repositories throw `ApiException(invalidResponse)` (`missingField`) for
   malformed bodies.
4. Riverpod providers expose `AsyncError`.
5. Screens render the error through `AsyncSection` / `ApiErrorCard` /
   `AsyncView`, snackbars or forms. All of these go through
   `localizedError`.

The layer existed but had these gaps, now fixed:

| # | Found | Kind | Fix |
|---|---|---|---|
| E1 | Timeouts read "Can't reach the server" | Flutter presentation | New `timeout` kind with its own sentence |
| E2 | 400 and 409 fell to "Something went wrong" | Flutter presentation | `badRequest` and `conflict` sentences with a next step |
| E3 | Sign-in and password screens showed the server's raw `message` for 401/403/422, in English even in the Arabic UI | Flutter presentation | `safeServerMessage`: shown only if short, one line, non-technical and in the UI's language. Otherwise "email or password is incorrect" (401) or "this account can't sign in right now" (403) |
| E4 | Form fields (auth, profile) and the task form summary showed raw Laravel validation strings | Flutter presentation | `safeFieldError` / `safeFieldErrors`: the safe message or "Check this field." |
| E5 | 401 wording "has ended"; 403 "You don't have access to this." | Copy | Product wording from the brief, in English and Arabic |
| E6 | Malformed responses read as an unknown error | Flutter presentation | Treated as a server-side fault ("try again later") |

No screen shows `exception.toString()`, a `DioException`, a status code or a
URL. This was checked by search and is enforced by `error_presentation_test`
and `copy_guard_test`.

### Technical copy replaced (English and Arabic)

"…the WorkFlow API has no create route…" (meetings, invoices, payments,
projects), "…ready for the new WorkFlow API… once the backend team publishes
the endpoints", "Not saved: this action has no verified server endpoint yet",
"Export will be available when the backend supports it", "The server reports
project counts only; … needs a documented dashboard response", "…the WorkFlow
API doesn't let employees delete their own account", "Voice messages aren't
supported — the WorkFlow API accepts…", "Calls aren't part of conversations in
the WorkFlow API", "Client accounts can't join by code: the WorkFlow API
has…", "Joining by code isn't connected in the app yet", "…the server did not
confirm it is assigned to you", "The server didn't accept this:", the
payments and companies notes, and "…connect through LiveKit".

### Dead controls removed (API mode; the demo keeps the Figma layout)

- Client More **+**: Schedule meeting, Join by code, Create invoice, Add
  project, Add payment. None has a client route.
- Meetings (both roles): the Schedule **+** and the join-by-code chip.
- Invoices and Payments: the **+** and the Export chip. Projects: the **+**.
- Chat: call and video icons, the voice button and the emoji button. Files
  and images still attach.

## 3. Remaining real backend errors (not Flutter)

| Id | Issue | Status |
|---|---|---|
| S1 | `GET /employee/sprints/{id}` returns task `cost` to employees | Release blocker; re-checked 2026-11-17 |
| S2 | `GET /employee/projects/{id}` returns full project, client and member records to a non-member | Release blocker; re-checked 2026-11-17 |
| O2 | `GET /employee/settings/notifications` answers 404 | Open |
| O5 | Sprint `days_remaining` 0 while `active`; meetings `live` for days | Stale server data |

The app shows these through the normal error and empty states. It neither
hides nor invents data.

## 4. Missing or unsupported features (for future work)

| Feature | Why it is not in the app | Type |
|---|---|---|
| Timesheet entries and details (employee) | Documented and observed, not built | Missing Flutter feature |
| Join meeting by code (employee) | `GET /employee/meetings/by-code/{code}` documented, not wired | Missing Flutter feature |
| Notification tap opens its task or chat | `subject {type, id}` available | Missing Flutter feature |
| Employee Reports | `GET /employee/report` documented | Missing Flutter feature (needs Figma) |
| CSV exports | Export routes documented | Missing Flutter feature (needs a save/share decision) |
| Assignee list limited to project members | `tasks/project-employees/{p}` observed | Missing Flutter feature |
| Client: create meetings, invoices, projects, payments; join by code | No client routes | Not supported by the backend for this role |
| Employee: create meetings or projects | 403 boundaries | Not supported for this role (by design) |
| Voice messages in chat | Uploads accept images, PDF and text only | Not supported by the backend |
| Calls inside a conversation | Calls are meetings | Product design |
| Emoji picker | The keyboard provides emoji | Not needed |

Also see `docs/employee-open-items.md` O4.

## 5. Redmi 8 checklist (read-only)

Build: the latest commit of this branch (see the commands in the report), API mode, with `BUILD_SHA`. Don't create, edit,
move or mark anything.

| Id | Account / mode | Steps | Expected |
|---|---|---|---|
| TF1 | Regular Employee, English | More → Tasks | One search field (top); no My/Team switch; status chips All / To do / In Progress / Under Review / Completed with counts; a **Filters** button; no **+** |
| TF2 | same | Tap **To do** | List shows the to-do task; "1 task"; the previous list stays visible under a thin bar while it loads |
| TF3 | same | Filters → Priority Medium → Show results | "Filters (1)", a "Medium" chip with ×, status counts hidden, result count shown |
| TF4 | same | Tap × on "Medium" | Filter removed; the list is back |
| TF5 | same | Filters → Sort Title A–Z → close the sheet by swiping down | Nothing changes (no request, still "Filters") |
| TF6 | same | Set a status and a filter, then **Reset filters** | All Tasks, no chips, counts back |
| TF7 | same, Arabic + Dark | Repeat TF1–TF3 | Mirrored RTL; sheet readable in dark; no clipped text; chips wrap |
| TF8 | Team Lead (optional) | Tasks | My / Team switch shown; Team shows team tasks; **+ Add Task** present |
| ER1 | Regular Employee | Turn on Airplane mode, pull to refresh Home or Tasks | "You're offline. Check your connection and try again." with Retry; Arabic in the Arabic UI |
| ER2 | same | Airplane mode off → Retry | Data loads; no error left |
| ER3 | any, signed out | Sign in with a wrong password (your own account) | "The email or password is incorrect." (or the server's own short English reason in English mode); never "session expired" |
| ER4 | Regular Employee | Chat → open "Team" (read only; don't send) | No call/video icons, no mic, no emoji; attach and image icons shown |
| ER5 | same | More → Meetings | No **+**, no "join by code" chip |
| ER6 | same | More → Timesheets | Totals with "Your timesheet totals. Individual entries aren't shown in the app yet." |
| ER7 | both languages | Browse Home, Tasks, Chat, Meetings, Timesheets, Profile | No text mentioning API, backend, endpoint, route, server error codes or exceptions |

Record PASS / FAIL / NOTE per id, with on-screen text only.
