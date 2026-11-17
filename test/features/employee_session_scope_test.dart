import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';

import '../helpers/fake_http_adapter.dart';

/// Employee E2E QA (2026-11-17): the Dashboard and Timesheets figures must
/// follow the signed-in account and company, like every other employee
/// list. Before the fix these three providers watched neither, so while a
/// screen stayed mounted across an account switch they kept the previous
/// account's figures. Responses are test doubles shaped from the collection.
class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  static final Map<String, dynamic> _page = ok({
    'current_page': 1,
    'data': <Object>[],
    'last_page': 1,
    'per_page': 1,
    'total': 0,
  });

  Object _body(String path) => switch (path) {
    '/api/v1/employee/dashboard' => ok({
      'myTasks': 1,
      'myHours': 0,
      'myMinutes': 0,
      'totalEarned': 0,
      'paidSalary': 0,
      'unpaidSalary': 0,
    }),
    '/api/v1/employee/tasks' => {
      ..._page,
      'stats': {
        'total': 0,
        'by_status': <String, int>{},
        'active': 0,
        'logged_minutes': 0,
      },
    },
    '/api/v1/employee/timesheets' => {
      ..._page,
      'stats': {
        'count': 0,
        'approved': 0,
        'pending': 0,
        'rejected': 0,
        'total_minutes': 0,
      },
      'totals': <Object>[],
    },
    _ => failure('Not found'),
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = _body(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Auth implements AuthRepository {
  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async => const Session(
    token: 'tkn-b',
    tokenType: 'Bearer',
    userId: 11,
    companyId: 4,
    portal: Portal.employee,
  );

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('dashboard, task figures and timesheets re-read after an '
      'account switch, with the new token and X-Company', () async {
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 'tkn-a',
        tokenType: 'Bearer',
        userId: 10,
        companyId: 3,
        portal: Portal.employee,
      ).toStorage(),
    );
    final server = _Server();
    final container = ProviderContainer(
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
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);

    // Keep the providers alive, as a mounted Dashboard/Timesheets screen does.
    final subs = [
      container.listen(employeeDashboardSummaryProvider, (_, _) {}),
      container.listen(employeeTaskStatsProvider, (_, _) {}),
      container.listen(employeeTimesheetSummaryProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await container.read(employeeDashboardSummaryProvider.future);
    await container.read(employeeTaskStatsProvider.future);
    await container.read(employeeTimesheetSummaryProvider.future);
    expect(server.requests, hasLength(3));
    for (final r in server.requests) {
      expect(r.headers['Authorization'], 'Bearer tkn-a');
      expect(r.headers['X-Company'], '3');
    }

    final before = server.requests.length;
    await container
        .read(sessionControllerProvider.notifier)
        .login(email: 'b@test.dev', password: 'x', portal: Portal.employee);
    await container.read(employeeDashboardSummaryProvider.future);
    await container.read(employeeTaskStatsProvider.future);
    await container.read(employeeTimesheetSummaryProvider.future);

    final after = server.requests.skip(before).toList();
    for (final path in [
      '/api/v1/employee/dashboard',
      '/api/v1/employee/tasks',
      '/api/v1/employee/timesheets',
    ]) {
      final hits = after.where((r) => r.uri.path == path).toList();
      expect(hits, isNotEmpty, reason: '$path was not re-read for account B');
      expect(hits.last.headers['Authorization'], 'Bearer tkn-b');
      expect(hits.last.headers['X-Company'], '4');
    }
  });

  test('dashboard: myMinutes is the total, not minutes past the hour', () {
    // Live 2026-11-17: myHours 160, myMinutes 9600 (= 160 h). Values here
    // are the observed hours; the money fields are invented.
    final live = EmployeeDashboardSummary.fromJson({
      'myTasks': 1,
      'myHours': 160,
      'myMinutes': 9600,
      'totalEarned': 1,
      'paidSalary': 0,
      'unpaidSalary': 1,
    });
    expect(live.loggedMinutes, 9600);
    // A remainder-style answer still reads correctly.
    final split = EmployeeDashboardSummary.fromJson({
      'myTasks': 0,
      'myHours': 2,
      'myMinutes': 30,
      'totalEarned': 0,
      'paidSalary': 0,
      'unpaidSalary': 0,
    });
    expect(split.loggedMinutes, 150);
  });
}
