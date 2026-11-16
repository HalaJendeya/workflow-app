import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';

enum TaskStatus { backlog, todo, inProgress, completed }

enum TaskPriority { low, medium, high, urgent }

/// Presentation model shared by Tasks Management (729:24059) and the
/// Sprint & Backlog kanban (729:24447).
class WorkTask implements Identified {
  const new({
    required this.id,
    required this.code,
    required this.title,
    required this.project,
    required this.sprint,
    required this.assignee,
    required this.status,
    required this.priority,
    required this.points,
    required this.start,
    required this.end,
    required this.amount,
    this.description,
    this.due,
    this.subtasksDone = 0,
    this.subtasksTotal = 0,
  });

  @override
  final String id;
  final String code;
  final String title;
  final String project;
  final String sprint;
  final String assignee;
  final TaskStatus status;
  final TaskPriority priority;
  final int points;
  final DateTime start;
  final DateTime end;
  final double amount;

  /// What the task asks for; null when none was written.
  final String? description;

  /// Deadline, when the task has one.
  final DateTime? due;
  final int subtasksDone;
  final int subtasksTotal;

  Duration get duration => end.difference(start);

  double get progress => subtasksTotal == 0 ? 0 : subtasksDone / subtasksTotal;

  String get initials => assignee
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  WorkTask copyWith({
    TaskStatus? status,
    String? title,
    String? project,
    String? assignee,
    TaskPriority? priority,
    int? points,
    DateTime? start,
    DateTime? end,
    double? amount,
  }) => WorkTask(
    id: id,
    code: code,
    title: title ?? this.title,
    project: project ?? this.project,
    sprint: sprint,
    assignee: assignee ?? this.assignee,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    points: points ?? this.points,
    start: start ?? this.start,
    end: end ?? this.end,
    amount: amount ?? this.amount,
    description: description,
    due: due,
    subtasksDone: subtasksDone,
    subtasksTotal: subtasksTotal,
  );
}

enum TimesheetStatus { approved, pending, rejected }

/// Presentation model for "Timesheets Dashboard" records (729:37832).
class TimesheetEntry implements Identified {
  const new({
    required this.id,
    required this.task,
    required this.project,
    required this.employee,
    required this.start,
    required this.end,
    required this.rate,
    required this.status,
  });

  @override
  final String id;
  final String task;
  final String project;
  final String employee;
  final DateTime start;
  final DateTime end;
  final double rate;
  final TimesheetStatus status;

  Duration get duration => end.difference(start);
  double get amount => rate * duration.inMinutes / 60;

  TimesheetEntry withStatus(TimesheetStatus s) => TimesheetEntry(
    id: id,
    task: task,
    project: project,
    employee: employee,
    start: start,
    end: end,
    rate: rate,
    status: s,
  );
}

DateTime _d(int dayOffset, int h, [int m = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + dayOffset, h, m);
}

const workProjects = [
  'Demo Project 01 — Customer Portal Revamp',
  'UI & UX',
  'Frontend Development',
  'Graphic Design',
  'Engineering',
];

/// The demo account (profile "Demo User"): My Tasks shows its tasks.
const demoSelf = 'Demo User';

const List<String> workPeople = [
  demoSelf,
  'Employee 1',
  'Employee 2',
  'Employee 3',
  'Lina Dawood',
  'Karim Daher',
  'Omar Demo',
];

final NotifierProvider<LocalCollection<WorkTask>, List<WorkTask>>
workTasksProvider = NotifierProvider<LocalCollection<WorkTask>, List<WorkTask>>(
  () => LocalCollection<WorkTask>(
    () => [
      WorkTask(
        id: 't1',
        code: 'P01-T04',
        title: 'Create executive dashboard widgets & realtime stream',
        project: workProjects[0],
        sprint: 'Sprint 4',
        assignee: demoSelf,
        description:
            'Build the KPI widgets for the executive dashboard and feed '
            'them from the realtime event stream.',
        due: _d(2, 18),
        status: TaskStatus.inProgress,
        priority: TaskPriority.urgent,
        points: 5,
        start: _d(-1, 9),
        end: _d(-1, 11, 30),
        amount: 133.58,
        subtasksDone: 3,
        subtasksTotal: 5,
      ),
      WorkTask(
        id: 't2',
        code: 'P01-T09',
        title: 'Integrate payment webhooks',
        project: workProjects[0],
        sprint: 'Sprint 4',
        assignee: 'Karim Daher',
        description: 'Receive and verify payment provider callbacks.',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        points: 3,
        start: _d(-2, 7, 40),
        end: _d(-2, 12, 10),
        amount: 160.75,
        subtasksDone: 1,
        subtasksTotal: 4,
      ),
      WorkTask(
        id: 't3',
        code: 'P01-T12',
        title: 'Configure Redis cache invalidation hooks',
        project: workProjects[0],
        sprint: 'Sprint 4',
        assignee: demoSelf,
        description:
            'Invalidate cached project and invoice pages whenever the '
            'underlying records change, including bulk imports, and '
            'add a dashboard showing the hit rate per cache key so the '
            'team can spot stale entries before customers do.',
        due: _d(5, 17),
        status: TaskStatus.inProgress,
        priority: TaskPriority.medium,
        points: 2,
        start: _d(-3, 9, 30),
        end: _d(-3, 11, 30),
        amount: 95,
      ),
      WorkTask(
        id: 't4',
        code: 'TASK-8921',
        title: 'Consequatur magna qui',
        project: 'UI & UX',
        sprint: 'Sprint 4',
        assignee: demoSelf,
        status: TaskStatus.todo,
        priority: TaskPriority.low,
        points: 1,
        start: _d(-4, 5, 31),
        end: _d(-4, 10, 29),
        amount: 210.4,
      ),
      WorkTask(
        id: 't5',
        code: 'TASK-8922',
        title: 'Voluptas sit amet',
        project: 'Frontend Development',
        sprint: 'Core integration',
        assignee: 'Employee 2',
        status: TaskStatus.completed,
        priority: TaskPriority.medium,
        points: 3,
        start: _d(-5, 7, 40),
        end: _d(-5, 12, 10),
        amount: 160.75,
      ),
      WorkTask(
        id: 't6',
        code: 'TASK-8930',
        title: 'Dolorbus est nulla',
        project: 'Graphic Design',
        sprint: 'Backlog',
        assignee: 'Employee 3',
        status: TaskStatus.backlog,
        priority: TaskPriority.low,
        points: 2,
        start: _d(-6, 9),
        end: _d(-6, 11, 30),
        amount: 95,
      ),
    ],
  ),
);

final timesheetsProvider =
    NotifierProvider<LocalCollection<TimesheetEntry>, List<TimesheetEntry>>(
      () => LocalCollection<TimesheetEntry>(
        () => [
          for (var i = 0; i < 6; i++)
            TimesheetEntry(
              id: 'ts$i',
              task: const [
                'P04-T04 Implement search filters',
                'P02-T09 Integrate payment webhooks',
                'P01-T12 Configure Redis cache invalidation',
                'P03-T02 Design onboarding screens',
                'P05-T07 Write REST endpoint tests',
                'P02-T15 Fix invoice PDF layout',
              ][i],
              project: workProjects[1 + i % 4],
              employee: workPeople[i % workPeople.length],
              start: _d(-i, 8),
              end: _d(-i, 8 + 1 + i % 3, 30),
              rate: 18 + i * 3,
              status: TimesheetStatus.values[i % 3],
            ),
        ],
      ),
    );
