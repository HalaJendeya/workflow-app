# M03 live authentication verification plan

Contract: Postman collection `WorkFlow` (uid
`56083386-d0da80f4-f067-42e4-9b96-9e021769e55e`, 2026-11-14), folder
`01 Auth` and the `Get Profile` requests of `04 Employee` / `05 Client`.
Server: `https://api.workflownets.com`, all routes under a single `/api/v1`.

## Ground rules

1. **`api.workflownets.com` is production** until the backend team says
   otherwise. The collection's safety gate only recognises
   `workflow.aliservice.site`, so it does **not** protect this host. Never run
   the Collection Runner against it, and never trust a "SAFE_CREATE" label.
2. Every request below is classified. **READ-ONLY** steps may run once QA
   tokens are in place. **SESSION** steps (log in, log out) and anything else
   that writes need the owner's explicit approval *for that step*, in the
   chat, beforehand. Registration, OTP, resend, forgot/reset password and
   account setup are **out of scope** (they send real email or change
   credentials).
3. Credentials only through the session's secure credential form (the proxy
   injects them; nobody types them into chat, files, `.env` or command
   lines). Reports show status codes, key names and value *types* only —
   never tokens, emails, names, ids of people, or amounts.
4. Only the dedicated QA accounts and their own company. No guessed ids, no
   other organisations.
5. A step that fails unexpectedly stops the run; it is reported, not retried
   in a loop.

## Why login itself is a device step

`POST /api/v1/login` takes `email` and `password` in the JSON body. The
secure credential mechanism injects **headers** (a bearer token), not body
fields, so Claude cannot log in without seeing the password. Therefore:

- **Claude** verifies everything that works with a bearer token: role
  endpoints, wrong-role access, token revocation and expiry (L-steps below).
- **The owner** runs the real login/logout end to end in the app on a phone
  (D-steps), where the password is typed into the app only.

## QA accounts needed

| Account | Must be | Used for |
|---|---|---|
| QA Employee | role `employee`, active, email verified, password set; in a **QA-only** company; on ≥ 1 project with a sprint, tasks and timesheets | L1–L6, D1–D4; Employee API gaps E1/E3 |
| QA Client | role `client`, active, verified, password set; **approved** (`client_company`) in the same QA company, ideally in two companies | L7–L9, D5–D6; client gaps A9, C2, C3 |
| QA Employee B (optional) | second employee in the same QA company, on a project the QA Employee is **not** on | Security S2 (project isolation) |
| Negative accounts (optional) | one unverified, one deactivated, one invited-but-no-password | Login 403 reasons (gap A2), D7 |

Each token is saved with the credential form for host `api.workflownets.com`
(header `Authorization`, prefix `Bearer`). The proxy keeps one bearer secret
per host, so the client token replaces the employee token when the client
steps start.

## L-steps — Claude, bearer token injected by the proxy

| Id | Request | Class | Expected | Pass criteria |
|---|---|---|---|---|
| L0 | `GET /up`; `GET /api/v1/employee/account` **without** a token | READ-ONLY | 200; 401 `{success:false, message:"Unauthenticated."}` | Host up; envelope as documented |
| L1 | `GET /api/v1/employee/account` (employee token, no `X-Company`) | READ-ONLY | 200 `{data:{id, email, company_id, …}}` | `data.id`, `data.email` present (collection test) |
| L2 | `GET /api/v1/client/account` (employee token) | READ-ONLY | 403 envelope | Wrong role refused → app's `PortalMismatch` path is correct |
| L3 | `GET /api/v1/employee/account` with `X-Company: <own company_id>` | READ-ONLY | 200 | Tenant header accepted for the own company |
| L4 | `GET /api/v1/employee/dashboard`, `/tasks?per_page=1&month=all`, `/timesheets?per_page=1` | READ-ONLY | 200 | Keys the app reads are present (shapes only) |
| L5 | `POST /api/v1/logout` with the employee token | **SESSION — approval** | 200 envelope | Token revoked server-side |
| L6 | Repeat L1 with the **same** (now revoked) token | READ-ONLY | 401 | Revoked token = expired session → app clears storage and shows "Your session has ended" |
| L7 | `GET /api/v1/client/account` (client token) | READ-ONLY | 200 | As L1, client side |
| L8 | `GET /api/v1/employee/account` (client token) | READ-ONLY | 403 | Wrong role refused |
| L9 | `GET /api/v1/client/dashboard` | READ-ONLY | 200 `{projectsCount, projectsCompleted, projectsInProgress}` | Re-checks gap C3 on the new server |
| L10 | `POST /api/v1/logout` with the client token, then repeat L7 | **SESSION — approval** | 200, then 401 | As L5/L6 |

L5 and L10 revoke the saved tokens: after them the owner saves fresh tokens
if more L-steps are needed.

## D-steps — owner, app on a phone (API mode)

Build: `flutter run --dart-define=APP_MODE=api --dart-define=API_BASE_URL=https://api.workflownets.com`
(or `--dart-define-from-file=.env` from `.env.example`). No DEMO banner must
show.

| Id | Action | Expected |
|---|---|---|
| D1 | Account Type → **Employee** → log in with the QA Employee | Employee home (Sprints tab present); no error |
| D2 | Kill and reopen the app ("Remember me" on) | Still signed in; no login screen |
| D3 | Log in with "Remember me" **off**, kill and reopen | Login screen (token was not stored) |
| D4 | More → account menu → Log out | Account Type screen; reopening the app stays signed out |
| D5 | Account Type → **Client** → log in with the QA Employee | Message "This account isn't a client account. Go back and choose Employee."; stays on login |
| D6 | Account Type → **Client** → log in with the QA Client; repeat D2/D4 | Client home (Companies, Invoices tabs) |
| D7 | (optional) negative accounts | Server's 403 message shown; no session |
| D8 | Airplane mode → try to log in | Network error message; no crash; no session |
| D9 | While signed in, revoke the token elsewhere (e.g. log out of the same account on a second device) → open any screen that loads data | "Your session has ended. Please sign in again." and the Account Type screen |
| D10 | Wrong password | 401 handled as an error message; no session |

Report per step: pass / fail, a screenshot with personal data cropped, and
for failures the on-screen message only.

## Already covered by mocked tests (not live)

Login/register/OTP/reset request shapes; role probe, revoke on 403 and on
other failures; bearer and `X-Company` rules; 401 → session cleared and
reported once; 403 / 422 / 429 (`retry_after`) / 5xx / network mapping;
"Remember me" storage; router redirects per role. Files:
`test/features/auth/*`, `test/core/network/api_client_test.dart`,
`test/app/app_test.dart`.

## Run order once approved

1. Owner saves the QA Employee token (credential form, host
   `api.workflownets.com`).
2. Claude runs **L0–L4** (read-only) and reports.
3. Owner approves **L5** explicitly → Claude runs L5 + L6.
4. Owner saves the QA Client token → Claude runs **L7–L9**; L10 only with
   approval.
5. Owner runs **D1–D10** on a phone and sends results.
6. Claude records the outcome in `docs/api-contract-gaps.md` and closes or
   re-opens A1, A6, A9, C2, C3.
