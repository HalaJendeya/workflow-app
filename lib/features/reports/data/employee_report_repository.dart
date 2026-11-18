import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';

/// Which period the report covers. The route takes `year` (+ `month`) or a
/// `from`/`to` range; the app offers a calendar month and a whole year.
enum ReportSpan { month, year }

/// One request of `GET /employee/report`: [span] of the month or year
/// [anchor] falls in, and the page of the task list.
@immutable
class ReportQuery {
  const new({required this.span, required this.anchor, this.page = 1});

  final ReportSpan span;
  final DateTime anchor;
  final int page;

  /// `year` and `month` (month only for a month), the task page and size.
  /// No `employee_id`, `user_id` or `company_id`: the route refuses them
  /// (422) and always reports the caller.
  Json get params => {
    'year': anchor.year,
    if (span == ReportSpan.month) 'month': anchor.month,
    'page': page,
    'per_page': ReportQuery.perPage,
  };

  static const perPage = 10;

  ReportQuery copyWith({ReportSpan? span, DateTime? anchor, int? page}) =>
      ReportQuery(
        span: span ?? this.span,
        anchor: anchor ?? this.anchor,
        page: page ?? this.page,
      );

  @override
  bool operator ==(Object other) =>
      other is ReportQuery &&
      other.span == span &&
      other.anchor.year == anchor.year &&
      (span == ReportSpan.year || other.anchor.month == anchor.month) &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
    span,
    anchor.year,
    span == ReportSpan.month ? anchor.month : 0,
    page,
  );
}

/// The six task statuses the report counts (`tasks.by_status`).
const reportStatuses = [
  'backlog',
  'todo',
  'pending',
  'in_progress',
  'in_review',
  'completed',
];

class ReportProject {
  const new({
    required this.id,
    required this.title,
    required this.status,
    required this.associations,
    required this.tasks,
    required this.completedTasks,
  });

  factory fromJson(Json j) {
    final a = j['association_types'];
    return ReportProject(
      id: asInt(j['id']) ?? missingField('projects.id'),
      title: (j['title'] as String?) ?? '#${j['id']}',
      status: (j['status'] as String?) ?? '',
      associations: [
        if (a is List)
          for (final x in a)
            if (x is String) x,
      ],
      tasks: asInt(j['tasks_count']) ?? 0,
      completedTasks: asInt(j['completed_tasks_count']) ?? 0,
    );
  }

  final int id;
  final String title;
  final String status;

  /// `member`, `leader` and/or `assignee`.
  final List<String> associations;
  final int tasks;
  final int completedTasks;
}

class ReportTask {
  const new({
    required this.id,
    required this.title,
    required this.status,
    this.priority,
    this.taskDate,
    this.projectTitle,
  });

  factory fromJson(Json j) {
    final p = j['project'];
    return ReportTask(
      id: asInt(j['id']) ?? missingField('tasks.items.id'),
      title: (j['title'] as String?) ?? '#${j['id']}',
      status: (j['status'] as String?) ?? '',
      priority: j['priority'] as String?,
      taskDate: asDate(j['task_date']),
      projectTitle: p is Json ? p['title'] as String? : null,
    );
  }

  final int id;
  final String title;
  final String status;
  final String? priority;
  final DateTime? taskDate;
  final String? projectTitle;
}

class ReportTimesheet {
  const new({
    required this.id,
    required this.month,
    required this.minutes,
    required this.status,
    required this.earnings,
  });

  factory fromJson(Json j) => ReportTimesheet(
    id: asInt(j['id']) ?? missingField('timesheets.items.id'),
    month: (j['month'] as String?) ?? '',
    minutes: asInt(j['minutes']) ?? 0,
    status: (j['status'] as String?) ?? '',
    earnings: asDouble(j['earnings']) ?? 0,
  );

  final int id;
  final String month;
  final int minutes;
  final String status;
  final double earnings;
}

/// A meeting row: exactly the documented keys (no code, room or password).
class ReportMeeting {
  const new({
    required this.id,
    required this.title,
    required this.status,
    required this.attended,
    this.invitationStatus,
    this.at,
  });

  factory fromJson(Json j) => ReportMeeting(
    id: asInt(j['id']) ?? missingField('meetings.id'),
    title: (j['title'] as String?) ?? '#${j['id']}',
    status: (j['status'] as String?) ?? '',
    attended: j['attended'] == true,
    invitationStatus: j['invitation_status'] as String?,
    at: asDate(j['started_at']) ?? asDate(j['scheduled_at']),
  );

  final int id;
  final String title;
  final String status;
  final bool attended;
  final String? invitationStatus;

  /// When it started, else when it is scheduled.
  final DateTime? at;
}

/// Earnings from `timesheets.total` (`summary.earnings`), in the
/// employee's currency (`null` when the company has none).
typedef ReportEarnings = ({
  double total,
  double approved,
  double pending,
  String? code,
  String? symbol,
});

/// `GET /employee/report` (`employee_reports.view_own`): the caller's own
/// work for a period. Every section is required by the collection's test;
/// a missing one is an invalid response, never an empty report.
/// `summary.task_completion_rate` is not read: its unit (0–1 or 0–100) is
/// undocumented, and completed/total is shown from the counts instead.
class EmployeeReport {
  const new({
    required this.from,
    required this.to,
    required this.projects,
    required this.byAssociation,
    required this.byStatus,
    required this.tasks,
    required this.workingMinutes,
    required this.meetingsCount,
    required this.meetingsAttended,
    required this.earnings,
    required this.timesheets,
    required this.meetings,
  });

  factory fromJson(Json d) {
    Json obj(Object? v, String name) => v is Json ? v : missingField(name);
    List<Json> list(Object? v, String name) =>
        v is List ? v.whereType<Json>().toList() : missingField(name);
    final period = obj(d['period'], 'period');
    final s = obj(d['summary'], 'summary');
    final tasks = obj(d['tasks'], 'tasks');
    final by = obj(tasks['by_status'], 'tasks.by_status');
    final pag = obj(tasks['pagination'], 'tasks.pagination');
    final ts = obj(d['timesheets'], 'timesheets');
    final earn = obj(s['earnings'], 'summary.earnings');
    final cur = earn['currency'];
    final assoc = s['projects_by_association'];
    int n(Json m, String k, String where) =>
        asInt(m[k]) ?? missingField('$where.$k');
    return EmployeeReport(
      from: asDate(period['from']) ?? missingField('period.from'),
      to: asDate(period['to']) ?? missingField('period.to'),
      projects: [
        for (final p in list(d['projects'], 'projects'))
          ReportProject.fromJson(p),
      ],
      byAssociation: {
        if (assoc is Json)
          for (final e in assoc.entries) e.key: asInt(e.value) ?? 0,
      },
      byStatus: {for (final k in reportStatuses) k: asInt(by[k]) ?? 0},
      tasks: ApiPage(
        items: [
          for (final t in list(tasks['items'], 'tasks.items'))
            ReportTask.fromJson(t),
        ],
        currentPage: n(pag, 'current_page', 'tasks.pagination'),
        lastPage: n(pag, 'last_page', 'tasks.pagination'),
        perPage: n(pag, 'per_page', 'tasks.pagination'),
        total: n(pag, 'total', 'tasks.pagination'),
      ),
      workingMinutes: n(s, 'working_minutes', 'summary'),
      meetingsCount: n(s, 'meetings_count', 'summary'),
      meetingsAttended: n(s, 'meetings_attended', 'summary'),
      earnings: (
        total: asDouble(earn['total']) ?? 0,
        approved: asDouble(earn['approved']) ?? 0,
        pending: asDouble(earn['pending']) ?? 0,
        code: cur is Json ? cur['code'] as String? : null,
        symbol: cur is Json ? cur['symbol'] as String? : null,
      ),
      timesheets: [
        for (final t in list(ts['items'], 'timesheets.items'))
          ReportTimesheet.fromJson(t),
      ],
      meetings: [
        for (final m in list(d['meetings'], 'meetings'))
          ReportMeeting.fromJson(m),
      ],
    );
  }

  final DateTime from;
  final DateTime to;
  final List<ReportProject> projects;

  /// Projects per association (`member`, `leader`, `assignee`).
  final Map<String, int> byAssociation;

  /// Tasks dated in the period per status (all six keys).
  final Map<String, int> byStatus;

  /// The period's tasks, one page at a time.
  final ApiPage<ReportTask> tasks;
  final int workingMinutes;
  final int meetingsCount;
  final int meetingsAttended;
  final ReportEarnings earnings;
  final List<ReportTimesheet> timesheets;
  final List<ReportMeeting> meetings;

  int get taskCount => byStatus.values.fold(0, (a, b) => a + b);
  int get completedTasks => byStatus['completed'] ?? 0;
}

class EmployeeReportRepository {
  new(this._client);

  final ApiClient _client;

  Future<EmployeeReport> report(ReportQuery q) async => EmployeeReport.fromJson(
    ApiEnvelope.unwrapObject(
      await _client.get('/api/v1/employee/report', query: q.params),
    ),
  );
}

final employeeReportRepositoryProvider = Provider<EmployeeReportRepository>(
  (ref) => EmployeeReportRepository(ref.watch(apiClientProvider)),
);

/// Keyed to the account and company (the report is the caller's own).
final FutureProviderFamily<EmployeeReport, ReportQuery> employeeReportProvider =
    FutureProvider.autoDispose.family<EmployeeReport, ReportQuery>((ref, q) {
      watchSessionScope(ref);
      return ref.watch(employeeReportRepositoryProvider).report(q);
    });
