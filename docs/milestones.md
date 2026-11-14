# Milestone status

| Milestone | Status | Live verification | Notes |
|---|---|---|---|
| M00–M02 | Accepted | Owner's Redmi 8 | Sprint/Kanban, Drag & Drop, dialogs, forms. |
| M01 (reduced gate) | Accepted | Owner's Redmi 8 (batches 1–2) | Deferred visual/accessibility items in the M01 report. |
| M03 Authentication & session | Accepted (owner tested on Redmi 8) | Read-only role/account checks on `api.workflownets.com` (L0–L4 employee, L7–L9 client) | `docs/m03-live-auth-test-plan.md`. |
| **M04 Client Dashboard, Companies, Projects** | **Implementation-complete; live QA pending** (accepted 2026-11-14, commits `412df09`, `72981fe`) | Read-only with the client QA token, which has **no company and no project**: dashboard counts, empty companies list, projects `stats`/filters, 404 shapes. **Populated company and project workflows are verified with mocked responses only — not against the live backend.** | QA fixtures needed: `docs/api-contract-gaps.md` C10. Open contract items: C4 (membership status, company directory, switch), A9 (client company context). |
| M05a Client Invoices & Payments (read-only) | Implementation-complete; live QA pending | Read-only on `api.workflownets.com` with the client QA token: every request the app sends (invoice `status`/`sort`/`from`, project options `per_page=100`, payment `status`/`search`/`from`) answers 200 with the documented `stats`/`totals`; 404/422 shapes confirmed. **The QA client has no invoices or payments, so rows, details and amounts are verified with mocked responses only.** | `docs/m05-client-finance-plan.md` §6. |
| M05b Pay (Stripe Checkout) | Not started — needs approvals | — | `docs/m05-client-finance-plan.md` §5 and §4. |

Release blockers (backend): sprint task-cost exposure to employees (S1, high
priority); employee access to projects they are not on (S2, unverified).
