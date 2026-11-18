import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';

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

TimesheetStatus? timesheetStatusOf(Object? v) => switch (v) {
  'approved' => TimesheetStatus.approved,
  'pending' => TimesheetStatus.pending,
  'rejected' => TimesheetStatus.rejected,
  _ => null,
};

/// A row of `GET /employee/timesheets`. The collection names the row's
/// `hours_minutes`, `payment_type`, `rate`, `total`, `currency` and `can`;
/// the other keys (`id, date, month, user, company, status`) were read live
/// on 2026-11-17/18. `hours_minutes` is the month's **total minutes** (live:
/// 9600 with `stats.total_minutes` 9600, i.e. 160 h). `can` is not read:
/// employees may not approve or reject (Permission Boundary, 403).
class ApiTimesheet {
  const new({
    required this.id,
    required this.month,
    required this.minutes,
    required this.total,
    required this.rawStatus,
    this.date,
    this.userName,
    this.companyName,
    this.paymentType,
    this.rate,
    this.currencyCode,
    this.currencySymbol,
  });

  factory fromJson(Json j) {
    final user = j['user'];
    final company = j['company'];
    final currency = j['currency'];
    return ApiTimesheet(
      id: asInt(j['id']) ?? missingField('id'),
      month: (j['month'] as String?) ?? missingField('month'),
      minutes: asInt(j['hours_minutes']) ?? missingField('hours_minutes'),
      total: asDouble(j['total']) ?? missingField('total'),
      rawStatus: (j['status'] as String?) ?? '',
      date: asDate(j['date']),
      userName: user is Json ? user['name'] as String? : null,
      companyName: company is Json ? company['name'] as String? : null,
      paymentType: j['payment_type'] as String?,
      rate: asDouble(j['rate']),
      currencyCode: currency is Json ? currency['code'] as String? : null,
      currencySymbol: currency is Json ? currency['symbol'] as String? : null,
    );
  }

  final int id;

  /// `YYYY-MM`.
  final String month;
  final int minutes;
  final double total;
  final String rawStatus;
  final DateTime? date;
  final String? userName;
  final String? companyName;

  /// `hourly` or `monthly` (live); shown as given otherwise.
  final String? paymentType;
  final double? rate;
  final String? currencyCode;
  final String? currencySymbol;

  TimesheetStatus? get status => timesheetStatusOf(rawStatus);
}

/// One page of timesheet rows and the months the list can be filtered by
/// (`available_months`, `YYYY-MM`, newest first as the server sends them).
class TimesheetRows {
  const new({required this.page, required this.months});

  final ApiPage<ApiTimesheet> page;
  final List<String> months;
}

/// Filters of the timesheet list: `month` (YYYY-MM) and `status`.
typedef TimesheetQuery = ({String? month, TimesheetStatus? status, int page});

/// A task counted in a timesheet (`projects[].tasks[]` of
/// `GET /timesheets/{id}/details`). Per-task `cost` is not read.
class TimesheetTask {
  const new({
    required this.id,
    required this.title,
    required this.rawStatus,
    required this.countedMinutes,
    this.taskDate,
  });

  factory fromJson(Json j) => TimesheetTask(
    id: asInt(j['id']) ?? missingField('tasks.id'),
    title: (j['title'] as String?) ?? '#${j['id']}',
    rawStatus: (j['status'] as String?) ?? '',
    countedMinutes: asInt(j['counted_minutes']) ?? 0,
    taskDate: asDate(j['task_date']),
  );

  final int id;
  final String title;
  final String rawStatus;
  final int countedMinutes;
  final DateTime? taskDate;
}

/// A project group of a timesheet's tasks.
class TimesheetProject {
  const new({
    required this.title,
    required this.countedMinutes,
    required this.tasks,
  });

  factory fromJson(Json j) {
    final tasks = j['tasks'];
    return TimesheetProject(
      title: (j['project_title'] as String?) ?? '#${j['project_id']}',
      countedMinutes: asInt(j['counted_minutes']) ?? 0,
      tasks: [
        if (tasks is List)
          for (final t in tasks.whereType<Json>()) TimesheetTask.fromJson(t),
      ],
    );
  }

  final String title;
  final int countedMinutes;
  final List<TimesheetTask> tasks;
}

/// `GET /employee/timesheets/{id}/details` (documented with an example):
/// the tasks one month is paid from, grouped by project, and whether the
/// stored timesheet still agrees with them (`summary.in_sync`). The caller's
/// own timesheet only; a colleague's answers 403 (seen live 2026-11-18).
class TimesheetBreakdown {
  const new({
    required this.month,
    required this.rawStatus,
    required this.countedMinutes,
    required this.tasksCount,
    required this.inSync,
    required this.projects,
    this.payType,
    this.from,
    this.to,
  });

  factory fromJson(Json d) {
    final ts = d['timesheet'];
    final s = d['summary'];
    final period = d['period'];
    final projects = d['projects'];
    if (ts is! Json) missingField('timesheet');
    if (s is! Json) missingField('summary');
    if (projects is! List) missingField('projects');
    return TimesheetBreakdown(
      month: (ts['month'] as String?) ?? '',
      rawStatus: (ts['status'] as String?) ?? '',
      countedMinutes:
          asInt(s['counted_minutes']) ??
          missingField('summary.counted_minutes'),
      tasksCount:
          asInt(s['tasks_count']) ?? missingField('summary.tasks_count'),
      inSync: s['in_sync'] != false,
      payType: d['pay_type'] as String?,
      from: period is Json ? asDate(period['start']) : null,
      to: period is Json ? asDate(period['end']) : null,
      projects: [
        for (final p in projects.whereType<Json>())
          TimesheetProject.fromJson(p),
      ],
    );
  }

  final String month;
  final String rawStatus;
  final int countedMinutes;
  final int tasksCount;

  /// `false` when the stored timesheet no longer matches its tasks.
  final bool inSync;
  final String? payType;
  final DateTime? from;
  final DateTime? to;
  final List<TimesheetProject> projects;
}

/// Read-only figures and rows for the employee Dashboard, Tasks and
/// Timesheets screens. Employees cannot approve, reject or delete a
/// timesheet (Permission Boundary), so nothing here writes.
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

  /// `GET /employee/timesheets` rows with the documented `month`, `status`
  /// and `page` filters. `status=all` is a 422, so "all" sends none.
  Future<TimesheetRows> timesheetRows(TimesheetQuery q) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/employee/timesheets',
        query: {'page': q.page, 'month': ?q.month, 'status': ?q.status?.name},
      ),
    );
    final data = body['data'];
    if (data is! Json) missingField('data');
    final months = body['available_months'];
    return TimesheetRows(
      page: ApiPage.parse(data, ApiTimesheet.fromJson),
      months: [
        if (months is List)
          for (final m in months)
            if (m is String) m,
      ],
    );
  }

  Future<TimesheetBreakdown> timesheetDetails(int id) async =>
      TimesheetBreakdown.fromJson(
        ApiEnvelope.unwrapObject(
          await _client.get('/api/v1/employee/timesheets/$id/details'),
        ),
      );
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

/// Timesheet rows for the list's filters, keyed to the account and company.
final FutureProviderFamily<TimesheetRows, TimesheetQuery>
apiTimesheetRowsProvider = FutureProvider.autoDispose
    .family<TimesheetRows, TimesheetQuery>((ref, q) {
      watchSessionScope(ref);
      return ref.watch(employeeWorkRepositoryProvider).timesheetRows(q);
    });

final FutureProviderFamily<TimesheetBreakdown, int>
apiTimesheetDetailsProvider = FutureProvider.autoDispose
    .family<TimesheetBreakdown, int>((ref, id) {
      watchSessionScope(ref);
      return ref.watch(employeeWorkRepositoryProvider).timesheetDetails(id);
    });
