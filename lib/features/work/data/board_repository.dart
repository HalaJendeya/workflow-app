import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';

/// Task status values the backend uses (collection `WorkFlow`, 2026-11-14):
///
/// * list filter, `stats.by_status` and task create/update: backlog, todo,
///   pending, in_progress, in_review, completed (create/update also accept
///   the legacy `waiting_review` → in_review and `done` → completed, stored
///   canonically);
/// * kanban update-status: backlog, todo, in_progress, in_review,
///   completed.
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

int? _id(Object? v) => v is Json ? asInt(v['id']) : null;

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
/// rows of the "Get Timesheet Details" example. `description` is the
/// create/update field; `assignee.id` is the `users.id` that
/// `assigned_to` takes. Only `id` and `title` are required; everything
/// else is optional. The employee role never receives `cost` or
/// `currency`, so none is read.
class ApiTask {
  const new({
    required this.id,
    required this.title,
    required this.status,
    required this.rawStatus,
    this.description,
    this.priority,
    this.storyPoints,
    this.taskDate,
    this.start,
    this.end,
    this.assigneeId,
    this.assigneeName,
    this.projectId,
    this.projectTitle,
    this.sprintId,
    this.sprintName,
    this.canUpdate,
    this.canDelete,
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
      description: switch (j['description']) {
        final String d when d.trim().isNotEmpty => d.trim(),
        _ => null,
      },
      priority: _priority(j['priority']),
      storyPoints: asInt(j['story_points']),
      taskDate: day,
      start: _at(day, j['start_time']),
      end: _at(day, j['end_time']),
      assigneeId: j['assignee'] is Json
          ? asInt((j['assignee'] as Json)['id'])
          : null,
      assigneeName: _label(j['assignee'], 'name'),
      projectId: _id(j['project']),
      projectTitle: _label(j['project'], 'title'),
      sprintId: _id(j['sprint']),
      sprintName: _label(j['sprint'], 'name'),
      canUpdate: can is Json ? can['update'] as bool? : null,
      canDelete: can is Json ? can['delete'] as bool? : null,
    );
  }

  final int id;
  final String title;
  final ApiTaskStatus status;
  final String rawStatus;

  /// Free text the task was created with; null when absent or blank.
  final String? description;
  final TaskPriority? priority;
  final int? storyPoints;
  final DateTime? taskDate;
  final DateTime? start;
  final DateTime? end;

  /// `assignee.id`: a `users.id`, compared with the signed-in user.
  final int? assigneeId;
  final String? assigneeName;

  /// `project.id` / `sprint.id` of the row's relations; null when the
  /// row does not carry them. Used to scope a lead's edit form and to open
  /// related lists, never to guess another id.
  final int? projectId;
  final String? projectTitle;
  final int? sprintId;
  final String? sprintName;

  /// `can.update`; null when the row does not say.
  final bool? canUpdate;

  /// `can.delete`; null when the row does not say.
  final bool? canDelete;

  /// This task with [row]'s `can` where this one does not say. Task
  /// details (`GET /tasks/{id}`) carry no `can`; the list row the user
  /// opened them from does, and the server's 403 stays the authority.
  ApiTask withPermissionsFrom(ApiTask row) =>
      canUpdate != null && canDelete != null
      ? this
      : ApiTask(
          id: id,
          title: title,
          status: status,
          rawStatus: rawStatus,
          description: description,
          priority: priority,
          storyPoints: storyPoints,
          taskDate: taskDate,
          start: start,
          end: end,
          assigneeId: assigneeId,
          assigneeName: assigneeName,
          projectId: projectId,
          projectTitle: projectTitle,
          sprintId: sprintId,
          sprintName: sprintName,
          canUpdate: canUpdate ?? row.canUpdate,
          canDelete: canDelete ?? row.canDelete,
        );

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

  /// Still open (not `completed`) after its last day. The status is a
  /// manual workflow state (Start/Complete Sprint), so the server reports
  /// such a sprint as `active`.
  bool isPastEnd(DateTime now) {
    final end = endDate;
    if (end == null || status == 'completed') return false;
    return DateTime(
      end.year,
      end.month,
      end.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }
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

/// Whose tasks the list shows: the signed-in employee's (`assigned_to`,
/// the default) or every task the backend lets them see (`tasks.view`).
enum TaskScope { mine, team }

/// Documented `sort` values of `GET /employee/tasks` the app offers.
/// [newest] is the route's default (`-created_at`) and is not sent.
enum TaskSort {
  newest(null),
  plannedDate('-task_date'),
  title('title');

  new(this.param);

  final String? param;
}

/// One request of `GET /employee/tasks`: scope, search, the documented
/// filters (`status`, `priority`, `project_id`, `sprint_id`), sort and
/// page. A value object, so equal queries share one provider.
@immutable
class TaskQuery {
  const new({
    this.scope = TaskScope.mine,
    this.search = '',
    this.status,
    this.priority,
    this.page = 1,
    this.projectId,
    this.sprintId,
    this.sort = TaskSort.newest,
    this.perPage = 10,
  });

  final TaskScope scope;
  final String search;
  final ApiTaskStatus? status;
  final TaskPriority? priority;
  final int page;
  final int? projectId;
  final int? sprintId;
  final TaskSort sort;
  final int perPage;

  /// Whether anything narrows the list beyond the scope (empty states).
  bool get filtered =>
      search.trim().isNotEmpty ||
      status != null ||
      priority != null ||
      projectId != null ||
      sprintId != null;

  List<Object?> get _props => [
    scope,
    search,
    status,
    priority,
    page,
    projectId,
    sprintId,
    sort,
    perPage,
  ];

  @override
  bool operator ==(Object other) =>
      other is TaskQuery && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// `status` filter of `GET /employee/tasks`. The collection documents
/// backlog, todo, pending, in_progress, in_review and completed (anything
/// else answers 422); [ApiTaskStatus.other] has no filter value.
String? taskListStatusParam(ApiTaskStatus s) => switch (s) {
  ApiTaskStatus.backlog => 'backlog',
  ApiTaskStatus.todo => 'todo',
  ApiTaskStatus.pending => 'pending',
  ApiTaskStatus.inProgress => 'in_progress',
  ApiTaskStatus.inReview => 'in_review',
  ApiTaskStatus.completed => 'completed',
  ApiTaskStatus.other => null,
};

/// Employee sprint board and backlog. The only write is moving a task
/// between kanban columns (`kanban.manage_status`); creating sprints has
/// no employee route.
class BoardRepository {
  new(this._client);

  final ApiClient _client;

  /// `scope` is documented as `mine | all`: employees (leads included)
  /// get `mine` by default; `all` is for the lead. The app asks for
  /// `all` only on a project the user leads (`ledProjectIdsProvider`);
  /// the server still decides what it returns.
  Future<KanbanBoard> kanban({int? projectId, bool all = false}) async =>
      KanbanBoard.fromJson(
        ApiEnvelope.unwrapObject(
          await _client.get(
            '/api/v1/employee/kanban',
            query: {'project_id': ?projectId, if (all) 'scope': 'all'},
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

  /// `GET /employee/tasks` rows over all months, newest first (the
  /// route's default sort). `stats` is read separately by
  /// `EmployeeWorkRepository.taskStats`.
  ///
  /// With [assignedTo] (My Tasks) the documented `assigned_to` filter is
  /// sent, and every row is still checked: one whose `assignee.id` is not
  /// [assignedTo] — another person's, unassigned, or without an id — is
  /// left out and counted in [TaskList.hidden], never shown as "mine".
  Future<TaskList> tasks(TaskQuery q, {int? assignedTo}) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/employee/tasks',
        query: {
          'month': 'all',
          'page': q.page,
          'per_page': q.perPage,
          'assigned_to': ?assignedTo,
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          if (q.status case final s?) 'status': ?taskListStatusParam(s),
          if (q.priority case final p?) 'priority': p.name,
          'project_id': ?q.projectId,
          'sprint_id': ?q.sprintId,
          'sort': ?q.sort.param,
        },
      ),
    );
    final data = body['data'];
    if (data is! Json) missingField('data');
    final page = ApiPage.parse(data, ApiTask.fromJson);
    if (assignedTo == null) return TaskList(page);
    final mine = [
      for (final t in page.items)
        if (t.assigneeId == assignedTo) t,
    ];
    return TaskList(
      ApiPage(
        items: mine,
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        perPage: page.perPage,
        total: page.total,
      ),
      hidden: page.items.length - mine.length,
    );
  }

  /// `GET /employee/tasks/{task}` (`tasks.view`). The collection gives no
  /// response example. Live (2026-11-17) the task model is nested:
  /// `data {task {…, project_id, sprint_id, assigned_to, assigned_user,
  /// project, sprint}, duration_formatted, …}`, with no `assignee` and no
  /// `can`. It is read as a task row (see [ApiTask]); only the id and name
  /// of `assigned_user` are kept. A flat row is still accepted.
  Future<ApiTask> task(int id) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.get('/api/v1/employee/tasks/$id'),
    );
    final nested = data['task'];
    if (nested is! Json) return ApiTask.fromJson(data);
    final user = nested['assigned_user'];
    final assignedTo = asInt(nested['assigned_to']);
    final projectId = asInt(nested['project_id']);
    final sprintId = asInt(nested['sprint_id']);
    return ApiTask.fromJson({
      ...nested,
      'assignee':
          nested['assignee'] ??
          switch (user) {
            final Json u => {'id': u['id'] ?? assignedTo, 'name': u['name']},
            _ => assignedTo == null ? null : {'id': assignedTo},
          },
      'project':
          nested['project'] ?? (projectId == null ? null : {'id': projectId}),
      'sprint':
          nested['sprint'] ?? (sprintId == null ? null : {'id': sprintId}),
    });
  }

  /// `POST /employee/tasks` (`tasks.create`). Only the project's leader
  /// may create on it (403 otherwise). The documented response is
  /// `data.id` (201); the new task's id is returned.
  Future<int> createTask(TaskDraft draft) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post('/api/v1/employee/tasks', body: draft.toCreate()),
    );
    return asInt(data['id']) ?? missingField('data.id');
  }

  /// `PUT /employee/tasks/{task}` (`tasks.update`, lead only). Sends only
  /// the fields that differ from [original], so a value the form could not
  /// read from the row is never overwritten.
  Future<void> updateTask(int id, TaskDraft draft, TaskDraft original) async {
    final body = draft.changesFrom(original);
    if (body.isEmpty) return;
    ApiEnvelope.unwrapObject(
      await _client.put('/api/v1/employee/tasks/$id', body: body),
    );
  }

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

/// Which board to read: a project (null = the server's default) and
/// whether to ask for the whole team's cards (`scope=all`).
typedef BoardKey = ({int? projectId, bool all});

/// Rebuilds when the signed-in account or its company changes, so data is
/// never served to another account or company.
void watchSessionScope(Ref ref) => ref.watch(
  sessionControllerProvider.select(
    (s) => (s.value?.userId, s.value?.companyId),
  ),
);

final FutureProviderFamily<KanbanBoard, BoardKey> kanbanProvider =
    FutureProvider.autoDispose.family<KanbanBoard, BoardKey>((ref, key) {
      watchSessionScope(ref);
      return ref
          .watch(boardRepositoryProvider)
          .kanban(projectId: key.projectId, all: key.all);
    });

final FutureProviderFamily<SprintPlanning, int?> planningProvider =
    FutureProvider.autoDispose.family<SprintPlanning, int?>((ref, projectId) {
      watchSessionScope(ref);
      return ref.watch(boardRepositoryProvider).planning(projectId: projectId);
    });

/// A page of tasks plus how many rows of it were left out because they
/// could not be confirmed as the signed-in user's.
class TaskList {
  const new(this.page, {this.hidden = 0});

  final ApiPage<ApiTask> page;
  final int hidden;
}

/// The signed-in user's id for My Tasks. Without one there is no "mine"
/// to ask for, so it fails instead of falling back to every task.
int myUserId(Ref ref) {
  final id = ref.watch(
    sessionControllerProvider.select((s) => s.value?.userId),
  );
  if (id == null) {
    throw const ApiException(
      kind: ApiFailureKind.unauthorized,
      message: 'Not signed in.',
    );
  }
  return id;
}

/// Keyed to the account and its company (and, through the query, to the
/// scope): one user's or company's tasks are never served to another.
final FutureProviderFamily<TaskList, TaskQuery> apiTasksProvider =
    FutureProvider.autoDispose.family<TaskList, TaskQuery>((ref, q) {
      watchSessionScope(ref);
      final me = q.scope == TaskScope.mine ? myUserId(ref) : null;
      return ref.watch(boardRepositoryProvider).tasks(q, assignedTo: me);
    });

/// One task, fetched fresh when its details open; keyed like the list.
final FutureProviderFamily<ApiTask, int> apiTaskProvider = FutureProvider
    .autoDispose
    .family<ApiTask, int>((ref, id) {
      watchSessionScope(ref);
      return ref.watch(boardRepositoryProvider).task(id);
    });
