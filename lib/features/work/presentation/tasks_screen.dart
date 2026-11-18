import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/api_task_form.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/features/work/presentation/task_filters.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String priorityLabel(AppLocalizations l10n, TaskPriority p) => switch (p) {
  TaskPriority.low => l10n.priorityLow,
  TaskPriority.medium => l10n.priorityMedium,
  TaskPriority.high => l10n.priorityHigh,
  TaskPriority.urgent => l10n.priorityUrgent,
};

String taskStatusLabel(AppLocalizations l10n, TaskStatus s) => switch (s) {
  TaskStatus.backlog => l10n.backlog,
  TaskStatus.todo => l10n.toDo,
  TaskStatus.inProgress => l10n.statusInProgress,
  TaskStatus.completed => l10n.statusCompleted,
};

String durationLabel(Duration d) => '${d.inHours}h ${d.inMinutes % 60}m';

BadgeTone taskStatusTone(TaskStatus s) => switch (s) {
  TaskStatus.backlog => BadgeTone.neutral,
  TaskStatus.todo => BadgeTone.info,
  TaskStatus.inProgress => BadgeTone.warning,
  TaskStatus.completed => BadgeTone.success,
};

BadgeTone apiTaskStatusTone(ApiTaskStatus s) => switch (s) {
  ApiTaskStatus.inProgress || ApiTaskStatus.inReview => BadgeTone.warning,
  ApiTaskStatus.completed => BadgeTone.success,
  ApiTaskStatus.todo || ApiTaskStatus.pending => BadgeTone.info,
  _ => BadgeTone.neutral,
};

/// One line for a task's time: `2026/11/14 09:00–11:30`, or both dates when
/// it spans days.
String scheduleLabel(DateTime start, DateTime end) {
  final day = DateFormat('yyyy/MM/dd', 'en');
  final time = DateFormat('HH:mm', 'en');
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  // Left-to-right isolate: the figures keep their order inside Arabic
  // text. Word joiners keep a range together, so a narrow card breaks
  // between the date and the times, never inside "09:30–11:30".
  final from = '${day.format(start)} ${time.format(start)}';
  final range = sameDay
      ? '$from$_joinedDash${time.format(end)}'
      : '$from – ${day.format(end)} ${time.format(end)}';
  return '$_lri$range$_pdi';
}

/// Left-to-right isolate around figures, and an en dash that never breaks.
const _lri = '\u2066';
const _pdi = '\u2069';
const _joinedDash = '\u2060–\u2060';

/// [text] as figures that keep their order in Arabic (see [scheduleLabel]).
String ltrIsolate(String text) => '$_lri$text$_pdi';

final _dueDay = DateFormat('yyyy/MM/dd', 'en');

/// Add/edit task. Demo: the local form. API: the task form for a project
/// the user leads (`POST /employee/tasks` accepts new tasks only from the
/// project's leader); someone who leads none is told so.
Future<void> openTaskForm(BuildContext context, {WorkTask? existing}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(demoModeProvider)) {
    await openDemoForm(
      context,
      page: (_) => TaskFormScreen(existing: existing),
      unavailable: AppLocalizations.of(context).taskCreateUnavailable,
    );
    return;
  }
  final List<ProjectOption> led;
  try {
    led = await container.read(ledProjectsProvider.future);
  } on Object catch (e) {
    if (context.mounted) {
      showSnack(context, localizedError(AppLocalizations.of(context), e));
    }
    return;
  }
  if (!context.mounted) return;
  if (led.isEmpty) {
    showSnack(context, AppLocalizations.of(context).taskCreateUnavailable);
    return;
  }
  await openApiTaskForm(context);
}

/// The documented `status` list filter for [tab] (`null`: no filter).
ApiTaskStatus? apiStatusOf(TaskStatusTab tab) => switch (tab) {
  TaskStatusTab.all => null,
  TaskStatusTab.todo => ApiTaskStatus.todo,
  TaskStatusTab.inProgress => ApiTaskStatus.inProgress,
  TaskStatusTab.inReview => ApiTaskStatus.inReview,
  TaskStatusTab.completed => ApiTaskStatus.completed,
};

/// Whether a demo task belongs under [tab]. Demo tasks have no review
/// state, so "Under Review" matches none of them rather than borrowing
/// another status.
bool demoTaskInTab(WorkTask t, TaskStatusTab tab) => switch (tab) {
  TaskStatusTab.all => true,
  TaskStatusTab.todo => t.status == TaskStatus.todo,
  TaskStatusTab.inProgress => t.status == TaskStatus.inProgress,
  TaskStatusTab.inReview => false,
  TaskStatusTab.completed => t.status == TaskStatus.completed,
};

String taskTabLabel(AppLocalizations l10n, TaskStatusTab tab) => switch (tab) {
  TaskStatusTab.all => l10n.allTasks,
  TaskStatusTab.todo => l10n.toDo,
  TaskStatusTab.inProgress => l10n.statusInProgress,
  TaskStatusTab.inReview => l10n.underReview,
  TaskStatusTab.completed => l10n.statusCompleted,
};

/// Figma "Tasks Management" (729:24059), content first: one search (the
/// masthead's), My/Team only for someone who leads a project, and one
/// "Filters" sheet for status, project, priority, assignee and sort. The
/// Redmi 8 acceptance run found always-visible status chips next to the
/// Filters button distracting, so status moved into the sheet too.
class TasksScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _pageSize = 4;
  String _query = '';
  TaskScope _scope = TaskScope.mine;
  TaskFilters _filters = const TaskFilters();
  int _page = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// A new search starts on page 1. In API mode each search is a request,
  /// so typing is debounced instead of sending one per keystroke.
  void _onSearch(String v) {
    void apply() => setState(() {
      _query = v;
      _page = 0;
    });
    _debounce?.cancel();
    if (ref.read(demoModeProvider)) {
      apply();
    } else {
      _debounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) apply();
      });
    }
  }

  /// Every filter change starts on page 1: a kept page number past the
  /// result's last page showed an empty list with no pager.
  void _set({TaskScope? scope, TaskFilters? filters}) => setState(() {
    if (scope != null && scope != _scope) {
      _scope = scope;
      // Assignees exist only in the team view.
      _filters = _filters.without(assignee: true);
    }
    if (filters != null) _filters = filters;
    _page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    // Team tasks only for someone who leads a project (and the demo): for
    // everyone else the backend answers with their own tasks, so the
    // switch showed the same list twice.
    final canTeam = demo || ref.watch(ledProjectIdsProvider).isNotEmpty;
    final scope = canTeam ? _scope : TaskScope.mine;
    final mine = scope == TaskScope.mine;
    final q = _query.trim().toLowerCase();

    // Demo: My Tasks are the demo account's (the API filters by
    // `assigned_to` and checks every row; see BoardRepository.tasks).
    final all = [
      for (final t in ref.watch(workTasksProvider))
        if (!mine || t.assignee == demoSelf) t,
    ];
    final filtered = all.where((t) {
      if (!demoTaskInTab(t, _filters.status)) return false;
      if (_filters.project != null && t.project != _filters.project) {
        return false;
      }
      if (!mine &&
          _filters.assignee != null &&
          t.assignee != _filters.assignee) {
        return false;
      }
      if (_filters.priority != null && t.priority != _filters.priority) {
        return false;
      }
      return q.isEmpty ||
          '${t.title} ${t.code} ${t.project} ${t.assignee}'
              .toLowerCase()
              .contains(q);
    }).toList();
    final page = _page.clamp(
      0,
      ((filtered.length - 1) ~/ _pageSize).clamp(0, 999),
    );
    final visible = filtered.skip(page * _pageSize).take(_pageSize).toList();
    final active = all.where((t) => t.status != TaskStatus.completed).length;
    final hours = all.fold<int>(0, (s, t) => s + t.duration.inMinutes) ~/ 60;
    final budget = all.fold<double>(0, (s, t) => s + t.amount);
    // API mode: figures from `stats` of GET /employee/tasks. The employee
    // role gets no cost/currency, so budget utilisation has no source.
    final api = demo ? null : ref.watch(scopedTaskStatsProvider(scope));
    final stats = api?.value;
    // Creating is offered only to a project leader (API) and in the demo.
    final canCreate = canTeam;

    // Projects for the sheet: the documented options list (API) or the
    // demo tasks' projects. A failed options load only leaves it out.
    final projects = demo
        ? [
            for (final p in {for (final t in all) t.project}) (p as Object, p),
          ]
        : [
            for (final p
                in ref.watch(projectOptionsProvider).value ??
                    const <ProjectOption>[])
              (p.id as Object, p.title),
          ];
    String projectLabel(Object id) =>
        projects.where((p) => p.$1 == id).firstOrNull?.$2 ?? '#$id';

    // A result count shows over a searched or narrowed list.
    final narrowed = q.isNotEmpty || _filters.narrows;

    // The scope's total per status, for the sheet's status choices (the
    // sheet hides them once anything else narrows the list).
    int? statusCount(TaskStatusTab tab) {
      if (demo) return all.where((t) => demoTaskInTab(t, tab)).length;
      if (stats == null) return null;
      return switch (tab) {
        TaskStatusTab.all => stats.total,
        TaskStatusTab.todo => stats.byStatus['todo'],
        TaskStatusTab.inProgress => stats.byStatus['in_progress'],
        TaskStatusTab.inReview => stats.byStatus['in_review'],
        TaskStatusTab.completed => stats.byStatus['completed'],
      };
    }

    final activeFilters = [
      if (_filters.status != TaskStatusTab.all)
        ActiveFilter(
          'status',
          taskTabLabel(l10n, _filters.status),
          () => _set(filters: _filters.without(status: true)),
        ),
      if (_filters.project case final p?)
        ActiveFilter(
          'project',
          projectLabel(p),
          () => _set(filters: _filters.without(project: true)),
        ),
      if (_filters.priority case final p?)
        ActiveFilter(
          'priority',
          priorityLabel(l10n, p),
          () => _set(filters: _filters.without(priority: true)),
        ),
      if (_filters.assignee case final a? when !mine)
        ActiveFilter(
          'assignee',
          a,
          () => _set(filters: _filters.without(assignee: true)),
        ),
      if (_filters.sort != TaskSort.newest)
        ActiveFilter(
          'sort',
          taskSortLabel(l10n, _filters.sort),
          () => _set(filters: _filters.without(sort: true)),
        ),
    ];

    Future<void> openFilters() async {
      final picked = await showTaskFilterSheet(
        context,
        current: _filters,
        projects: projects,
        priorityLabel: (p) => priorityLabel(l10n, p),
        statusLabel: (s) => taskTabLabel(l10n, s),
        statusCount: statusCount,
        countsApply: q.isEmpty,
        assignees: demo && !mine
            ? [
                for (final a in {for (final t in all) t.assignee}) a,
              ]
            : const [],
        // The demo list has no server-side order to change.
        sortable: !demo,
      );
      // Unchanged: no new request, no page reset.
      if (picked != null && picked != _filters) _set(filters: picked);
    }

    return ModulePage(
      title: l10n.tasksManagement,
      description: l10n.tasksManagementBody,
      searchHint: l10n.searchTasksHint,
      searchFieldKey: const Key('tasks-search'),
      onSearch: _onSearch,
      onCreate: canCreate
          ? () => demo ? openTaskForm(context) : openApiTaskForm(context)
          : null,
      createLabel: l10n.addTask,
      children: [
        if (canTeam)
          // Whose tasks: the employee's own first. "Team tasks" is every
          // task of the projects this account leads (`tasks.view`).
          ChipRow(
            key: const Key('task-scope'),
            children: [
              for (final (s, label) in [
                (TaskScope.mine, l10n.myTasks),
                (TaskScope.team, l10n.teamTasks),
              ])
                FilterChipBox(
                  key: Key('task-scope-${s.name}'),
                  label: label,
                  selected: scope == s,
                  onTap: () => _set(scope: s),
                ),
            ],
          ),
        if (api case AsyncError(:final error))
          ApiErrorCard(
            error: error,
            onRetry: () => ref.invalidate(scopedTaskStatsProvider(scope)),
          ),
        MetricGroup(
          metrics: [
            Metric(
              label: l10n.activeTasks,
              value: demo ? '$active' : '${stats?.active ?? '—'}',
            ),
            if (demo)
              Metric(label: l10n.totalBudgetUtilization, value: money(budget)),
            Metric(
              label: l10n.loggedHours,
              value: demo
                  ? '$hours'
                  : stats == null
                  ? '—'
                  : (stats.loggedMinutes / 60).toStringAsFixed(1),
            ),
          ],
        ),
        TaskFilterBar(
          count: _filters.count,
          active: activeFilters,
          onOpen: openFilters,
          onReset: () => _set(filters: const TaskFilters()),
        ),
        if (!demo)
          _ApiTaskRows(
            query: TaskQuery(
              scope: scope,
              search: _query,
              status: apiStatusOf(_filters.status),
              priority: _filters.priority,
              page: _page + 1,
              projectId: _filters.project as int?,
              sort: _filters.sort,
            ),
            showCount: narrowed,
            onPage: (p) => setState(() => _page = p),
          )
        else ...[
          if (narrowed) _ResultCount(filtered.length),
          if (visible.isEmpty)
            EmptyNotice(
              text: mine && all.isEmpty ? l10n.noTasksAssigned : l10n.noRecords,
            ),
          for (final t in visible)
            TaskCard(
              key: Key('task-${t.id}'),
              title: t.title,
              description: t.description,
              due: switch (t.due) {
                final d? => ltrIsolate(_dueDay.format(d)),
                null => null,
              },
              status: StatusBadge(
                label: taskStatusLabel(l10n, t.status),
                tone: taskStatusTone(t.status),
              ),
              onOpen: () => openTaskDetails(context, t),
            ),
          Pager(
            page: page,
            pageSize: _pageSize,
            total: filtered.length,
            onPage: (p) => setState(() => _page = p),
          ),
        ],
      ],
    );
  }
}

/// "3 tasks" over a filtered list.
class _ResultCount extends StatelessWidget {
  const new(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      AppLocalizations.of(context).taskResultCount(count),
      key: const Key('task-result-count'),
      style: AppTextStyles.mobileXsSemiBold.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Create/edit task form. Figma shows the Create action but no form frame,
/// so the fields follow the documented task attributes with the shared
/// form styling.
class TaskFormScreen extends ConsumerStatefulWidget {
  const new({this.existing, this.initialStatus, super.key});

  final WorkTask? existing;
  final TaskStatus? initialStatus;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _points = TextEditingController(
    text: '${widget.existing?.points ?? 1}',
  );
  late String? _project = widget.existing?.project;
  late String? _assignee = widget.existing?.assignee;
  late TaskPriority? _priority =
      widget.existing?.priority ?? TaskPriority.medium;
  late TaskStatus? _status =
      widget.existing?.status ?? widget.initialStatus ?? TaskStatus.todo;
  late DateTime _date = widget.existing?.start ?? DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _points.dispose();
    super.dispose();
  }

  void _save() {
    if (!validateAndReveal(_form)) return;
    final e = widget.existing;
    final start = DateTime(_date.year, _date.month, _date.day, 9);
    final notifier = ref.read(workTasksProvider.notifier);
    final bool applied;
    if (e == null) {
      applied = notifier.add(
        WorkTask(
          id: localId('task'),
          code: 'TASK-${8900 + ref.read(workTasksProvider).length + 40}',
          title: _title.text.trim(),
          project: _project!,
          sprint: 'Sprint 4',
          assignee: _assignee!,
          status: _status!,
          priority: _priority!,
          points: int.parse(_points.text),
          start: start,
          end: start.add(const Duration(hours: 2)),
          amount: 0,
        ),
      );
    } else {
      applied = notifier.replace(
        e.copyWith(
          title: _title.text.trim(),
          project: _project,
          assignee: _assignee,
          status: _status,
          priority: _priority,
          points: int.parse(_points.text),
          start: start,
          end: start.add(e.duration),
        ),
      );
    }
    showLocalOutcome(context, applied: applied);
    if (applied) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String id(String s) => s;
    return FormPage(
      title: widget.existing == null ? l10n.addTask : l10n.editTask,
      formKey: _form,
      onSave: _save,
      fields: [
        TextInputField(
          fieldKey: const Key('task-title'),
          label: l10n.taskTitle,
          controller: _title,
        ),
        SelectField<String>(
          label: l10n.fieldProject,
          value: _project,
          options: {...workProjects, ?_project}.toList(),
          labelOf: id,
          onChanged: (v) => setState(() => _project = v),
        ),
        SelectField<String>(
          label: l10n.assignee,
          value: _assignee,
          options: {...workPeople, ?_assignee}.toList(),
          labelOf: id,
          onChanged: (v) => setState(() => _assignee = v),
        ),
        SelectField<TaskPriority>(
          label: l10n.priority,
          value: _priority,
          options: TaskPriority.values,
          labelOf: (p) => priorityLabel(l10n, p),
          onChanged: (v) => setState(() => _priority = v),
        ),
        SelectField<TaskStatus>(
          label: l10n.fieldStatus,
          value: _status,
          options: TaskStatus.values,
          labelOf: (s) => taskStatusLabel(l10n, s),
          onChanged: (v) => setState(() => _status = v),
        ),
        TextInputField(
          fieldKey: const Key('task-points'),
          label: l10n.storyPoints,
          controller: _points,
          number: true,
          // Points are whole numbers; "1.5" used to be saved as 1.
          validator: (v) => wholeNumber(context, v),
        ),
        DateField(
          label: l10n.taskDate,
          value: _date,
          onChanged: (d) => setState(() => _date = d),
        ),
      ],
    );
  }
}

/// Task rows of `GET /employee/tasks` for one [TaskQuery] (search, status,
/// priority, project, sort and page are all sent to the server). While a
/// new filter loads, the previous rows stay on screen under a thin progress
/// bar instead of being replaced by a spinner.
class _ApiTaskRows extends ConsumerStatefulWidget {
  const new({
    required this.query,
    required this.onPage,
    this.showCount = false,
  });

  final TaskQuery query;
  final ValueChanged<int> onPage;
  final bool showCount;

  @override
  ConsumerState<_ApiTaskRows> createState() => _ApiTaskRowsState();
}

class _ApiTaskRowsState extends ConsumerState<_ApiTaskRows> {
  TaskList? _last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = widget.query;
    final value = ref.watch(apiTasksProvider(query));
    if (value.value case final v?) _last = v;
    final previous = value.isLoading && !value.hasValue ? _last : null;
    if (value.hasValue || previous != null) {
      final list = value.value ?? previous!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (previous != null) ...[
            const LinearProgressIndicator(key: Key('tasks-refreshing')),
            const SizedBox(height: 8),
          ],
          if (widget.showCount && previous == null) ...[
            _ResultCount(list.page.total),
            const SizedBox(height: 12),
          ],
          ..._rows(context, l10n, list, query),
        ],
      );
    }
    return AsyncSection(
      value: value,
      onRetry: () => ref.invalidate(apiTasksProvider(query)),
      builder: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _rows(context, l10n, list, query),
      ),
    );
  }

  List<Widget> _rows(
    BuildContext context,
    AppLocalizations l10n,
    TaskList list,
    TaskQuery query,
  ) => [
    if (list.hidden > 0) ...[
      ModuleCard(
        key: const Key('tasks-hidden-notice'),
        child: Text(
          l10n.tasksHiddenUnverified(list.hidden),
          style: AppTextStyles.mobileXsRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
    if (list.page.items.isEmpty && list.hidden == 0)
      EmptyNotice(
        text: query.scope == TaskScope.mine && !query.filtered
            ? l10n.noTasksAssigned
            : l10n.noRecords,
      ),
    for (final t in list.page.items) ...[
      TaskCard(
        key: Key('api-task-${t.id}'),
        title: t.title,
        // Only what the server sent; the API has no due date
        // (`task_date` is the planned work day, shown in details).
        description: t.description,
        status: StatusBadge(
          label: apiTaskStatusLabel(l10n, t.status),
          tone: apiTaskStatusTone(t.status),
        ),
        onOpen: () => openApiTaskDetails(context, t),
      ),
      const SizedBox(height: 12),
    ],
    if (list.page.lastPage > 1)
      Pager(
        page: list.page.currentPage - 1,
        pageSize: list.page.perPage,
        total: list.page.total,
        onPage: widget.onPage,
      ),
  ];
}
