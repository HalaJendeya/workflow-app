import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/route_http_adapter.dart';
import '../../helpers/viewport.dart';

/// F8, found on the Redmi 8 (2026-11-17): choosing "Unread" in the bell's
/// panel changed the Home Notifications card too ("All 1", unread only)
/// until restart, because both read one global filter. Mocked HTTP only.

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, Object?> _n(String id, String title, {bool read = false}) => {
  'id': id,
  'type': 'x',
  'category': 'x',
  'title': title,
  'message': 'Body of $title',
  'data': <String, Object>{},
  'subject': null,
  'actor': null,
  'company_id': 3,
  'is_read': read,
  'read_at': read ? '2026-11-14T10:00:00Z' : null,
  'created_at': '2026-11-14T09:00:00Z',
};

void main() {
  late RouteHttpAdapter http;
  late Set<String> readIds;

  (int, Object?) inbox(RequestOptions o) {
    final all = [
      _n('n1', 'Task assigned', read: readIds.contains('n1')),
      _n('n2', 'Meeting moved', read: true),
    ];
    final items = switch (o.queryParameters['status']) {
      'unread' => all.where((n) => n['is_read'] == false).toList(),
      'read' => all.where((n) => n['is_read'] == true).toList(),
      _ => all,
    };
    return (
      200,
      ok({
        'notifications': items,
        'meta': {
          'current_page': 1,
          'last_page': 1,
          'per_page': 20,
          'total': items.length,
          'unread_count': all.where((n) => n['is_read'] == false).length,
        },
      }),
    );
  }

  Future<void> pump(WidgetTester tester) async {
    useViewport(tester, const Size(390, 844));
    await loadAppFonts();
    readIds = {};
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 'tkn',
        tokenType: 'Bearer',
        userId: 1,
        companyId: 3,
        portal: Portal.client,
      ).toStorage(),
    );
    http = RouteHttpAdapter(
      {
        'GET /api/v1/client/account': (
          200,
          ok({'id': 1, 'email': 'c@test.dev', 'name': 'Client QA'}),
        ),
      },
      handlers: {
        'GET /api/v1/client/notifications': inbox,
        'POST /api/v1/client/notifications/n1/read': (_) {
          readIds.add('n1');
          return (200, ok(_n('n1', 'Task assigned', read: true)));
        },
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
          ),
          sessionStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_Auth()),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'https://api.test',
              credentials: ref.watch(sessionCredentialsProvider),
              adapter: http,
            ),
          ),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openBell(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Notifications').first);
    await tester.pumpAndSettle();
  }

  Future<void> closePanel(WidgetTester tester) async {
    Navigator.of(tester.element(find.byKey(const Key('notifications-panel'))))
        .pop();
    await tester.pumpAndSettle();
  }

  Finder home(String id) => find.byKey(Key('home-notification-$id'));
  Finder panel(String id) => find.byKey(Key('notification-$id'));

  testWidgets('Unread in the bell panel leaves the Home card on All', (
    tester,
  ) async {
    await pump(tester);
    expect(home('n1'), findsOneWidget);
    expect(home('n2'), findsOneWidget);
    expect(find.text('All 2'), findsOneWidget);

    await openBell(tester);
    await tester.tap(find.byKey(const Key('notifications-filter-unread')));
    await tester.pumpAndSettle();
    expect(panel('n1'), findsOneWidget);
    expect(panel('n2'), findsNothing);
    expect(find.text('1 unread'), findsOneWidget);

    await closePanel(tester);
    // Before the fix Home showed "All 1" with only the unread item.
    expect(home('n1'), findsOneWidget);
    expect(home('n2'), findsOneWidget);
    expect(find.text('All 2'), findsOneWidget);
  });

  testWidgets('the panel opens on All every time', (tester) async {
    await pump(tester);
    await openBell(tester);
    await tester.tap(find.byKey(const Key('notifications-filter-read')));
    await tester.pumpAndSettle();
    expect(panel('n1'), findsNothing);
    await closePanel(tester);

    await openBell(tester);
    expect(panel('n1'), findsOneWidget);
    expect(panel('n2'), findsOneWidget);
  });

  testWidgets('a read in the filtered panel updates Home from the server', (
    tester,
  ) async {
    await pump(tester);
    await openBell(tester);
    await tester.tap(find.byKey(const Key('notifications-filter-unread')));
    await tester.pumpAndSettle();
    await tester.tap(panel('n1'));
    await tester.pumpAndSettle();
    expect(panel('n1'), findsNothing);
    expect(find.text('0 unread'), findsOneWidget);
    await closePanel(tester);

    // Home still lists both; n1 is now read, and the badge has no dot.
    expect(home('n1'), findsOneWidget);
    expect(home('n2'), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.isLabelVisible, isFalse);
  });
}
