# M05 — Client Invoices & Payments: contract review and plan

Read-only review, 2026-11-14. Contract: Postman `WorkFlow`
(`56083386-d0da80f4-…`, updated 2026-11-14), folders `05 Client / 04
Invoices` and `05 Payments`. Live checks: read-only GETs on
`api.workflownets.com` with the client QA token (no company, so every list
is empty). **No payment, checkout or other write was sent.**

## 1. Endpoints and supported actions

| Route | Permission | Contract | Live (client QA) |
|---|---|---|---|
| `GET /client/invoices` | `invoices.view` | Query: `search`, `page`, `per_page` (1–100, default 15), `sort` (`invoice_date`, `created_at`, `due_date`, `amount`, `status`; `-` = desc; default `-invoice_date`), `status` (`paid`/`unpaid`/`partially_paid`/`overdue`/`all`; bad value 422), `project_id`, `from`/`to` (on `invoice_date`), `client_id`. Rows carry derived `paid_amount`, `remaining_amount`, `payment_status`, `is_overdue`; `status` is the derived `unpaid`/`partially_paid`/`paid`. Beside `data`: `stats {total, paid, unpaid, partially_paid, overdue}` (also inside `data`; ignores `status`), `totals [{currency_id, code, symbol, amount, paid, remaining, overdue_amount}]`, `series.invoiced`. | 200; `stats` (inside and beside `data`), `totals: []`, `series.invoiced` (6 points); `status=bogus` → **422** `errors.status`. No rows. |
| `GET /client/invoices/{id}` | `invoices.view` | Test asserts `data.id`. 401/403/404. | Unknown id → **404** "Invoice not found". |
| `GET /client/invoices/export` | `invoices.view` | CSV (list filters + sort, `ids[]`); > 10 000 rows → 422. | Not called. |
| `POST /client/invoices/{id}/pay` | `invoices.pay` | Body `{payment_gateway: "stripe"}` → `data {payment_url, session_id}`. ⚠️ Creates a **real Stripe Checkout Session**. 401/403/404/409/422/502/503. Payer must own the invoice in the active company. | **Not called.** The live client role holds `invoices.pay` (12 permissions; the collection's client folder still says 9). |
| `GET /client/invoices/{id}/success?session_id=cs_…` | `invoices.view` | 200 `{invoice_id, status}` (idempotent); 400 not paid; 403 other client's invoice; 404; 409 settled/mismatched; 422 bad `session_id` (checked before Stripe is contacted). | Not called. |
| `GET /client/payments` | `payments.view` | Query: `search`, `page`, `type` (`invoice`/`employee`), `status` (`confirmed`/`pending`), `payment_method`, `wallet_id`, `invoice_id`, `from`/`to` (on `payment_date`). Beside `data`: `totals [{currency_id, code, symbol, received, pending, paid_out}]`, `stats {total, received, pending, paid_out}`, `series`, `facets.methods`. Rows carry `direction` (`incoming`/`outgoing`); **no other row field is documented.** | 200; `stats`, `totals: []`, `series {received, pending, count, revenue}`, `facets {methods: []}`; `status=bogus` → **422**. No rows. |
| `GET /client/payments/{id}` | `payments.view` | Test asserts `data.id`. 401/403/404. | Unknown id → **404** "Payment not found". |
| `GET /client/payments/export` | `payments.view` | CSV. | Not called. |

No refund endpoint, no recurring billing, no client-side create/update/delete
for invoices or payments.

## 2. Current Flutter implementation vs. contract

| Area | Today | Gap / defect |
|---|---|---|
| Invoice list | Integrated: `status` chips with `stats` counts, search, `from`/`to`, paging (`per_page` 15), per-currency formatting from `totals`. | `sort` and `project_id` not offered. Provider not keyed to the signed-in user (M04 pattern). |
| Invoice row parsing | `InvoiceRecord.fromJson`. | **Defect:** missing `paid_amount` becomes **0**, missing `remaining_amount` becomes the **full amount**, missing `is_overdue` becomes **false** — silent fallbacks for documented fields. Should be invalid responses. Project shown as `#id` (rows carry ids only). |
| Invoice details | Sheet built from the list row. | `GET /client/invoices/{id}` never called. |
| Pay invoice | Not offered. | Needs Stripe Checkout flow (see §5). |
| Payment confirmation | Not offered. | Needs a way to get `session_id` back to the app, or to re-read the invoice. |
| Payments list | Summary only (`stats.total`, `totals` received/pending) with the backend-pending notice; no rows. | Rows not integrated: only `direction` is documented. Filters (`status`, `type`, `payment_method` from `facets.methods`, dates) not offered. |
| Payment summary parsing | `PaymentSummary`. | **Defect:** missing `received`/`pending` per currency become **0**, missing `code` becomes `''`. |
| Payment details | None. | `GET /client/payments/{id}` (`data.id` only documented). |
| Exports | None. | CSV download/share needs a file-saving dependency; low priority. |
| Dashboard invoices | First page of invoices (M04). | Inherits the invoice parsing defect. |
| Company context | `X-Company` only when the session has a company. | Same open question as M04 A9. |

## 3. QA data needed (isolated, test-mode only)

1. A **QA company** whose Stripe configuration uses **test keys** — on a
   staging host, not `api.workflownets.com`, unless the backend team confirms
   in writing that this host uses Stripe test mode.
2. The QA client **approved** in that company (and, for isolation, a second
   QA company with its own client and invoices).
3. Invoices for the QA client in every state, in **two currencies**:
   unpaid, partially paid, paid, overdue (due date in the past), and one
   invoice linked to a project. More than 15 invoices for paging.
4. Payments against those invoices: confirmed and pending, at least two
   `payment_method` values, so `facets.methods` and the filters have data.
5. Optional: one invoice reserved for a single, explicitly approved
   test-mode checkout, plus a Stripe test card.

## 4. Backend blockers and security considerations

- **Payment safety:** `POST /pay` creates a real Stripe Checkout Session.
  The collection's guard skips it only on `workflow.aliservice.site`; it
  does **not** protect `api.workflownets.com`. Treat that host as production:
  no checkout from automated tests or Claude, ever, without explicit owner
  approval of a single test-mode run.
- **Unknown Stripe mode** of `api.workflownets.com` — backend to confirm.
- **Return path:** the success callback needs the `session_id` Stripe adds to
  the success URL; the server-configured success URL is not documented, and
  the app has no deep link or URL launcher (`url_launcher` would be a new
  dependency and changes `pubspec.lock` — needs approval).
- **Undocumented payment rows** (only `direction`) and **undocumented
  invoice/payment detail fields** (only `data.id`) block a faithful
  payments list and detail screens.
- **Permission drift:** live client = 12 permissions (`invoices.pay`,
  `notifications.view/update` added); the collection's client folder still
  says 9.
- Tenant isolation for finance must be retested with two QA companies
  (`X-Company` of a company the client is not approved in → 403, SEC-005)
  once fixtures exist; no other organisation's ids are to be guessed.
- Existing release blockers stand (S1 sprint task cost, S2 project access).

## 5. Recommended scoped M05 plan

**M05a — read-only correctness (no new dependencies, no payments):**
1. Make invoice and payment-summary parsing strict for documented fields
   (no silent 0 / full-amount / `false` / `''` fallbacks); key finance
   providers to the signed-in user.
2. Invoice details from `GET /client/invoices/{id}` (row first, then the
   server record; 403/404/Retry), as done for projects in M04.
3. Invoice list: add `sort` (due date / amount / date) and keep filters,
   search and paging resetting correctly.
4. Payments: keep the summary; add `status`, `type` and date filters to the
   summary query only if the backend documents the row shape — otherwise
   keep rows backend-pending and record it.
5. Contract + widget tests for all of the above; live read-only checks once
   QA invoices exist.

**M05b — Pay (only after approvals):**
1. Backend confirms Stripe test mode and the success-URL / return
   behaviour; owner approves adding `url_launcher` (and deep links if used).
2. "Pay" on unpaid/partially paid invoices → `POST /pay` → open
   `payment_url` in the browser → on return, re-read
   `GET /client/invoices/{id}` (the signed webhook settles independently);
   use `/success` only if the `session_id` reaches the app.
3. Handle 409 (already settled), 422, 502/503 (checkout service) with clear
   messages; never show success without the server's `status: paid`.
4. One owner-approved test-mode checkout on a staging host; never on
   `api.workflownets.com` without written confirmation of test mode.

**Deferred:** CSV export (needs file-saving/share dependency), payment
details and rows (undocumented fields).

## 6. M05a outcome (2026-11-14)

Implemented (read-only, no new dependencies, no payment calls):

- **Strict parsing.** Invoice `paid_amount`, `remaining_amount`,
  `is_overdue` (boolean), `stats` (all five counts) and `totals` (each row
  with `code`) are required; payment `stats.total`, `totals[].received` /
  `pending` / `code`, and row `amount` / `payment_date` are required. A
  missing value is an invalid response with Retry — no 0, full balance,
  `false` or empty currency is invented.
- **Invoices:** server-side status chips, search, date range, **sort**
  (newest, oldest, due date, highest amount), **project filter**, paging; **details from `GET /client/invoices/{id}`** (row first
  with a loading bar, then the server record; 403/404/5xx/network show the
  error with Retry and no stale amounts).
- **Payments:** rows from the documented example of the same controller
  (`id`, `invoice_id`, `amount`, `payment_method`, `payment_date`) plus
  `direction`; server-side status (`confirmed`/`pending`), search, date
  range, paging; metrics and rows from one request; amounts carry the
  currency only when `totals` names exactly one. Details are the row
  itself.
- **Isolation:** every finance provider is keyed to the signed-in user and
  company; tests cover a company switch for the same user and a switch to
  another account.

Still limited by the API (not invented):

| Item | Missing |
|---|---|
| Payment row status | No status field in the documented row (the `status` filter works server-side). |
| Payment row currency | No currency on rows; with several currencies in `totals` amounts show without a symbol. |
| Payment details | `GET /client/payments/{id}` documents only `data.id` (no example in any role; no QA payment to check live). Not called; the row is shown in a view titled **"Payment summary"** with a note that full details are not documented. |
| Invoice details shape | Documented only by `data.id`; parsed with the list row fields (the collection says "every invoice carries" them). Not yet seen live (no QA invoices). |
| Payment `type` and `payment_method` filters | `type` is for staff payments; `facets.methods` element shape is undocumented (empty live). |
| CSV export | Deferred (needs a file-saving dependency). |

## 7. M05a cleanup (2026-11-14)

- **Project filter — resolved.** A searchable picker uses the documented
  server-side `search` and `page` of `GET /client/projects`, 20 projects per
  page with "Load more", so every project is reachable (tested with 105)
  and nothing is downloaded up front. Selecting a project returns the
  invoice list to page 1; a slower answer for a superseded project never
  replaces the current one. Project names on invoice cards come from
  `GET /client/projects/{id}` for the projects on the current page (one
  request per distinct project; `#id` until known or if unreadable). The
  picker and the lookups are keyed to the account and company.
- **Payment details — backend-dependent.** Still no documented response for
  `GET /client/payments/{id}`; the view is labelled "Payment summary" and
  shows only verified list fields. No details request is made.

