---
name: workflow-m01
description: Coordinator for WorkFlow milestone M01 (Full Mobile Responsiveness & Navigation), Batches 3, 4 and 5. Runs one batch at a time - scope, Figma verification, fixes, responsive and regression tests, emulator QA where available - ends each batch with its own local commit and an English report, and stops for owner acceptance before the next batch. Never pushes or merges. Use when the owner asks to start or continue an M01 batch.
argument-hint: "<batch number 3|4|5> [scope from the owner]"
disable-model-invocation: true
---

# WorkFlow M01 — batch coordinator

Request: **$ARGUMENTS**

## Ground rules (from the owner; override everything else)

- **One batch per invocation.** Batches run in order: 3, then 4, then 5. Before starting batch N, confirm batch N-1 is committed and the owner accepted it. Check `git log` for its commit, and if acceptance isn't in the conversation, ask. Never start the next batch on your own.
- **Scope comes from the owner.** The repo doesn't define Batches 3–5. Use the scope given in `$ARGUMENTS` or the prompt. If none is given, propose one from the frame map in `/figma-ui-verify` and the screens Batches 1–2 didn't cover, then wait for confirmation. Don't invent a scope and start.
- **Local commits only.** No `git push`, merge, rebase of shared history, force operations, or branch deletion without explicit approval of that exact action.
- **No mutating or ⚠️ destructive API requests** against a real server. Integrate only endpoints the Postman collection *WorFlowNets* documents, and model only documented fields. Never fake success in api mode or fall back to mock data.
- **Preserve accepted work:** Sprint/Kanban, Drag & Drop, M02, and M01 Batches 1–2. Their tests must stay green.
- **Preserve uncommitted files**, especially `pubspec.lock`. Run `git status` first. Don't stage, revert, or overwrite files you didn't change. Stage paths explicitly and never use `git add -A`.
- **English** for progress updates and reports. English locale and light theme only; Arabic, RTL, and dark mode are out of scope.
- **Bounded execution.** Every test or build gets `timeout`. Stop a stalled task rather than waiting on it.

## Per-batch procedure

Track these steps with tasks so progress is visible.

1. **Baseline.** Run `git status`, `git log --oneline -3`, and record the HEAD SHA. Run `.claude/skills/android-emulator-qa/scripts/env_check.sh` once.
2. **Scope.** List each screen and flow in the batch with its Figma node and its route or file under `lib/features/*/presentation/`.
3. **Figma verification.** Run `/figma-ui-verify <node>` per screen and collect the differences. Routes without a frame stay `DesignPendingScreen`.
4. **Fix.** Fix the real defects, not just an audit. Follow the architecture: UI → Riverpod notifier → repository → `ApiClient`. Use theme tokens only, add strings to both ARB files, and use directional insets.
5. **Responsive tests.** Run `/flutter-responsive-qa <screens>`: four viewports × text scale 1.0/1.3, keyboard, reachability, and back navigation. Use a new test file per batch, e.g. `test/features/m01_batch<N>_layout_test.dart`. Add behaviour tests for every defect fixed.
6. **Regression.** Run `/flutter-regression-qa <new and affected test files>`. It must print `RESULT: ALL PASS`.
7. **Device QA.** Run `/android-emulator-qa <flows>`. If no device is available, the fallback runs and the report says emulator testing was not performed.
8. **Commit (local).** One commit per batch, staged with explicit paths:
   ```bash
   git add <paths> && git commit -F "${QA_OUT:-/tmp/workflow-qa}/msg.txt"
   ```
   Subject: `<summary> (M01 batch <N>)`. The body lists the defects fixed and the tests added. Write the message to a file, because quotes in the text break heredocs.
9. **Report (English) and stop.** Include:
   - Commit SHA and branch.
   - What changed, per screen.
   - Figma differences fixed or left, with reasons.
   - Test results with counts.
   - Emulator status: performed, or not performed and why.
   - Backend gaps found.
   - Checks the owner should run on their phone.

   Then stop. Don't push, and don't start the next batch.

## Reused skills

`/figma-ui-verify`, `/flutter-responsive-qa`, `/flutter-regression-qa`, `/android-emulator-qa` (project). Optionally the built-ins `/code-review` and `/security-review` on the batch diff before committing.
