import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// `GET /api/v1/employee/dashboard` → `data {myTasks, myHours, myMinutes,
/// totalEarned, paidSalary, unpaidSalary}`, as returned by the live server.
/// The collection's description lists other keys (`wallet_balances`,
/// `latest_projects`, `monthly`, …) that the server does not return to an
/// employee, so they are not read.
class EmployeeDashboardSummary {
  const new({
    required this.tasks,
    required this.loggedMinutes,
    required this.earned,
    required this.paid,
    required this.unpaid,
  });

  factory fromJson(Json j) {
    int n(String k) => asInt(j[k]) ?? missingField(k);
    double d(String k) => asDouble(j[k]) ?? missingField(k);
    return EmployeeDashboardSummary(
      tasks: n('myTasks'),
      loggedMinutes: n('myHours') * 60 + n('myMinutes'),
      earned: d('totalEarned'),
      paid: d('paidSalary'),
      unpaid: d('unpaidSalary'),
    );
  }

  final int tasks;
  final int loggedMinutes;

  /// Amounts in the employee's own currency, which this route does not name.
  final double earned;
  final double paid;
  final double unpaid;
}

/// `stats` of `GET /employee/tasks`: `{total, by_status{…}, active,
/// logged_minutes}`. Live `by_status` keys: backlog, todo, pending,
/// in_progress, in_review, completed.
class TaskStats {
  const new({
    required this.total,
    required this.active,
    required this.loggedMinutes,
    required this.byStatus,
  });

  final int total;
  final int active;
  final int loggedMinutes;
  final Map<String, int> byStatus;
}

/// Per-currency row of `totals[]` on `GET /employee/timesheets`.
typedef TimesheetMoney = ({String code, String symbol, double approved});

/// `stats {count, approved, pending, rejected, total_minutes}` and the
/// approved amount per currency.
class TimesheetSummary {
  const new({
    required this.count,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.totalMinutes,
    required this.money,
  });

  final int count;
  final int approved;
  final int pending;
  final int rejected;
  final int totalMinutes;
  final List<TimesheetMoney> money;
}

/// Read-only figures for the employee Dashboard, Tasks and Timesheets
/// screens. Task and timesheet rows are not mapped: the collection does not
/// document their fields and the test account has none to confirm them.
class EmployeeWorkRepository {
  new(this._client);

  final ApiClient _client;

  Future<EmployeeDashboardSummary> dashboard() async =>
      EmployeeDashboardSummary.fromJson(
        ApiEnvelope.unwrapObject(
          await _client.get('/api/v1/employee/dashboard'),
        ),
      );

  Future<TaskStats> taskStats() async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/employee/tasks',
        query: {'per_page': 1, 'month': 'all'},
      ),
    );
    final s = body['stats'];
    if (s is! Json) missingField('stats');
    final by = s['by_status'];
    return TaskStats(
      total: asInt(s['total']) ?? missingField('stats.total'),
      active: asInt(s['active']) ?? missingField('stats.active'),
      loggedMinutes:
          asInt(s['logged_minutes']) ?? missingField('stats.logged_minutes'),
      byStatus: {
        if (by is Json)
          for (final e in by.entries) e.key: asInt(e.value) ?? 0,
      },
    );
  }

  Future<TimesheetSummary> timesheets() async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get('/api/v1/employee/timesheets', query: {'per_page': 1}),
    );
    final s = body['stats'];
    if (s is! Json) missingField('stats');
    int n(String k) => asInt(s[k]) ?? missingField('stats.$k');
    final totals = body['totals'];
    return TimesheetSummary(
      count: n('count'),
      approved: n('approved'),
      pending: n('pending'),
      rejected: n('rejected'),
      totalMinutes: n('total_minutes'),
      money: [
        if (totals is List)
          for (final t in totals.whereType<Json>())
            (
              code: (t['code'] as String?) ?? '',
              symbol: (t['symbol'] as String?) ?? (t['code'] as String?) ?? '',
              approved: asDouble(t['approved']) ?? 0,
            ),
      ],
    );
  }
}

final employeeWorkRepositoryProvider = Provider<EmployeeWorkRepository>(
  (ref) => EmployeeWorkRepository(ref.watch(apiClientProvider)),
);

final FutureProvider<EmployeeDashboardSummary>
employeeDashboardSummaryProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(employeeWorkRepositoryProvider).dashboard(),
);

final FutureProvider<TaskStats> employeeTaskStatsProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(employeeWorkRepositoryProvider).taskStats(),
    );

final FutureProvider<TimesheetSummary> employeeTimesheetSummaryProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(employeeWorkRepositoryProvider).timesheets(),
    );
