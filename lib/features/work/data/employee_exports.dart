import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';

/// The employee's documented CSV exports (collection, "Added
/// 2026-10-27"): the same filters as each list, without paging. Every one
/// leaves pay columns out for an employee (projects: Budget; tasks: Cost
/// and Currency), as the collection states and the live headers confirm.
/// Read-only `GET` routes; nothing is changed on the server.
class EmployeeExportsRepository {
  new(this._client);

  final ApiClient _client;

  static const _base = '/api/v1/employee';

  /// `GET /employee/tasks/export`: [q]'s search, status, priority, project,
  /// sprint and sort over every month; [assignedTo] for My Tasks.
  Future<CsvFile> tasks(TaskQuery q, {int? assignedTo}) => downloadCsv(
    _client,
    '$_base/tasks/export',
    fallbackName: 'tasks.csv',
    query: {
      'month': 'all',
      'assigned_to': ?assignedTo,
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      if (q.status case final s?) 'status': ?taskListStatusParam(s),
      if (q.priority case final p?) 'priority': p.name,
      'project_id': ?q.projectId,
      'sprint_id': ?q.sprintId,
      'sort': ?q.sort.param,
    },
  );

  /// `GET /employee/timesheets/export`: the caller's own timesheets
  /// (`month` as YYYY-MM, `status` approved/pending/rejected).
  Future<CsvFile> timesheets({String? month, String? status}) => downloadCsv(
    _client,
    '$_base/timesheets/export',
    fallbackName: 'timesheets.csv',
    query: {'month': ?month, 'status': ?status},
  );

  /// `GET /employee/projects/export` with the list's search and status.
  Future<CsvFile> projects({String search = '', ApiProjectStatus? status}) =>
      downloadCsv(
        _client,
        '$_base/projects/export',
        fallbackName: 'projects.csv',
        query: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status case final s? when s != ApiProjectStatus.other)
            'status': s == ApiProjectStatus.inProgress ? 'in_progress' : s.name,
        },
      );

  /// `GET /employee/sprints/backlog/export` for [projectId] (the server
  /// picks the first plannable project without one), narrowed by the
  /// backlog's [search] (documented `search`, partial text match).
  Future<CsvFile> backlog({int? projectId, String search = ''}) => downloadCsv(
    _client,
    '$_base/sprints/backlog/export',
    fallbackName: 'backlog.csv',
    query: {
      'project_id': ?projectId,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    },
  );
}

final employeeExportsProvider = Provider<EmployeeExportsRepository>(
  (ref) => EmployeeExportsRepository(ref.watch(apiClientProvider)),
);
