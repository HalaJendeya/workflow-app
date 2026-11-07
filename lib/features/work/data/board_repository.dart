import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';

/// Task status values the backend uses. The collection names three
/// different sets (see the backend gap report):
///
/// * list filter and `stats.by_status`: backlog, todo, pending,
///   in_progress, in_review, completed;
/// * kanban update-status: backlog, todo, in_progress, in_review,
///   completed;
/// * task create/update: backlog, todo, in_progress, waiting_review, done.
///
/// Rows are read with the list/stats set. Values outside it stay [other]
/// and keep their raw text, so nothing is silently renamed.
enum ApiTaskStatus {
  backlog,
  todo,
  pending,
  inProgress,
  inReview,
  completed,
  other,
}

ApiTaskStatus apiTaskStatus(Object? v) => switch (v) {
  'backlog' => ApiTaskStatus.backlog,
  'todo' => ApiTaskStatus.todo,
  'pending' => ApiTaskStatus.pending,
  'in_progress' => ApiTaskStatus.inProgress,
  'in_review' => ApiTaskStatus.inReview,
  'completed' => ApiTaskStatus.completed,
  _ => ApiTaskStatus.other,
};

/// Statuses `POST /employee/kanban/update-status` accepts, in board order.
const List<ApiTaskStatus> kanbanStatuses = [
  ApiTaskStatus.backlog,
  ApiTaskStatus.todo,
  ApiTaskStatus.inProgress,
  ApiTaskStatus.inReview,
  ApiTaskStatus.completed,
];

String kanbanStatusParam(ApiTaskStatus s) => switch (s) {
  ApiTaskStatus.backlog => 'backlog',
  ApiTaskStatus.todo => 'todo',
  ApiTaskStatus.inProgress => 'in_progress',
  ApiTaskStatus.inReview => 'in_review',
  ApiTaskStatus.completed => 'completed',
  _ => throw ArgumentError.value(s, 'status', 'Not a kanban status'),
};

TaskPriority? _priority(Object? v) => switch (v) {
  'low' => TaskPriority.low,
  'medium' => TaskPriority.medium,
  'high' => TaskPriority.high,
  'urgent' => TaskPriority.urgent,
  _ => null,
};

String? _label(Object? v, String key) => v is Json ? v[key] as String? : null;

/// `HH:mm[:ss]` on [day]; null when absent or malformed.
DateTime? _at(DateTime? day, Object? time) {
  if (day == null || time is! String) return null;
  final p = time.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// A task row from the employee task, kanban and backlog routes.
///
/// The collection gives no row example. Field names come from the task
/// create/update rules (`title`, `status`, `priority`, `story_points`,
/// `task_date`, `start_time`, `end_time`), the documented row relations
/// (`assignee`, `project`, `sprint`, `can {update, delete}`) and the task
/// rows of the "Get Timesheet Details" example. Only `id` and `title` are
/// required; everything else is optional. The employee role never
/// receives `cost` or `currency`, so none is read.
class ApiTask {
  const new({
    required this.id,
    required this.title,
    required this.status,
    required this.rawStatus,
    this.priority,
    this.storyPoints,
    this.taskDate,
    this.start,
    this.end,
    this.assigneeName,
    this.projectTitle,
    this.sprintName,
    this.canUpdate,
  });

  factory fromJson(Json j) {
    final day = asDate(j['task_date']);
    final can = j['can'];
    return ApiTask(
      id: asInt(j['id']) ?? missingField('id'),
      title: j['title'] is String
          ? j['title'] as String
          : missingField('title'),
      status: apiTaskStatus(j['status']),
      rawStatus: '${j['status'] ?? ''}',
      priority: _priority(j['priority']),
      storyPoints: asInt(j['story_points']),
      taskDate: day,
      start: _at(day, j['start_time']),
      end: _at(day, j['end_time']),
      assigneeName: _label(j['assignee'], 'name'),
      projectTitle: _label(j['project'], 'title'),
      sprintName: _label(j['sprint'], 'name'),
      canUpdate: can is Json ? can['update'] as bool? : null,
    );
  }

  final int id;
  final String title;
  final ApiTaskStatus status;
  final String rawStatus;
  final TaskPriority? priority;
  final int? storyPoints;
  final DateTime? taskDate;
  final DateTime? start;
  final DateTime? end;
  final String? assigneeName;
  final String? projectTitle;
  final String? sprintName;

  /// `can.update`; null when the row does not say.
  final bool? canUpdate;

  Duration? get duration =>
      start != null && end != null ? end!.difference(start!) : null;

  String get initials => (assigneeName ?? '')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

typedef BoardProject = ({int id, String title});

/// A sprint as the planning and board routes return it.
class ApiSprint {
  const new({
    required this.id,
    required this.name,
    required this.status,
    this.goal,
    this.startDate,
    this.endDate,
    this.taskCount,
    this.pointsTotal,
    this.pointsDone,
  });

  factory fromJson(Json j) {
    final s = j['stats'];
    final stats = s is Json ? s : const <String, dynamic>{};
    return ApiSprint(
      id: asInt(j['id']) ?? missingField('sprint.id'),
      name: (j['name'] as String?) ?? '#${j['id']}',
      status: (j['status'] as String?) ?? '',
      goal: j['goal'] as String?,
      startDate: asDate(j['start_date']),
      endDate: asDate(j['end_date']),
      taskCount: asInt(stats['task_count']),
      pointsTotal: asInt(stats['points_total']),
      pointsDone: asInt(stats['points_done']),
    );
  }

  final int id;
  final String name;
  final String status;
  final String? goal;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? taskCount;
  final int? pointsTotal;
  final int? pointsDone;
}

List<BoardProject> _projects(Object? v) => [
  if (v is List)
    for (final p in v.whereType<Json>())
      if (asInt(p['id']) case final id?)
        (id: id, title: (p['title'] as String?) ?? '#$id'),
];

int? _selected(Object? v) => v is Json ? asInt(v['id']) : null;

/// `GET /employee/kanban`: `{projects, selected_project, sprint, tasks,
/// stats {points_total, points_done, percent_done, by_status, days_remaining,
/// members}, burndown, velocity}` (collection note 2026-10-27, live
/// 2026-11-07).
class KanbanBoard {
  const new({
    required this.projects,
    required this.selectedProjectId,
    required this.sprint,
    required this.tasks,
    required this.byStatus,
    this.pointsTotal,
    this.pointsDone,
    this.percentDone,
    this.daysRemaining,
    this.memberCount,
  });

  factory fromJson(Json d) {
    final s = d['stats'];
    final stats = s is Json ? s : const <String, dynamic>{};
    final by = stats['by_status'];
    final sprint = d['sprint'];
    final tasks = d['tasks'];
    final members = stats['members'];
    return KanbanBoard(
      projects: _projects(d['projects']),
      selectedProjectId: _selected(d['selected_project']),
      sprint: sprint is Json ? ApiSprint.fromJson(sprint) : null,
      tasks: [
        if (tasks is List) ...tasks.whereType<Json>().map(ApiTask.fromJson),
      ],
      byStatus: {
        if (by is Json)
          for (final e in by.entries) apiTaskStatus(e.key): asInt(e.value) ?? 0,
      },
      pointsTotal: asInt(stats['points_total']),
      pointsDone: asInt(stats['points_done']),
      percentDone: asInt(stats['percent_done']),
      daysRemaining: asInt(stats['days_remaining']),
      memberCount: members is List ? members.length : null,
    );
  }

  final List<BoardProject> projects;
  final int? selectedProjectId;

  /// Null when the project has no current sprint.
  final ApiSprint? sprint;
  final List<ApiTask> tasks;

  /// Whole-sprint counts per column, independent of the `scope` filter.
  final Map<ApiTaskStatus, int> byStatus;
  final int? pointsTotal;
  final int? pointsDone;
  final int? percentDone;
  final int? daysRemaining;
  final int? memberCount;
}

/// `GET /employee/sprints`: `{projects, selected_project, sprints[{…,
/// stats}], backlog {data, current_page, last_page, per_page, total},
/// backlog_stats {count, points}}`.
class SprintPlanning {
  const new({
    required this.projects,
    required this.selectedProjectId,
    required this.sprints,
    required this.backlog,
    this.backlogCount,
    this.backlogPoints,
  });

  factory fromJson(Json d) {
    final sprints = d['sprints'];
    final backlog = d['backlog'];
    final bs = d['backlog_stats'];
    return SprintPlanning(
      projects: _projects(d['projects']),
      selectedProjectId: _selected(d['selected_project']),
      sprints: [
        if (sprints is List)
          ...sprints.whereType<Json>().map(ApiSprint.fromJson),
      ],
      backlog: backlog is Json
          ? ApiPage.parse(backlog, ApiTask.fromJson)
          : missingField('backlog'),
      backlogCount: bs is Json ? asInt(bs['count']) : null,
      backlogPoints: bs is Json ? asInt(bs['points']) : null,
    );
  }

  final List<BoardProject> projects;
  final int? selectedProjectId;
  final List<ApiSprint> sprints;
  final ApiPage<ApiTask> backlog;
  final int? backlogCount;
  final int? backlogPoints;
}

/// Employee sprint board and backlog. The only write is moving a task
/// between kanban columns (`kanban.manage_status`); creating sprints has
/// no employee route.
class BoardRepository {
  new(this._client);

  final ApiClient _client;

  Future<KanbanBoard> kanban({int? projectId}) async => KanbanBoard.fromJson(
    ApiEnvelope.unwrapObject(
      await _client.get(
        '/api/v1/employee/kanban',
        query: {'project_id': ?projectId},
      ),
    ),
  );

  /// The backlog's first page only: the collection documents no query
  /// parameter for its other pages.
  Future<SprintPlanning> planning({int? projectId}) async =>
      SprintPlanning.fromJson(
        ApiEnvelope.unwrapObject(
          await _client.get(
            '/api/v1/employee/sprints',
            query: {'project_id': ?projectId},
          ),
        ),
      );

  Future<void> updateStatus(int taskId, ApiTaskStatus status) async {
    ApiEnvelope.unwrapData(
      await _client.post(
        '/api/v1/employee/kanban/update-status',
        body: {'task_id': taskId, 'status': kanbanStatusParam(status)},
      ),
    );
  }
}

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.watch(apiClientProvider)),
);

final FutureProviderFamily<KanbanBoard, int?> kanbanProvider = FutureProvider
    .autoDispose
    .family<KanbanBoard, int?>(
      (ref, projectId) =>
          ref.watch(boardRepositoryProvider).kanban(projectId: projectId),
    );

final FutureProviderFamily<SprintPlanning, int?> planningProvider =
    FutureProvider.autoDispose.family<SprintPlanning, int?>(
      (ref, projectId) =>
          ref.watch(boardRepositoryProvider).planning(projectId: projectId),
    );
