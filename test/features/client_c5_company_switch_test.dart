import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/companies/data/client_companies_repository.dart';
import 'package:workflow_app/features/companies/presentation/companies_screen.dart';
import 'package:workflow_app/features/dashboard/data/client_dashboard_repository.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';

/// Client C5: the company a client works in. The collection (§4 "Company
/// context — X-Company") makes `X-Company` the tenant for every role
/// route: a company the account may use is accepted, any other answers 403
/// (SEC-005, "Unauthorized Company (X-Company) → 403" on the read-only
/// `GET /client/dashboard`). `GET /client/companies` lists the account's
/// companies (`data` list). There is no switch route: switching is sending
/// another `X-Company`. Every response here is a test double; nothing was
/// sent to a live server.

const _base = '/api/v1/client';

const _session = Session(
  token: 'tkn',
  tokenType: 'Bearer',
  userId: 1,
  companyId: 3,
  portal: Portal.client,
);

Map<String, Object?> _err(String m) => {
  'success': false,
  'message': m,
  'errors': <String, Object>{},
};

const List<Map<String, Object>> _companies = [
  {'id': 3, 'name': 'Gaza Works', 'domain': 'gaza.example'},
  {'id': 7, 'name': 'Tech Company', 'email': 'hello@tech.example'},
  {'id': 9, 'name': 'Pending Co', 'domain': 'pending.example'},
];

/// Answers per company (the request's `X-Company`): company 9 refuses
/// like a company the account may not use yet.
(int, Object?) _dashboard(RequestOptions o) => switch (o.headers['X-Company']) {
  '3' => (
    200,
    ok({'projectsCount': 4, 'projectsCompleted': 1, 'projectsInProgress': 2}),
  ),
  '7' => (
    200,
    ok({'projectsCount': 9, 'projectsCompleted': 5, 'projectsInProgress': 3}),
  ),
  '9' => (403, _err('You do not have access to this company.')),
  _ => (500, _err('x')),
};

/// Projects of the request's company: `data` is the paginator, `stats`
/// sits beside it (as the projects list reads them).
(int, Object?) _projects(RequestOptions o) => (
  200,
  {
    ...ok({
      'data': [
        {
          'id': o.headers['X-Company'] == '7' ? 70 : 30,
          'title': 'Project of company ${o.headers['X-Company']}',
          'status': 'in_progress',
        },
      ],
      'current_page': 1,
      'last_page': 1,
      'per_page': 10,
      'total': 1,
    }),
    'stats': {'total': 1, 'pending': 0, 'in_progress': 1, 'completed': 0},
  },
);

const ProjectQuery _q = (search: '', status: null, page: 1);

class _Creds implements ApiCredentials {
  @override
  String? get token => 'tkn';
  @override
  int? get companyId => 3;
  @override
  void onUnauthorized() {}
}

/// Holds the access check's reply until [gate] completes, so a test can
/// look at the screen while a switch is on the way.
class _Gated implements HttpClientAdapter {
  new(this.inner, this.gate);

  final RouteHttpAdapter inner;
  final Future<void> gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path == '$_base/dashboard') await gate;
    return await inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, RouteHttpAdapter, InMemorySessionStorage)> _boot({
  bool remembered = true,
  Map<String, (int, Object?) Function(RequestOptions)> handlers = const {},
  Future<void>? gate,
}) async {
  final storage = InMemorySessionStorage();
  if (remembered) await storage.writeAll(_session.toStorage());
  final http = RouteHttpAdapter(
    {'GET $_base/companies': (200, ok(_companies))},
    handlers: {
      'GET $_base/dashboard': _dashboard,
      'GET $_base/projects': _projects,
      ...handlers,
    },
  );
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
      ),
      sessionStorageProvider.overrideWithValue(storage),
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: 'https://api.test',
          credentials: ref.watch(sessionCredentialsProvider),
          adapter: gate == null ? http : _Gated(http, gate),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  if (!remembered) {
    // "Remember me" off: the session lives in memory only.
    await c.read(sessionControllerProvider.future);
    c.read(sessionCredentialsProvider).session = _session;
    c.read(sessionControllerProvider.notifier).state = const AsyncData(
      _session,
    );
  } else {
    await c.read(sessionControllerProvider.future);
  }
  return (c, http, storage);
}

void main() {
  group('contract: X-Company and the access check', () {
    test('a request naming its company keeps it; others get the '
        "session's", () async {
      final http = FakeHttpAdapter()
        ..reply(200, ok(<Object>[]))
        ..reply(200, ok(<Object>[]))
        ..reply(200, ok(<Object>[]));
      final client = ApiClient(
        baseUrl: 'https://api.test',
        credentials: _Creds(),
        adapter: http,
      );
      await client.get('$_base/projects');
      await client.get('$_base/dashboard', headers: {'X-Company': '7'});
      await client.get('/api/v1/employee/tasks');
      expect(http.requests[0].headers['X-Company'], '3');
      expect(http.requests[1].headers['X-Company'], '7');
      expect(http.requests[1].headers['Authorization'], 'Bearer tkn');
      expect(http.requests[2].headers['X-Company'], '3');
    });

    test(
      'checkAccess is the read-only dashboard GET with that company',
      () async {
        final http = RouteHttpAdapter(
          {},
          handlers: {'GET $_base/dashboard': _dashboard},
        );
        final repo = ClientCompaniesRepository(
          ApiClient(
            baseUrl: 'https://api.test',
            credentials: _Creds(),
            adapter: http,
          ),
        );
        await repo.checkAccess(7);
        final r = http.requests.single;
        expect(r.method, 'GET');
        expect(r.uri.path, '$_base/dashboard');
        expect(r.headers['X-Company'], '7');
        expect(r.data, isNull);
        await expectLater(
          repo.checkAccess(9),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiFailureKind.forbidden,
            ),
          ),
        );
      },
    );

    test('withCompany keeps token, user and portal', () {
      final s = _session.withCompany(7);
      expect(
        (s.token, s.userId, s.portal, s.companyId),
        ('tkn', 1, Portal.client, 7),
      );
      expect(Session.fromStorage(s.toStorage()).companyId, 7);
    });
  });

  group('switching', () {
    test(
      'accepted: the session and stored session move to the company',
      () async {
        final (c, http, storage) = await _boot();
        expect(
          await c.read(companySwitchProvider.notifier).switchTo(7),
          isTrue,
        );
        expect(c.read(sessionControllerProvider).value?.companyId, 7);
        expect(c.read(sessionCredentialsProvider).companyId, 7);
        expect((await storage.readAll())['company_id'], '7');
        expect(http.requests.where((r) => r.method != 'GET'), isEmpty);
      },
    );

    test('"Remember me" off: nothing is written to the device', () async {
      final (c, _, storage) = await _boot(remembered: false);
      await c.read(companySwitchProvider.notifier).switchTo(7);
      expect(c.read(sessionControllerProvider).value?.companyId, 7);
      expect(await storage.readAll(), isEmpty);
    });

    test('refused (403): nothing changes and the error comes back', () async {
      final (c, _, storage) = await _boot();
      await expectLater(
        c.read(companySwitchProvider.notifier).switchTo(9),
        throwsA(isA<ApiException>()),
      );
      expect(c.read(sessionControllerProvider).value?.companyId, 3);
      expect((await storage.readAll())['company_id'], '3');
      expect(c.read(companySwitchProvider), isNull);
    });

    test('a second switch while one runs is dropped; the active company '
        'is not checked again', () async {
      final (c, http, _) = await _boot();
      final n = c.read(companySwitchProvider.notifier);
      final results = await Future.wait([n.switchTo(7), n.switchTo(7)]);
      expect(results, [true, false]);
      expect(
        http.requests.where((r) => r.uri.path == '$_base/dashboard'),
        hasLength(1),
      );
      expect(await n.switchTo(7), isFalse, reason: 'already active');
      expect(
        http.requests.where((r) => r.uri.path == '$_base/dashboard'),
        hasLength(1),
      );
    });

    test('a sign-out during the switch is not undone by it', () async {
      final (c, _, storage) = await _boot(
        handlers: {'POST /api/v1/logout': (_) => (200, ok(null))},
      );
      final pending = c.read(companySwitchProvider.notifier).switchTo(7);
      await c.read(sessionControllerProvider.notifier).logout();
      await pending.catchError((_) => false);
      expect(c.read(sessionControllerProvider).value, isNull);
      expect(await storage.readAll(), isEmpty);
    });
  });

  group('isolation: data reloads for the new company', () {
    test('dashboard, projects and the company list are read again with '
        'the new X-Company; nothing of the old company remains', () async {
      final (c, http, _) = await _boot();
      final subs = [
        c.listen(clientDashboardSummaryProvider, (_, _) {}),
        c.listen(apiProjectsProvider(_q), (_, _) {}),
        c.listen(clientCompaniesProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final s in subs) {
          s.close();
        }
      });
      expect((await c.read(clientDashboardSummaryProvider.future)).projects, 4);
      expect(
        (await c.read(apiProjectsProvider(_q).future)).page.items.single.id,
        30,
      );
      await c.read(clientCompaniesProvider.future);
      final before = http.requests.length;

      await c.read(companySwitchProvider.notifier).switchTo(7);

      expect((await c.read(clientDashboardSummaryProvider.future)).projects, 9);
      expect(
        (await c.read(apiProjectsProvider(_q).future)).page.items.single.id,
        70,
      );
      await c.read(clientCompaniesProvider.future);
      final after = http.requests.skip(before).toList();
      // The check, then every reload, all with the new company.
      expect(after.map((r) => r.headers['X-Company']).toSet(), {'7'});
      expect(
        after.map((r) => r.uri.path).toSet(),
        containsAll([
          '$_base/dashboard',
          '$_base/projects',
          '$_base/companies',
        ]),
      );
    });
  });

  group('companies screen', () {
    late RouteHttpAdapter http;
    late ProviderContainer scope;

    Future<void> pump(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      Size size = const Size(390, 844),
      double textScale = 1,
      Map<String, (int, Object?) Function(RequestOptions)> handlers = const {},
      Future<void>? gate,
    }) async {
      useViewport(tester, size, ratio: 3);
      final (c, h, _) = await _boot(handlers: handlers, gate: gate);
      scope = c;
      http = h;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const CompaniesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('the active company is marked; switching asks, checks, '
        'then moves the mark', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('company-active-3')), findsOneWidget);
      expect(find.byKey(const Key('company-use-3')), findsNothing);
      expect(find.byKey(const Key('company-use-7')), findsOneWidget);
      expect(find.byKey(const Key('join-api-7')), findsNothing);

      // Cancel: nothing is requested.
      await tapVisible(tester, find.byKey(const Key('company-use-7')));
      expect(find.text('Switch company?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final checks = http.requests
          .where((r) => r.uri.path == '$_base/dashboard')
          .length;
      expect(checks, 0);

      await tapVisible(tester, find.byKey(const Key('company-use-7')));
      await tester.tap(find.byKey(const Key('company-switch-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Now working in Tech Company.'), findsOneWidget);
      expect(find.byKey(const Key('company-active-7')), findsOneWidget);
      expect(find.byKey(const Key('company-use-3')), findsOneWidget);
      expect(scope.read(sessionControllerProvider).value?.companyId, 7);
      expect(http.requests.where((r) => r.method != 'GET'), isEmpty);
    });

    testWidgets('a refused company (403) says so and changes nothing', (
      tester,
    ) async {
      await pump(tester);
      await tapVisible(tester, find.byKey(const Key('company-use-9')));
      await tester.tap(find.byKey(const Key('company-switch-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text("Your account can't work in Pending Co yet."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('company-active-3')), findsOneWidget);
      expect(scope.read(sessionControllerProvider).value?.companyId, 3);
    });

    testWidgets('a server error says so and changes nothing', (tester) async {
      await pump(
        tester,
        handlers: {'GET $_base/dashboard': (_) => (500, _err('boom'))},
      );
      await tapVisible(tester, find.byKey(const Key('company-use-7')));
      await tester.tap(find.byKey(const Key('company-switch-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't switch company."), findsOneWidget);
      expect(scope.read(sessionControllerProvider).value?.companyId, 3);
    });

    testWidgets('while one switch runs the other buttons are off', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pump(tester, gate: gate.future);
      await tapVisible(tester, find.byKey(const Key('company-use-7')));
      await tester.tap(find.byKey(const Key('company-switch-confirm')));
      // The check is held: the tapped card spins, the other is off, and a
      // second tap on it sends nothing.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final seven = tester.widget<InkWell>(
        find.byKey(const Key('company-use-7')),
      );
      final nine = tester.widget<InkWell>(
        find.byKey(const Key('company-use-9')),
      );
      expect(seven.onTap, isNull);
      expect(nine.onTap, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('company-use-7')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('company-active-7')), findsOneWidget);
      expect(
        http.requests.where((r) => r.uri.path == '$_base/dashboard'),
        hasLength(1),
      );
    });

    testWidgets('Arabic RTL', (tester) async {
      await pump(tester, locale: const Locale('ar'));
      expect(find.text('نشطة'), findsOneWidget);
      expect(find.text('استخدام هذه الشركة'), findsNWidgets(2));
      await tapVisible(tester, find.byKey(const Key('company-use-7')));
      expect(find.text('تبديل الشركة؟'), findsOneWidget);
      await tester.tap(find.byKey(const Key('company-switch-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('تعمل الآن في Tech Company.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('responsive', () {
      setUpAll(loadAppFonts);
      for (final locale in const [Locale('en'), Locale('ar')]) {
        for (final v in phoneViewports.entries) {
          for (final scale in const [1.0, 1.3]) {
            testWidgets('${locale.languageCode} ${v.key} x$scale', (
              tester,
            ) async {
              await pump(
                tester,
                locale: locale,
                size: v.value,
                textScale: scale,
              );
              final use = find.byKey(const Key('company-use-7'));
              await tester.ensureVisible(use);
              await tester.pumpAndSettle();
              expect(use.hitTestable(), findsOneWidget);
              await screenshot(
                tester,
                'c5_companies_${locale.languageCode}_${v.key}_x$scale',
              );
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    });
  });
}
