import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/companies/presentation/companies_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';

/// Redmi 8 F1: the live `GET /client/companies` (2026-11-22) answers 200
/// with membership rows `{status, client, company}`, and the QA client's
/// login has no `company_id`, so no `X-Company` is sent. The Companies tab
/// showed "Something went wrong" because the parser read `id`/`name` from
/// the row instead of its `company`.
Map<String, Object?> _ok(Object? data) => {
  'success': true,
  'message': 'Companies retrieved',
  'data': data,
};

const Map<String, Object?> _membership = {
  'status': 'approved',
  'client': {
    'id': 7,
    'name': 'Client A',
    'email': 'a@client.test',
    'created_at': '2026-10-01T00:00:00.000000Z',
    'updated_at': '2026-10-01T00:00:00.000000Z',
  },
  'company': {
    'id': 1,
    'name': 'Live Co',
    'email': 'hi@live.test',
    'domain': 'live.test',
    'logo': null,
    'created_at': '2026-09-01T00:00:00.000000Z',
    'updated_at': '2026-09-01T00:00:00.000000Z',
  },
};

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final width in const [320.0, 360.0]) {
      testWidgets('Companies lists a live membership row: '
          '${locale.languageCode} ${width.toInt()} dp', (tester) async {
        useViewport(tester, Size(width, 760));
        final storage = InMemorySessionStorage();
        await storage.writeAll(
          const Session(
            token: 't',
            tokenType: 'Bearer',
            userId: 10,
            // No companyId: the live client login answers company_id: null.
            portal: Portal.client,
          ).toStorage(),
        );
        final http = RouteHttpAdapter({
          'GET /api/v1/client/companies': (200, _ok([_membership])),
        });
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                mode: AppMode.api,
                apiBaseUrl: 'https://api.test',
              ),
            ),
            sessionStorageProvider.overrideWithValue(storage),
            apiClientProvider.overrideWith(
              (ref) => ApiClient(
                baseUrl: 'https://api.test',
                credentials: ref.watch(sessionCredentialsProvider),
                adapter: http,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(sessionControllerProvider.future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CompaniesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CompaniesScreen)),
        );
        expect(find.text(l10n.errorServer), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Live Co'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Live Co'), findsOneWidget);
        // The client's own name is not shown as a company.
        expect(find.text('Client A'), findsNothing);

        final req = http.requests.singleWhere(
          (r) => r.uri.path == '/api/v1/client/companies',
        );
        // No company in the session: no X-Company, as on the phone.
        expect(req.headers.containsKey('X-Company'), isFalse);
      });
    }
  }
}
