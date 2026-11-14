# WorkFlow API contract gaps

The Flutter app integrates only what the Postman collection **WorFlowNets**
(Hala's Workspace) documents. This file records what the collection leaves
open, how the app handles it today, and what is needed to close it.

| | |
|---|---|
| Contract source | Postman collection `WorFlowNets`, uid `56083386-3bd0b0e2-751a-4dd1-83c7-40b21362dc2e` |
| Collection version read | last updated 2026-11-05 · 991 requests · re-read 2026-11-14 (unchanged) |
| Backend | `https://work.isradev.shop` |
| Live verification | **Not possible on 2026-11-14**: every request (including `/`) answered `502 upstream request failed`. Nothing below was confirmed against live responses. |

Status: **Open** = needs backend or product input · **Handled** = the app
works around it without inventing anything · **Deferred** = planned for a
later milestone.

## M03 — Authentication & session

| # | Gap | Status | App behaviour today | Needed to close |
|---|---|---|---|---|
| A1 | `POST /api/v1/login` documents only `data.token`, `data.token_type`, `data.user.id`, `data.user.company_id`. No role. | Handled | The user picks Client or Employee; before a session opens, the app reads `GET /api/v1/{portal}/account` with the new token. The `role:` gate answers 403 for another role → the token is revoked (`POST /logout`) and the user is told to choose the other account type. Nothing is stored. | A documented role field (e.g. `data.user.role`) would remove the extra request and let the app route by itself. |
| A2 | Login answers 403 for a deactivated account, an unverified email, or an account that never set its password; the three are distinguishable only by `message` text. | Open | The server message is shown as given. | A machine-readable reason (e.g. `errors.reason: unverified \| inactive \| setup_required`) so an unverified user can be sent to the OTP screen. |
| A3 | OTP length is not documented. `verify-email-otp` takes `otp: string`, `verify-otp-forgot-password` takes `otp: numeric`. | Open | 4 boxes, as in Figma "Verification Code" (137:26665). | The code length and alphabet. |
| A4 | `POST /api/v1/account/setup` (invited users: emailed `token`, password `min:8`) has no app flow. Employees are created by a Company Admin, so this is how they get their first password. | Open | Not offered. Login shows the server's 403 message. | A Figma frame for the flow, and a decision on how the token reaches the app (deep link vs. paste). |
| A5 | Link-based flows `GET /verify-email-token` and `POST /reset-password-form` (token from an email link). | Deferred | The app uses the OTP flows (`verify-email-otp`, `forgot-password` → `verify-otp-forgot-password` → `reset-password`). | Only if deep links are adopted (see A4). |
| A6 | No refresh endpoint; token lifetime is not documented. | Handled | Any 401 on an authenticated route ends the session, clears secure storage and says "Your session has ended. Please sign in again." | Token lifetime, if the app should warn before expiry. |
| A7 | `POST /api/v1/account/setup/resend` is authenticated (super/company admin only). | Handled | Sent with the bearer token (it was wrongly treated as public). The app has no admin screens and never calls it. | — |
| A8 | `POST /api/v1/register`: Figma has no password-confirmation field; `image` (optional file) has no Figma control. | Handled | The single password is sent as `password_confirmation`; `image` is not sent. | — |
| A9 | Client company context: client tenancy runs through the approved `client_company` pivot; the login `company_id` may be null. | Deferred (client API milestone) | `X-Company` is sent only when `data.user.company_id` is known; otherwise the server falls back to the account's own company (SEC-006). There is no in-app company switch. | How a client with several approved companies chooses the active one. |

## Employee API (later milestones)

| # | Gap | Status | App behaviour today | Needed to close |
|---|---|---|---|---|
| E1 | `GET /employee/tasks` returns `facets`, whose shape is undocumented. | Open | API mode offers search, priority and status filters; project and assignee filters are demo-only. | The `facets` shape (ids and labels for projects and assignees). |
| E2 | Task counts and task rows come from two calls to `GET /employee/tasks` (`per_page=1` for `stats`, then the page). | Deferred (performance) | Two requests per screen open. | Whether `stats` in a filtered response ignores the filters; if so one request can serve both. |
| E3 | `GET /employee/timesheets` rows: only prose names `hours_minutes`, `payment_type`, `rate`, `total`, `currency`, `can{approve,reject}`; no task, date or user field. | Open | Summary figures (`stats`, `totals`) are shown; rows are not, with the "backend pending" notice. | A documented row example. |
| E4 | Employee timesheet approve / reject / delete are listed as 403 (Permission Boundary). | Handled | Timesheet cards are view-only. | — |

## Design / API clarifications

| # | Item | Decision |
|---|---|---|
| D1 | The employee Dashboard frame (731:47939) shows Financial Summary & Escrow, Latest Invoices & Receipts and "New Milestone Request". The employee role gets 403 on invoices, payments and wallets and has no milestone-request route. | Not implemented (owner decision, 2026-11-14). A design/API clarification, not a Flutter defect. |

## Release blockers (not fixable in Flutter)

Known backend authorization and sensitive-data exposure issues remain
production-release blockers. They must be fixed on the server; hiding fields
in the app is not a fix.
