# Onboarding and Help: proposal (not implemented)

Status: proposal only, written 2026-11-18 after the Redmi 8 UX acceptance
follow-up. No code, ARB strings or routes exist for it yet. Build it only
after the feature set it describes is complete. Each step names a screen
that must already be finished and accepted, so the guide never points at
something missing or still on `DesignPendingScreen`.

## Goals

1. On first launch, show a new user where things are in under a minute.
2. Make navigation predictable: which tab holds what, what More contains,
   and what Back does.
3. Explain complex screens (Tasks filters, Sprint board, Meeting Details,
   join requests) in place, only when the user asks.
4. Let any user replay the guide from **More → Help & Guide**.
5. Add no new floating button. The `+` (Create) FAB stays the only one,
   and nothing in the guide may cover or imitate it.

## 1. First-launch walkthrough

A short set of 3 to 5 full-width cards shown once, after the first
successful sign-in and before the Home tab. It is not shown on the auth
screens.

- Each card has one sentence, one illustration taken from the Figma file
  (no screenshots of live data), and the buttons **Next**, **Skip** and,
  on the last card, **Start**.
- The illustrations come from the design system, and each card follows
  the light/dark palette and RTL.
- Completion is stored per account and company in the existing
  preferences storage, as `guideSeen:<portal>:<userId>`. A new company or
  role sees its own guide once.
- Back on the first card skips the guide. Back on later cards goes to the
  previous card. It never exits the app.
- Accessibility: every card is one semantics node with a live region, and
  text grows to 130% without clipping at 320×640.

## 2. Navigation guidance (inside the walkthrough)

A card that shows the five-tab bar with labels and states three rules in
plain language:

- "Home, Projects/Companies and Chat are always one tap away."
- "More holds everything else: Tasks, Meetings, Dashboard, Settings."
- "Back takes you to where you were, then Home."

This matches the tab-history Back added in this round (see
`navigation_flow_test.dart`).

## 3. Contextual help inside complex screens

A small `?` icon button in the masthead, next to the notifications bell.
It is not floating and not in the content area. It opens a bottom sheet
with 2 to 4 short tips for that screen and a **Show me** link that replays
the matching walkthrough steps. Planned screens:

| Screen | Tips |
|---|---|
| Tasks | Search is at the top. **Filters** holds status, project, priority and sort, applied together. Chips show what's active, and **x** removes one. |
| Sprint board | Drag between columns. Only allowed moves are offered. A lead can switch to the whole team. |
| Meeting Details | Join, Leave and join requests. What "waiting for the host" means. |
| Projects | Tap a project for details, its sprints and tasks. Leads can add tasks there. |
| Invoices / Payments (client) | Status meanings. Where receipts are. |

The tips are ARB strings in English and Arabic, and they never mention
backend terms.

## 4. Help & Guide entry in More

A new row in More's last section, above the preferences card:

- **Replay the guide** runs the role's walkthrough again.
- **Tips for this app** lists every contextual-help sheet.
- **Contact support** appears only if the backend documents a support
  channel. None exists in the collection today, so record it in
  `docs/api-contract-gaps.md` before adding it.

## 5. Steps per role

| Step | Client | Regular employee | Project lead |
|---|---|---|---|
| 1 Welcome + company switcher | ✓ | ✓ | ✓ |
| 2 Tab bar and More | Home · Companies · Invoices · Chat · More | Home · Sprints · Projects · Chat · More | same as employee |
| 3 Main work | Companies → projects; invoices and payments | My Tasks: search, Filters, Task Details | My/Team tasks switch, **Add Task**, Team view on the board |
| 4 Communication | Chat, Meetings: join and join requests | Chat, Meetings | Chat, Meetings, invitations |
| 5 Create (`+`) | What `+` offers the client | Not shown when `+` has no actions for this user | What `+` offers a lead |

The role comes from the session (portal) and, for the lead, from
`ledProjectIdsProvider`, the same rule that shows Team Tasks and Add Task.
A user who becomes a lead later sees a single "You now lead a project"
card once.

## 6. Not conflicting with the `+` button

- No walkthrough highlight, coach mark or help control is placed in the
  FAB's area (bottom end, above the navigation surface).
- Step 5 points at the real `+` with a cut-out highlight, and only when
  the user has create actions.
- Contextual help lives in the masthead, so the content area and the FAB
  stay as they are.

## Prerequisites before building

1. M08 scope settled. The guide describes only screens accepted on
   device.
2. Figma frames for the walkthrough cards and the help sheet (none exist
   yet). Per the project rules, screens stay pending until their frame is
   inspected.
3. Copy reviewed in English and Arabic.
4. Tests: first launch shows once per account/company, Skip and Back
   work, the guide can be replayed from More, and every card works at
   4 viewports × text 1.0/1.3 × light/dark × LTR/RTL.
