---
name: flutter-responsive-qa
description: Responsive-layout QA for WorkFlow screens - writes or extends widget tests that render a screen at the four phone viewports and two text scales, with the keyboard raised, and assert no overflow, no clipped text, and reachable actions clear of the floating navigation. Use when a screen, form, sheet, or dialog is added or changed, or when a layout defect is reported on a phone.
argument-hint: "<screen or flow, e.g. 'employee tasks list'>"
---

# Flutter responsive QA

Target: **$ARGUMENTS**. English locale, light theme only. Arabic, RTL, and dark mode are out of scope until the owner asks.

## Harness (reuse it; don't rewrite it)

`test/helpers/viewport.dart` provides:
- `phoneViewports`: 320x640, 360x740, 390x844, 430x932
- `useViewport(tester, size)`
- `showKeyboard(tester, height)`
- `loadAppFonts()` (real fonts, so text metrics match a device)
- `screenshot(tester, name)`, which writes a PNG when `SCREENSHOT_DIR` is set

For the pattern, copy `test/features/overlays_layout_test.dart`:
- `_pumpMock` with a `ProviderScope` (`retry: (_, _) => null`), `AppConfig(mode: AppMode.mock)`, and an `InMemorySessionStorage` session for the right `Portal`
- `_reveal`, which scrolls a target into view and clear of the bottom 130 px where the navigation surface floats
- `_withKeyboard`, where the keyboard covers 42 % of the screen and the field must sit above it
- `_expectWhole`, which checks that `RenderParagraph.didExceedMaxLines` is false

For API-mode screens, use `test/helpers/route_http_adapter.dart` with documented payloads only.

## Matrix per screen

For each `phoneViewports` entry × text scale `[1.0, 1.3]`:
1. Render it. The framework reports any `RenderFlex overflowed` exception, and the test fails.
2. Check that key labels are whole (`_expectWhole`). Shrinking is done by `FitText`/`WordFitText`, not ellipsis.
3. Check that every primary action is `hitTestable()` after `_reveal`. Bottom sheets and dialogs sit above the navigation surface.
4. For forms: empty submit shows the errors and `validateAndReveal` scrolls to the first one; with the keyboard up, the focused field and its send/save button are above the keyboard.
5. Check back navigation (`masthead-back` or system back) returns to the previous screen.
6. Call `screenshot(tester, '<screen>_<viewport>_x<scale>')` at the key states.

## Fixing defects

- Use only `AppTheme`/`AppSpacing` values. Never hardcode colors or sizes.
- Use `EdgeInsetsDirectional`/`AlignmentDirectional` even though RTL isn't tested yet.
- Add new strings to **both** `app_en.arb` and `app_ar.arb`, then run `flutter gen-l10n`.
- Don't change visuals the Figma frame defines. Check with `/figma-ui-verify` first.
- Test hygiene: no `pumpAndSettle` while a spinner animates (use `pump(duration)`), and bound every loop.

## Render the screenshots

```bash
SCREENSHOT_DIR=${QA_OUT:-/tmp/workflow-qa}/shots timeout 900 flutter test <file> --timeout 60s
```

Then look at the PNGs with Read. Use a scratchpad dir and never commit screenshots. Finish with `/flutter-regression-qa <file>`.
