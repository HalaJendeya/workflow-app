import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/companies/data/client_companies_repository.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';

/// M04: Client Dashboard, Companies and Projects against the documented
/// client routes of the `WorkFlow` collection. Mocked HTTP only; live
/// verification is reported separately.

class _Creds implements ApiCredentials {
  @override
  String? token = 'tkn';
  @override
  int? companyId = 25;
  @override
  void onUnauthorized() {}
}

Map<String, dynamic> _row(
  int id,
  String title, {
  String status = 'in_progress',
}) => {
  'id': id,
  'title': title,
  'status': status,
  'budget': '1200.50',
  'currency': {'id': 1, 'code': 'USD', 'symbol': r'$'},
  'completion_percentage': 40,
};

Map<String, dynamic> _projectList(List<Object> rows, {Object? stats}) => {
  'success': true,
  'message': 'OK',
  'data': {
    'current_page': 1,
    'data': rows,
    'last_page': 1,
    'per_page': 10,
    'total': rows.length,
  },
  'stats': ?stats,
};

const _stats = {'total': 7, 'pending': 1, 'in_progress': 4, 'completed': 2};

/// A client account's server. Answers depend on the bearer token, so a
/// second account sees only its own data; [gates] hold a path open.
class _Server implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, Completer<void>> gates = {};
  int projectShowStatus = 200;
  List<Object> companies = const [];
  int companiesStatus = 200;

  bool _isB(RequestOptions o) => o.headers['Authorization'] == 'Bearer tkn-b';

  (int, Object?) _reply(RequestOptions o) {
    final b = _isB(o);
    switch (o.uri.path) {
      case '/api/v1/client/account':
        return (200, ok({'id': b ? 2 : 1, 'email': 'x@test.dev'}));
      case '/api/v1/client/notifications':
        return (
          200,
          ok({
            'notifications': <Object>[],
            'meta': {
              'current_page': 1,
              'last_page': 1,
              'per_page': 20,
              'total': 0,
              'unread_count': 0,
            },
          }),
        );
      case '/api/v1/client/notifications/unread-count':
        return (200, ok({'unread_count': 0}));
      case '/api/v1/client/dashboard':
        return (
          200,
          ok({
            'projectsCount': b ? 9 : 7,
            'projectsCompleted': b ? 0 : 2,
            'projectsInProgress': b ? 9 : 4,
          }),
        );
      case '/api/v1/client/projects':
        return (
          200,
          _projectList(
            b
                ? [_row(20, 'Account B project')]
                : [_row(1, 'Customer Portal Revamp'), _row(2, 'Billing')],
            stats: b
                ? {'total': 9, 'pending': 0, 'in_progress': 9, 'completed': 0}
                : _stats,
          ),
        );
      case '/api/v1/client/projects/1':
        return projectShowStatus == 200
            ? (
                200,
                ok({
                  ..._row(1, 'Customer Portal Revamp (renamed)'),
                  'company': {'id': 3, 'name': 'Tech Company'},
                  'leader': {'id': 9, 'name': 'Sara Khalil'},
                }),
              )
            : (projectShowStatus, failure('Not found.'));
      case '/api/v1/client/invoices':
        return (
          200,
          ok({
            'current_page': 1,
            'data': <Object>[],
            'last_page': 1,
            'per_page': 10,
            'total': 0,
            'stats': {
              'total': 0,
              'paid': 0,
              'unpaid': 0,
              'partially_paid': 0,
              'overdue': 0,
            },
          })..['totals'] = <Object>[],
        );
      case '/api/v1/client/companies':
        return companiesStatus == 200
            ? (200, ok(companies))
            : (companiesStatus, failure('Server Error'));
    }
    return (404, failure('Not found'));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    await gates[o.uri.path]?.future;
    final (status, body) = _reply(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> to(String path) =>
      requests.where((r) => r.uri.path == path);
}

/// Signs in account B; logout always succeeds.
class _Auth implements AuthRepository {
  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async => const Session(
    token: 'tkn-b',
    tokenType: 'Bearer',
    userId: 2,
    portal: Portal.client,
  );

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _sessionA = Session(
  token: 'tkn-a',
  tokenType: 'Bearer',
  userId: 1,
  companyId: 3,
  portal: Portal.client,
);

Future<_Server> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  useViewport(tester, size);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(_sessionA.toStorage());
  final server = _Server();
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
            adapter: server,
          ),
        ),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final r = tester.getRect(target);
  if (r.bottom > h - 130) {
    await tester.drag(scroll, Offset(0, h - 130 - r.bottom));
    await tester.pumpAndSettle();
  }
}

/// [settle] false: a gated request keeps a spinner running, which never
/// settles, so frames are pumped for the page transition instead.
Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await _reveal(tester, target);
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> _openFromMore(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(Key('category-$label')), settle: settle);
}

void main() {
  group('contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late _Creds creds;
    late ApiClient client;

    setUp(() {
      http = FakeHttpAdapter();
      creds = _Creds();
      client = ApiClient(
        baseUrl: 'https://api.test',
        credentials: creds,
        adapter: http,
      );
    });

    test(
      'List My Companies: GET with bearer and X-Company; list rows',
      () async {
        http.reply(
          200,
          ok([
            {
              'id': 3,
              'name': 'Tech Company',
              'domain': 'tech.test',
              'logo': null,
            },
            {'id': 4, 'name': 'Ra', 'email': 'hi@ra.test', 'domain': ''},
          ]),
        );
        final list = await ClientCompaniesRepository(client).list();
        expect(http.last.method, 'GET');
        expect(http.last.path, '/api/v1/client/companies');
        expect(http.last.headers['Authorization'], 'Bearer tkn');
        expect(http.last.headers['X-Company'], '25');
        expect(list.map((c) => c.id), [3, 4]);
        expect(list.first.subtitle, 'tech.test');
        // An empty domain falls back to the email; nothing is made up.
        expect(list.last.subtitle, 'hi@ra.test');
      },
    );

    test('List My Companies: no company gives an empty list', () async {
      http.reply(200, ok(<Object>[]));
      expect(await ClientCompaniesRepository(client).list(), isEmpty);
    });

    test('List My Companies: a row without a name is invalid', () async {
      http.reply(
        200,
        ok([
          {'id': 3},
        ]),
      );
      await expectLater(
        ClientCompaniesRepository(client).list(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('List My Companies: non-list data is invalid', () async {
      http.reply(200, ok({'id': 3}));
      await expectLater(
        ClientCompaniesRepository(client).list(),
        throwsA(isA<ApiException>()),
      );
    });

    test('project details: GET /client/projects/{id}', () async {
      http.reply(200, ok(_row(7, 'Portal')));
      final p = await ProjectsRepository(client, Portal.client).show(7);
      expect(http.last.path, '/api/v1/client/projects/7');
      expect(http.last.headers['X-Company'], '25');
      expect(p.id, 7);
      expect(p.budget, 1200.5);
    });

    test('project details: 404 and 403 surface as typed failures', () async {
      http.reply(404, failure('Not found.'));
      await expectLater(
        ProjectsRepository(client, Portal.client).show(99),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.notFound,
          ),
        ),
      );
      http.reply(403, failure('Forbidden'));
      await expectLater(
        ProjectsRepository(client, Portal.client).show(98),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.forbidden,
          ),
        ),
      );
    });

    test(
      'project list without the documented stats is invalid, not 0',
      () async {
        http.reply(200, _projectList([_row(1, 'A')]));
        await expectLater(
          ProjectsRepository(
            client,
            Portal.client,
          ).list((search: '', status: null, page: 1)),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      },
    );

    test('project list sends search, status and page as documented', () async {
      http.reply(200, _projectList(const [], stats: _stats));
      await ProjectsRepository(client, Portal.client).list((
        search: ' portal ',
        status: ApiProjectStatus.inProgress,
        page: 2,
      ));
      expect(http.last.queryParameters, {
        'page': 2,
        'per_page': 10,
        'search': 'portal',
        'status': 'in_progress',
      });
    });
  });

  group('Client Dashboard', () {
    testWidgets('no count is shown before the server sends it', (tester) async {
      final server = await _pump(tester);
      server.gates['/api/v1/client/projects'] = Completer<void>();
      await _openFromMore(tester, 'Dashboard', settle: false);
      final chip = find.byKey(const Key('dash-running'));
      await tester.ensureVisible(chip);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(of: chip, matching: find.text('Running')),
        findsOneWidget,
      );
      expect(find.text('0 Running'), findsNothing);
      server.gates['/api/v1/client/projects']!.complete();
      await tester.pumpAndSettle();
      expect(find.text('4 Running'), findsOneWidget);
    });

    testWidgets('a figure opens Projects filtered to what it counts', (
      tester,
    ) async {
      final server = await _pump(tester);
      await _openFromMore(tester, 'Dashboard');
      expect(find.text('7'), findsWidgets);
      await _tap(tester, find.byKey(const Key('dash-completed')));
      expect(find.text('Projects Management'), findsOneWidget);
      expect(
        server.to('/api/v1/client/projects').last.queryParameters['status'],
        'completed',
      );
      // Back returns to the dashboard.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('masthead-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dash-completed')), findsOneWidget);
    });

    testWidgets('rapid open and back leaves no error and one live page', (
      tester,
    ) async {
      await _pump(tester);
      for (var i = 0; i < 3; i++) {
        await _openFromMore(tester, 'Dashboard');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const Key('masthead-back')));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('category-Dashboard')), findsOneWidget);
    });
  });

  group('Client Companies', () {
    testWidgets('no linked company: says so, no demo rows', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Companies').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('no-companies')), findsOneWidget);
      expect(find.byKey(const Key('my-companies-note')), findsOneWidget);
      expect(find.text('Gaza'), findsNothing);
    });

    testWidgets('one company is listed read-only; search narrows', (
      tester,
    ) async {
      final server = await _pump(tester);
      server.companies = const [
        {'id': 3, 'name': 'Tech Company', 'domain': 'tech.test'},
        {'id': 4, 'name': 'Ra', 'email': 'hi@ra.test'},
      ];
      await tester.tap(find.text('Companies').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('company-api-3')), findsOneWidget);
      expect(find.text('tech.test'), findsOneWidget);
      expect(find.text('Join Request'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'ra');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('company-api-3')), findsNothing);
      expect(find.byKey(const Key('company-api-4')), findsOneWidget);
    });

    testWidgets('a failed load offers Retry, which recovers', (tester) async {
      final server = await _pump(tester);
      server.companiesStatus = 500;
      await tester.tap(find.text('Companies').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('api-error')), findsOneWidget);
      server
        ..companiesStatus = 200
        ..companies = const [
          {'id': 3, 'name': 'Tech Company'},
        ];
      await _tap(tester, find.byKey(const Key('api-retry')));
      expect(find.byKey(const Key('api-error')), findsNothing);
      expect(find.text('Tech Company'), findsOneWidget);
    });
  });

  group('Client Projects', () {
    testWidgets('View details loads the project from the server', (
      tester,
    ) async {
      final server = await _pump(tester);
      server.gates['/api/v1/client/projects/1'] = Completer<void>();
      await _openFromMore(tester, 'Projects');
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const Key('api-project-1')),
          matching: find.text('View Details'),
        ),
        settle: false,
      );
      // The row shows at once, with a loading bar.
      expect(find.byKey(const Key('project-details')), findsOneWidget);
      expect(find.byKey(const Key('project-details-loading')), findsOneWidget);
      server.gates['/api/v1/client/projects/1']!.complete();
      await tester.pumpAndSettle();
      expect(server.to('/api/v1/client/projects/1'), hasLength(1));
      expect(find.text('Customer Portal Revamp (renamed)'), findsOneWidget);
      expect(find.text('Sara Khalil'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project-details')), findsNothing);
    });

    testWidgets('a project the account may not see shows the error and Retry', (
      tester,
    ) async {
      final server = await _pump(tester, size: const Size(320, 640));
      server.projectShowStatus = 404;
      await _openFromMore(tester, 'Projects');
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const Key('api-project-1')),
          matching: find.text('View Details'),
        ),
      );
      expect(find.byKey(const Key('api-error')), findsOneWidget);
      // No stale row fields next to the error.
      expect(
        find.descendant(
          of: find.byKey(const Key('project-details')),
          matching: find.text('Budget'),
        ),
        findsNothing,
      );
      server.projectShowStatus = 200;
      await tester.tap(find.byKey(const Key('api-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('api-error')), findsNothing);
      expect(find.text('Customer Portal Revamp (renamed)'), findsOneWidget);
    });
  });

  testWidgets('a new session sees only its own data and headers', (
    tester,
  ) async {
    final server = await _pump(tester);
    await _openFromMore(tester, 'Dashboard');
    expect(find.text('Customer Portal Revamp'), findsOneWidget);
    for (final r in server.requests) {
      expect(r.headers['Authorization'], 'Bearer tkn-a');
      if (r.uri.path.startsWith('/api/v1/client/')) {
        expect(r.headers['X-Company'], '3');
      }
    }

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorkFlowApp)),
    );
    await container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(find.text('Account Type'), findsOneWidget);
    final before = server.requests.length;
    await container
        .read(sessionControllerProvider.notifier)
        .login(email: 'b@test.dev', password: 'x', portal: Portal.client);
    await tester.pumpAndSettle();
    await _openFromMore(tester, 'Dashboard');

    expect(find.text('Account B project'), findsOneWidget);
    expect(find.text('Customer Portal Revamp'), findsNothing);
    final after = server.requests.skip(before);
    expect(after, isNotEmpty);
    for (final r in after) {
      expect(r.headers['Authorization'], 'Bearer tkn-b');
      // Account B has no company: no tenant header is sent.
      expect(r.headers.containsKey('X-Company'), isFalse);
    }
  });
}
