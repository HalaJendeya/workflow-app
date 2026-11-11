---
name: figma-ui-verify
description: Compare a WorkFlow Flutter screen against its Figma frame (file NGIAdfhxsrEy5hRorKjT8K) - fetch the frame's screenshot and metadata through the Figma MCP, render the Flutter screen at 390x844, and list the differences in layout, spacing, typography, color, copy, and components. Use before building or changing any screen, and to verify one afterwards.
argument-hint: "<figma node id or screen name> [flutter test/screen]"
---

# Figma UI verify

Figma is the visual source of truth (see CLAUDE.md). Target: **$ARGUMENTS**.

## 1. Fetch the design (read-only)

`www.figma.com` is blocked for curl, so use the Figma MCP tools only:
1. `mcp__Figma__create_session` with fileKey `NGIAdfhxsrEy5hRorKjT8K` and a short task description. Reuse its `sessionId` on every later call.
2. `mcp__Figma__get_metadata` on the frame gives node tree, sizes, and positions.
3. `mcp__Figma__get_screenshot` with `enableBase64Response: true` returns the image.
4. If you need exact tokens or styles: invoke `/figma:figma-design-to-code` **before** `get_design_context` (mandatory), and `/figma:figma-use` before any `use_figma`. For icons, use `use_figma` with `node.exportAsync({format:'SVG_STRING'})`. Export raster images in base64 chunks of 46 KB or less.

Never write to the Figma file.

## Frame map (page `534:30389`; client at y≈0, employee at y≈5900)

| Screen | Node | Screen | Node |
|---|---|---|---|
| Client dashboard | 643:32669 | Conversations | 643:36662 |
| Projects | 643:34237 | Chat | 643:37061 |
| Add project | 643:34778 | Meetings | 643:38772 |
| Invoices | 643:36002 | Meeting details | 643:37740 |
| Create invoice | 643:36437 | Schedule meeting | 643:39086 |
| Payments | 643:35269 | Join by code | 643:38034 |
| Add payment | 643:35666 | Profile | 643:33288 |
| Companies | 673:14300 | Client More | 666:69807 |
| Sprint | 729:24447 | Employee More | 729:46349 |

Auth frames: `130:20944`, `150:2174`. For an unmapped screen, run `get_metadata` on `534:30389` and find it by name and y-position. Add it to this table in the same commit.

If no frame exists for a route, it stays `DesignPendingScreen`. Report this and don't invent a layout.

## 2. Render the Flutter screen

Use a widget test at `Size(390, 844)` (the frame width) with `screenshot(...)` from `test/helpers/viewport.dart`. See `/flutter-responsive-qa`.

```bash
SCREENSHOT_DIR=${QA_OUT:-/tmp/workflow-qa}/figma timeout 900 flutter test <file> --plain-name '<test>' --timeout 60s
```

## 3. Compare and report

View the two images side by side and walk the metadata tree top-down. For each difference, give:
- **Region**: masthead, filters, card, list row, FAB, navigation surface, or sheet.
- **Figma vs Flutter**: size, spacing, font size and weight, color token, copy, icon, radius, or elevation.
- **Severity**: `blocker` (missing or wrong component, wrong flow), `visible` (more than 4 px off, or wrong token or copy), or `nit`.

Fix blockers and visible issues with `AppTheme`/`AppSpacing` tokens. Don't hardcode values. If Figma and a documented API field conflict, keep the Figma layout and record the data gap. Dynamic data like names and amounts may differ; structure and styling may not.

These Figma plugin skills are reused by reference, not copied: `figma:figma-design-to-code`, `figma:figma-use`.
