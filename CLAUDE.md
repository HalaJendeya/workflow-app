# WorkFlow app

Flutter app for WorkFlow's **Client** and **Employee** roles. The Laravel backend is documented by the Postman collection **WorFlowNets** (Hala's Workspace).

## Commands

```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run --dart-define-from-file=.env          # api mode; copy .env.example
flutter run --dart-define=APP_MODE=mock           # demo data, no server
flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock
```

The cloud sessions have no Android SDK or emulator. Use widget tests, plus the web build in headless Chromium for render checks. The `gstatic` CDN is blocked, so web builds need `--no-web-resources-cdn`.

## Architecture

```
lib/app/                 composition root: providers.dart, router.dart, app.dart
lib/core/                config, network (ApiClient, envelope, errors), storage, design_system, widgets
lib/features/<feature>/  data/ (repositories: Api* + Mock*), domain/ (typed models),
                         application/ (Riverpod notifiers), presentation/ (screens)
lib/l10n/arb/            app_en.arb, app_ar.arb (generated code in lib/l10n/gen)
```

- UI → Riverpod notifier → repository → `ApiClient`. Widgets never make HTTP calls.
- All responses go through `ApiEnvelope` (`{success, message, data}`). Errors become `ApiException` with a typed `ApiFailureKind`.
- `ApiClient` sends `Authorization: Bearer` on every non-public route. It sends `X-Company` only on `/api/v1/client/*` and `/api/v1/employee/*`.
- Mock repositories are only wired when `APP_MODE=mock`, and the app shows a DEMO banner. Never fall back to mock data in api mode.

## Rules

- **Figma is the visual source of truth.** File `NGIAdfhxsrEy5hRorKjT8K`. Mobile app frames are on page `534:30389` (client at y≈0, employee at y≈5900); mobile auth frames are in `130:20944` and `150:2174`. Don't build screens from guesses; routes stay `DesignPendingScreen` until their frame has been inspected.
- `www.figma.com` is blocked in cloud sessions, so asset URLs can't be curled. Export icons with `use_figma` (`node.exportAsync({format: 'SVG_STRING'})`); export raster images as base64 in chunks of 46 KB or less, then decode them from the session transcript.
- Theme values come only from `AppTheme` / `AppSpacing`. Never hardcode colors or sizes in screens.
- Integrate an endpoint only when the collection documents its request and response. Model only the fields that are documented, and record anything missing in the backend gap report.
- Never run requests marked ⚠️ (destructive) or that mutate data against a real server without explicit approval.
- Every user-facing string goes in both ARB files. Layouts must work in RTL; use `EdgeInsetsDirectional` and `AlignmentDirectional`.
- Use `main` plus short-lived `feat/*` branches. Never commit secrets or `.env`. Don't push or merge without the owner's approval.
