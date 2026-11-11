---
name: flutter-regression-qa
description: Bounded regression gate for the WorkFlow Flutter app - dart format check, flutter analyze, targeted widget tests, then the full suite, each under a hard timeout. Use before every local commit, after any change under lib/ or test/, or when asked to "run the tests" or "check for regressions".
argument-hint: "[targeted test files...]"
allowed-tools: Bash(.claude/skills/flutter-regression-qa/scripts/regression.sh *), Bash(flutter test *), Bash(flutter analyze*), Bash(dart format *), Bash(timeout *)
---

# Flutter regression QA

Proves a change broke nothing. It never edits code; it reports.

## Run

```bash
.claude/skills/flutter-regression-qa/scripts/regression.sh $ARGUMENTS
```

The script runs, in order, each with a hard `timeout`:

| Step | Command | Limit |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed lib test` | 2 min |
| analyze | `flutter analyze` | 5 min |
| targeted | `flutter test --timeout 60s <files>` (only if files given) | 15 min |
| full | `flutter test --timeout 90s` | 30 min |

For long runs, start it with `run_in_background` and wait for the completion notice. Do not poll with `sleep`.

## Rules

- **Bounded, always.** Never run `flutter test` without `timeout` and `--timeout`. A hang is a FAIL. Find the cause (usually `pumpAndSettle` while a spinner animates, or an unbounded `while` retry loop in a test); don't wait it out. If a background run stalls, stop only that task (`TaskStop`), then rerun the single file.
- **Loops in tests are bounded** (e.g. `for (var i = 0; i < 5 && cond; i++)`).
- **Never skip, delete, or loosen a failing test** to get green. Fix the code, or report the failure with its output.
- If `dart format` fails, run `dart format lib test` and include the change in the same commit.
- Pick targeted files from what changed. Existing suites to reuse:
  - Layout: `sprint_layout_test`, `forms_layout_test`, `overlays_layout_test`, `client_screens_layout_test`, `client_comms_layout_test`
  - Behaviour: `kanban_drag_test`, `forms_behavior_test`, `overlays_behavior_test`, `emulator_findings_test`, `notifications/notifications_filter_settle_test`
  - API contract: `client_api_contract_test`, `client_api_mode_test`, `employee_api_test`, `meetings_api_test`, `conversations_api_test`, `sprint_board_api_test`
- Out of scope until the owner asks: `rtl_screens_test`, `rtl_api_screens_test`, Arabic, and dark mode. They still run in the full suite and must stay green, but don't write new RTL, Arabic, or dark-mode checks.

## Report

List each step as PASS or FAIL with test counts, e.g. `+412 ~0 -0`. For any failure, quote the test name and the first assertion message. Only say "all green" if the script printed `RESULT: ALL PASS`.

For a code-quality pass on the diff, use the built-in `/code-review` or `/simplify`; this skill doesn't duplicate them.
