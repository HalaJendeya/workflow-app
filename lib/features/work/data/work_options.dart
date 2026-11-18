import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';

/// A row of `GET /employee/projects/options`: documented as
/// `[{id, title, company_id, leader_id, client, currency}]`, never with a
/// budget. Only `id`, `title` and `leader_id` are read.
class ProjectOption {
  const new({required this.id, required this.title, this.leaderId});

  factory fromJson(Json j) => ProjectOption(
    id: asInt(j['id']) ?? missingField('id'),
    title: (j['title'] as String?) ?? '#${j['id']}',
    leaderId: asInt(j['leader_id']),
  );

  final int id;
  final String title;

  /// `users.id` of the project's leader (the `leader_id` filter of the
  /// project list takes the login's `user_id`).
  final int? leaderId;
}

/// A row of `GET /employee/sprints/options?project_id=`: `[{id, name,
/// status}]` (status `planned`, `active` or `completed`).
class SprintOption {
  const new({required this.id, required this.name, required this.status});

  factory fromJson(Json j) => SprintOption(
    id: asInt(j['id']) ?? missingField('id'),
    name: (j['name'] as String?) ?? '#${j['id']}',
    status: (j['status'] as String?) ?? '',
  );

  final int id;
  final String name;
  final String status;
}

/// A row of `GET /employee/employees/options`: active employees of the
/// active company as `[{user_id, name, image}]`, no pay fields. `user_id`
/// is what `tasks.assigned_to` takes.
class PersonOption {
  const new({required this.userId, required this.name});

  factory fromJson(Json j) => PersonOption(
    userId: asInt(j['user_id']) ?? missingField('user_id'),
    name: (j['name'] as String?) ?? '#${j['user_id']}',
  );

  final int userId;
  final String name;
}

/// Form helpers the employee role may read. All are unpaginated lists and
/// are pinned by the server to the caller's company (no `company_id` is
/// sent; `X-Company` comes from the session).
class WorkOptionsRepository {
  new(this._client);

  final ApiClient _client;

  List<T> _list<T>(Object? data, T Function(Json) row) {
    if (data is! List) missingField('data');
    return [for (final j in data.whereType<Json>()) row(j)];
  }

  /// [led]: only projects the caller leads (`led=1`).
  Future<List<ProjectOption>> projects({bool led = false}) async => _list(
    ApiEnvelope.unwrapData(
      await _client.get(
        '/api/v1/employee/projects/options',
        query: {if (led) 'led': 1},
      ),
    ),
    ProjectOption.fromJson,
  );

  Future<List<SprintOption>> sprints(int projectId) async => _list(
    ApiEnvelope.unwrapData(
      await _client.get(
        '/api/v1/employee/sprints/options',
        query: {'project_id': projectId},
      ),
    ),
    SprintOption.fromJson,
  );

  /// Every active employee of the company. Not used for assigning: a lead
  /// may assign only members of the task's project ([projectMembers]).
  Future<List<PersonOption>> people() async => _list(
    ApiEnvelope.unwrapData(
      await _client.get('/api/v1/employee/employees/options'),
    ),
    PersonOption.fromJson,
  );

  /// `GET /employee/tasks/project-employees/{project}` ("List Task Project
  /// Employees", `tasks.view`): the people a task on [projectId] may be
  /// assigned to. The collection asserts only that `data` is a list; the
  /// rows were read live on 2026-11-18 as `{id, name}`, where `id` is the
  /// `users.id` that `assigned_to` takes (the lead's own row carries the
  /// login's user id). A row without a numeric id is an invalid response.
  Future<List<PersonOption>> projectMembers(int projectId) async => _list(
    ApiEnvelope.unwrapData(
      await _client.get('/api/v1/employee/tasks/project-employees/$projectId'),
    ),
    (j) => PersonOption(
      userId: asInt(j['id']) ?? missingField('id'),
      name: (j['name'] as String?) ?? '#${j['id']}',
    ),
  );
}

final workOptionsRepositoryProvider = Provider<WorkOptionsRepository>(
  (ref) => WorkOptionsRepository(ref.watch(apiClientProvider)),
);

/// Every project the account may see, for filters and pickers.
final FutureProvider<List<ProjectOption>> projectOptionsProvider =
    FutureProvider.autoDispose((ref) {
      watchSessionScope(ref);
      return ref.watch(workOptionsRepositoryProvider).projects();
    });

/// Projects the signed-in user leads: the only ones an employee may create
/// or edit tasks on, and the only boards where `scope=all` is asked for.
/// `led=1` is documented; a row whose `leader_id` names someone else is
/// dropped as well, so a misbehaving filter never widens what is offered.
final FutureProvider<List<ProjectOption>> ledProjectsProvider =
    FutureProvider.autoDispose((ref) async {
      watchSessionScope(ref);
      final me = myUserId(ref);
      final rows = await ref
          .watch(workOptionsRepositoryProvider)
          .projects(led: true);
      return [
        for (final p in rows)
          if (p.leaderId == null || p.leaderId == me) p,
      ];
    });

/// Ids of [ledProjectsProvider]; empty while loading or on failure, so
/// nothing lead-only is offered without the server's word.
final Provider<Set<int>> ledProjectIdsProvider = Provider.autoDispose(
  (ref) => {
    for (final p
        in ref.watch(ledProjectsProvider).value ?? const <ProjectOption>[])
      p.id,
  },
);

final FutureProviderFamily<List<SprintOption>, int> sprintOptionsProvider =
    FutureProvider.autoDispose.family<List<SprintOption>, int>((
      ref,
      projectId,
    ) {
      watchSessionScope(ref);
      return ref.watch(workOptionsRepositoryProvider).sprints(projectId);
    });

/// Who a task on the project may be assigned to (its members). Read only
/// for projects the user leads, the only ones the task form offers.
final FutureProviderFamily<List<PersonOption>, int> projectMembersProvider =
    FutureProvider.autoDispose.family<List<PersonOption>, int>((
      ref,
      projectId,
    ) {
      watchSessionScope(ref);
      return ref.watch(workOptionsRepositoryProvider).projectMembers(projectId);
    });

/// A time of day as `H:i` sends it.
typedef ClockTime = ({int hour, int minute});

String clockParam(ClockTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

int _minutes(ClockTime t) => t.hour * 60 + t.minute;

/// The documented task rules the form checks before sending (the server
/// checks them again): end after start on the same day, at most 4 hours,
/// and an end only with a start.
enum TaskTimeProblem { endWithoutStart, endNotAfterStart, overFourHours }

TaskTimeProblem? taskTimeProblem(ClockTime? start, ClockTime? end) {
  if (end == null) return null;
  if (start == null) return TaskTimeProblem.endWithoutStart;
  final d = _minutes(end) - _minutes(start);
  if (d <= 0) return TaskTimeProblem.endNotAfterStart;
  if (d > 4 * 60) return TaskTimeProblem.overFourHours;
  return null;
}

/// `Y-m-d` with Western digits, whatever the app's locale.
String dateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The fields of `POST /employee/tasks` and `PUT /employee/tasks/{task}`
/// (validation rules in the collection, re-verified 2026-11-12). There is
/// no due date (`task_date` is the planned work day), one assignee
/// (`users.id`) or none, and no cost.
@immutable
class TaskDraft {
  const new({
    required this.projectId,
    required this.title,
    this.taskDate,
    this.sprintId,
    this.assignedTo,
    this.description,
    this.storyPoints,
    this.priority,
    this.status,
    this.start,
    this.end,
  });

  /// The form's starting point for editing [t]. Only what the row says is
  /// filled in; [BoardRepository.updateTask] then sends only changes.
  factory fromTask(ApiTask t) => TaskDraft(
    projectId: t.projectId ?? missingField('project.id'),
    title: t.title,
    taskDate: t.taskDate,
    sprintId: t.sprintId,
    assignedTo: t.assigneeId,
    description: t.description,
    storyPoints: t.storyPoints,
    priority: t.priority,
    status: t.status == ApiTaskStatus.other ? null : t.status,
    start: t.start == null
        ? null
        : (hour: t.start!.hour, minute: t.start!.minute),
    end: t.end == null ? null : (hour: t.end!.hour, minute: t.end!.minute),
  );

  final int projectId;
  final String title;
  final DateTime? taskDate;
  final int? sprintId;
  final int? assignedTo;
  final String? description;
  final int? storyPoints;
  final TaskPriority? priority;
  final ApiTaskStatus? status;
  final ClockTime? start;
  final ClockTime? end;

  Map<String, Object?> _fields() => {
    'project_id': projectId,
    'sprint_id': sprintId,
    'assigned_to': assignedTo,
    'title': title.trim(),
    'description': switch (description?.trim()) {
      final d? when d.isNotEmpty => d,
      _ => null,
    },
    'story_points': storyPoints,
    'priority': priority?.name,
    'status': status == null ? null : taskListStatusParam(status!),
    'task_date': taskDate == null ? null : dateParam(taskDate!),
    'start_time': start == null ? null : clockParam(start!),
    'end_time': end == null ? null : clockParam(end!),
  };

  /// Create body: empty optional fields are left out.
  Map<String, Object?> toCreate() => {
    for (final e in _fields().entries)
      if (e.value != null) e.key: e.value,
  };

  /// Update body: the fields that differ from [original]. A field cleared
  /// in the form is sent as null (the rules mark it nullable). The project
  /// is not changed from the edit form.
  Map<String, Object?> changesFrom(TaskDraft original) {
    final before = original._fields();
    return {
      for (final e in _fields().entries)
        if (e.key != 'project_id' && e.value != before[e.key]) e.key: e.value,
    };
  }
}

/// After a task write: every task list, figure, board and backlog is read
/// again from the server, so no screen keeps the old state.
void invalidateTaskData(WidgetRef ref, {int? taskId}) {
  ref
    ..invalidate(apiTasksProvider)
    ..invalidate(scopedTaskStatsProvider)
    ..invalidate(employeeTaskStatsProvider)
    ..invalidate(employeeDashboardSummaryProvider)
    ..invalidate(kanbanProvider)
    ..invalidate(planningProvider);
  if (taskId != null) ref.invalidate(apiTaskProvider(taskId));
}
