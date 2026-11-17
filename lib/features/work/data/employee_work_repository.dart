import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';

/// Live (2026-11-17, both QA accounts): `myMinutes` is the **total** in
/// minutes (9600 with `myHours` 160, equal to the timesheets'
/// `stats.total_minutes`), not the minutes past the hour. Adding both
/// doubled the hours. A remainder (< 60) is still accepted: it is always
/// below `myHours * 60` unless there are no whole hours, where the two
/// readings agree.
int _dashboardMinutes(int hours, int minutes) =>
    minutes >= hours * 60 ? minutes : hours * 60 + minutes;

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
      loggedMinutes: _dashboardMinutes(n('myHours'), n('myMinutes')),
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

  /// `stats` of `GET /employee/tasks`; with [assignedTo], of the
  /// signed-in user's tasks (`assigned_to`). The collection says `stats`
  /// ignores `status` only, so it follows `assigned_to`.
  Future<TaskStats> taskStats({int? assignedTo}) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/employee/tasks',
        query: {'per_page': 1, 'month': 'all', 'assigned_to': ?assignedTo},
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
employeeDashboardSummaryProvider = FutureProvider.autoDispose((ref) {
  watchSessionScope(ref);
  return ref.watch(employeeWorkRepositoryProvider).dashboard();
});

final FutureProvider<TaskStats> employeeTaskStatsProvider =
    FutureProvider.autoDispose((ref) {
      watchSessionScope(ref);
      return ref.watch(employeeWorkRepositoryProvider).taskStats();
    });

/// Task figures for the Tasks screen's scope, keyed to the account and
/// company like the rows.
final FutureProviderFamily<TaskStats, TaskScope> scopedTaskStatsProvider =
    FutureProvider.autoDispose.family<TaskStats, TaskScope>((ref, scope) {
      ref.watch(
        sessionControllerProvider.select(
          (s) => (s.value?.userId, s.value?.companyId),
        ),
      );
      final me = scope == TaskScope.mine ? myUserId(ref) : null;
      return ref
          .watch(employeeWorkRepositoryProvider)
          .taskStats(assignedTo: me);
    });

final FutureProvider<TimesheetSummary> employeeTimesheetSummaryProvider =
    FutureProvider.autoDispose((ref) {
      watchSessionScope(ref);
      return ref.watch(employeeWorkRepositoryProvider).timesheets();
    });
