# Employee E2E — mutation readiness (2026-11-17)

Review of `docs/employee-mutation-plan.md` against the live server. **No write
was sent.** Evidence comes from read-only `GET` requests to
`https://api.workflownets.com/api/v1/employee/*` (production) with the stored
QA tokens and `X-Company: 1`. This report records ids, counts, status codes
and key names only.

App build for the run: `35bac2e` (F8, F9, U1–U3 fixed, local only, not pushed).
The plan still names `048ac6a`; use the newer build once its push is approved.

## 1. Preconditions

| ID | Status | Evidence (read-only) |
|---|---|---|
| P1 Regular Employee on project 1 "QA Test Project" | **NOT MET** | Regular Employee `GET /projects` → ids `[2]`. `GET /projects/1` → `users` ids `[4, 6]`; the Regular Employee (user 10) is not among them. The Team Lead's list is `[2, 1]`. |
| P2 WhatsApp notifications | **NOT CONFIRMED** | `GET /settings/notifications` → **404** (O2, unchanged). `GET /account` has no `phone` key for either account. The production value of `WHATSAPP_NOTIFICATIONS_ENABLED` cannot be read by an employee: the owner must confirm it. |
| P3 Dedicated QA meeting `{M}` | **NOT MET** | Both accounts see the same 6 meetings, ids 1–6 (statuses ended, live, live, live, ended, live), and none has "QA" in its title. Invitations: Regular Employee 1 (meeting 1, accepted); Team Lead 2 (meeting 4 pending, meeting 1 accepted). Meetings 1–6 are out of scope by rule. |
| P4 Device | **NOT MET now** | `adb devices` lists no device. The Redmi 8 must be reconnected, set to Do Not Disturb, and the build above installed. |

Baseline for later comparison: Regular Employee has 1 unread notification, 1
conversation (id 1, the shared "Team"), and 1 task (#13, `todo`). The Team
Lead has 0 unread, the same conversation, and 8 visible tasks.

## 2. Cross-account scenarios

| Scenario | IDs | Ready? | Needs |
|---|---|---|---|
| A — create and assign | M-A1 | **Ready** | Nothing more. The Team Lead creates an unassigned task in project 1. |
| | M-A2, M-A3 | Blocked | P1 (assigning a non-member answers 422) and P2 (assignment may send WhatsApp) |
| B — status workflow | M-B1, M-B2 | Blocked | M-A2. The task must be assigned to the Regular Employee first. |
| C — edit and permissions | M-C1 | **Ready after M-A1** (lead-side edit) | Seeing the edit on the Regular Employee's side needs M-A2. |
| | M-C2 (negative probe) | Blocked | M-A2. Without assignment the 403 doesn't test the lead-only edit rule. |
| D — timesheets | — | No writes in scope | — |
| E — chat (new conversation) | M-E1, M-E2, M-E3, M-E4 | **Ready** | Nothing more. Both accounts are in company 1, and the new conversation `{C}` is separate from "Team". |
| F — notifications | M-F2 | **Ready after M-E2** | — |
| | M-F1 | Blocked | M-A2 |
| G — meetings | M-G1 to M-G4 | Blocked | P3 (an admin creates and starts `{M}`) |
| H — session isolation | M-H1 | **Ready** | Device (P4) |

So the scenarios that can run as soon as the device is connected are **M-A1,
M-C1, M-E1 to M-E4, M-F2 and M-H1**. All of them run on the device by the
owner, except the verification GETs.

## 3. Blockers

1. **P1**: a company admin adds the Regular Employee to project 1. This
   unblocks A2/A3, B, C2 and F1.
2. **P2**: the owner confirms the production WhatsApp setting. This is
   needed before M-A2 only.
3. **P3**: an admin creates the `QA-E2E meeting`, invites both QA accounts
   without host approval, and starts it at run time. This unblocks G.
4. **P4**: reconnect the Redmi 8 and install `35bac2e` (or the pushed build).
5. **Backend release blockers (still open; re-checked today, read-only)**:
   - **S1**: Regular Employee `GET /sprints/2` → 200, and 4 of 4 task rows
     carry a non-null `cost`.
   - **S2**: Regular Employee (not a member) `GET /projects/1` → 200 with the
     full record: `client`, `currency`, `leader` and `users`.

   Both are server-side. They don't block the client mutation tests, but they
   do block release. See `docs/backend-security-issues-s1-s2.md`.

## 4. Operations that need the owner's explicit approval

Approve by ID. Approval of one ID never covers another.

| ID | Irreversible part |
|---|---|
| M-A1 | A task row stays until an admin deletes it (employees get 403 on DELETE) |
| M-A2 | A `task_assigned` notification, plus a possible WhatsApp message (P2) |
| M-B1, M-B2 | None (B2 reverts B1). M-B1 may run as a Claude API probe. |
| M-C1 | None |
| M-C2 | None expected (403). A 200 would be a security finding, and C1's title is then restored. |
| M-E1 | A conversation record ("delete for me" only hides it) |
| M-E2, M-E3, M-E4 | Messages and one private text file |
| M-F1, M-F2 | Read flags on QA notifications only. Mark all as read stays excluded. |
| M-G1 to M-G3 | Participant history in `{M}` |
| M-H1 | Revokes the device token (intended) |

Outside these IDs, the following also need approval:
- Pushing the local code commits `54e7055`…`35bac2e`, plus this report's docs
  commit.
- Admin precondition actions P1 and P3. These are done by the owner or an
  admin; Claude has no admin access.

The Employee E2E stays **not complete** until the approved scenarios have run
and been verified.
