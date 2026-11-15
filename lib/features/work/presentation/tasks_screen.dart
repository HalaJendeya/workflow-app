import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
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
String _isolate(String text) => '$_lri$text$_pdi';

final _dt = DateFormat('yyyy/MM/dd - HH:mm', 'en');

/// Add/edit task. Demo only for now: the API accepts new tasks only from a
/// project leader and this form does not send them yet, so in API mode
/// this explains that instead of opening the form.
Future<void> openTaskForm(BuildContext context, {WorkTask? existing}) =>
    openDemoForm(
      context,
      page: (_) => TaskFormScreen(existing: existing),
      unavailable: AppLocalizations.of(context).taskCreateUnavailable,
    );

void showTaskDetails(BuildContext context, WorkTask t) {
  final l10n = AppLocalizations.of(context);
  unawaited(
    showRecordDetails(
      context,
      title: t.title,
      status: taskStatusLabel(l10n, t.status),
      tone: BadgeTone.info,
      fields: [
        DetailField(l10n.taskCode, '${t.code} • ${t.sprint}'),
        DetailField(l10n.fieldAmount, money(t.amount)),
        DetailField(l10n.fieldProject, t.project),
        DetailField(l10n.fieldEmployee, t.assignee),
        DetailField(l10n.priority, priorityLabel(l10n, t.priority)),
        DetailField(l10n.startDate, _dt.format(t.start)),
        DetailField(l10n.endDate, _dt.format(t.end)),
        DetailField(l10n.duration, durationLabel(t.duration)),
      ],
    ),
  );
}

/// Status chips of Figma "Tasks Management" (node 729:24295).
enum TaskStatusTab { all, inProgress, inReview, completed }

/// The documented `status` list filter for [tab] (`null`: no filter).
ApiTaskStatus? apiStatusOf(TaskStatusTab tab) => switch (tab) {
  TaskStatusTab.all => null,
  TaskStatusTab.inProgress => ApiTaskStatus.inProgress,
  TaskStatusTab.inReview => ApiTaskStatus.inReview,
  TaskStatusTab.completed => ApiTaskStatus.completed,
};

/// Whether a demo task belongs under [tab]. Demo tasks have no review
/// state, so "Under Review" matches none of them rather than borrowing
/// another status.
bool demoTaskInTab(WorkTask t, TaskStatusTab tab) => switch (tab) {
  TaskStatusTab.all => true,
  TaskStatusTab.inProgress => t.status == TaskStatus.inProgress,
  TaskStatusTab.inReview => false,
  TaskStatusTab.completed => t.status == TaskStatus.completed,
};

String taskTabLabel(AppLocalizations l10n, TaskStatusTab tab) => switch (tab) {
  TaskStatusTab.all => l10n.allTasks,
  TaskStatusTab.inProgress => l10n.statusInProgress,
  TaskStatusTab.inReview => l10n.underReview,
  TaskStatusTab.completed => l10n.statusCompleted,
};

/// Figma "Tasks Management" (729:24059).
class TasksScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _pageSize = 4;
  String _query = '';
  TaskStatusTab _tab = TaskStatusTab.all;
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

  String? _project;
  String? _assignee;
  TaskPriority? _priority;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final all = ref.watch(workTasksProvider);
    final q = _query.trim().toLowerCase();
    final filtered = all.where((t) {
      if (!demoTaskInTab(t, _tab)) return false;
      if (_project != null && t.project != _project) return false;
      if (_assignee != null && t.assignee != _assignee) return false;
      if (_priority != null && t.priority != _priority) return false;
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
    final api = demo ? null : ref.watch(employeeTaskStatsProvider);
    final stats = api?.value;
    String tabCount(TaskStatusTab tab) {
      if (demo) return '${all.where((t) => demoTaskInTab(t, tab)).length}';
      if (stats == null) return '—';
      final n = switch (tab) {
        TaskStatusTab.all => stats.total,
        TaskStatusTab.inProgress => stats.byStatus['in_progress'],
        TaskStatusTab.inReview => stats.byStatus['in_review'],
        TaskStatusTab.completed => stats.byStatus['completed'],
      };
      return '${n ?? '—'}';
    }

    return ModulePage(
      title: l10n.tasksManagement,
      description: l10n.tasksManagementBody,
      // A new search starts on page 1: in API mode a kept page number past
      // the result's last page showed an empty list with no pager.
      onSearch: _onSearch,
      onCreate: () => openTaskForm(context),
      createLabel: l10n.addTask,
      children: [
        if (api case AsyncError(:final error))
          ApiErrorCard(
            error: error,
            onRetry: () => ref.invalidate(employeeTaskStatsProvider),
          ),
        MetricGroup(
          metrics: [
            Metric(
              label: l10n.activeTasks,
              value: demo ? '$active' : '${stats?.active ?? '—'}',
            ),
            if (demo)
              Metric(
                label: l10n.totalBudgetUtilization,
                value: demo ? money(budget) : '—',
              ),
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
        ChipRow(
          children: [
            for (final tab in TaskStatusTab.values)
              FilterChipBox(
                key: Key('task-tab-${tab.name}'),
                label: '${taskTabLabel(l10n, tab)} ${tabCount(tab)}',
                selected: _tab == tab,
                onTap: () => setState(() {
                  _tab = tab;
                  _page = 0;
                }),
              ),
          ],
        ),
        if (!demo)
          _ApiTaskRows(
            query: (
              search: _query,
              status: apiStatusOf(_tab),
              priority: _priority,
              page: _page + 1,
            ),
            onSearch: _onSearch,
            onPriority: (p) => setState(() {
              _priority = p;
              _page = 0;
            }),
            onPage: (p) => setState(() => _page = p),
          )
        else ...[
          WfSearchBox(
            fieldKey: const Key('tasks-search'),
            hint: l10n.searchTasksHint,
            onChanged: _onSearch,
          ),
          ChipRow(
            children: [
              DropdownChip<String?>(
                value: _project,
                options: [
                  null,
                  ...{for (final t in all) t.project},
                ],
                labelOf: (p) => p ?? l10n.allProjects,
                onChanged: (p) => setState(() {
                  _project = p;
                  _page = 0;
                }),
              ),
              DropdownChip<String?>(
                value: _assignee,
                options: [
                  null,
                  ...{for (final t in all) t.assignee},
                ],
                labelOf: (p) => p ?? l10n.allAssignees,
                onChanged: (p) => setState(() {
                  _assignee = p;
                  _page = 0;
                }),
              ),
              DropdownChip<TaskPriority?>(
                value: _priority,
                options: const [null, ...TaskPriority.values],
                labelOf: (p) =>
                    p == null ? l10n.priorityLevel : priorityLabel(l10n, p),
                onChanged: (p) => setState(() {
                  _priority = p;
                  _page = 0;
                }),
              ),
            ],
          ),
          if (visible.isEmpty) EmptyNotice(text: l10n.noRecords),
          for (final t in visible)
            TaskCard(
              key: Key('task-${t.id}'),
              title: t.title,
              subtitle: [t.code, t.sprint, t.project].join(' · '),
              badge: StatusBadge(
                label: taskStatusLabel(l10n, t.status),
                tone: taskStatusTone(t.status),
              ),
              meta: [
                TaskMeta(Icons.person_outline, l10n.fieldEmployee, t.assignee),
                TaskMeta(
                  Icons.event_outlined,
                  l10n.startDate,
                  scheduleLabel(t.start, t.end),
                ),
                TaskMeta(
                  Icons.timer_outlined,
                  l10n.duration,
                  durationLabel(t.duration),
                ),
                TaskMeta(
                  Icons.flag_outlined,
                  l10n.priority,
                  priorityLabel(l10n, t.priority),
                ),
                TaskMeta(
                  Icons.payments_outlined,
                  l10n.fieldAmount,
                  money(t.amount),
                  strong: true,
                ),
              ],
              onView: () => showTaskDetails(context, t),
              onEdit: () => openTaskForm(context, existing: t),
              onDelete: () async {
                if (await confirmDelete(context, t.code)) {
                  final removed = ref
                      .read(workTasksProvider.notifier)
                      .remove(t.id);
                  if (context.mounted) {
                    showLocalOutcome(context, applied: removed, deleted: true);
                  }
                }
              },
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

/// Task rows of `GET /employee/tasks`, with server-side search, priority
/// filter and pagination. Project and assignee filters need the shape of
/// `facets`, which is undocumented, so they are not offered here.
class _ApiTaskRows extends ConsumerWidget {
  const new({
    required this.query,
    required this.onSearch,
    required this.onPriority,
    required this.onPage,
  });

  final TaskQuery query;
  final ValueChanged<String> onSearch;
  final ValueChanged<TaskPriority?> onPriority;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiTasksProvider(query));
    final date = DateFormat('yyyy/MM/dd', 'en');
    final time = DateFormat('HH:mm', 'en');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WfSearchBox(
          fieldKey: const Key('tasks-search'),
          hint: l10n.searchTasksHint,
          onChanged: onSearch,
        ),
        const SizedBox(height: 20),
        ChipRow(
          children: [
            DropdownChip<TaskPriority?>(
              value: query.priority,
              options: const [null, ...TaskPriority.values],
              labelOf: (p) =>
                  p == null ? l10n.priorityLevel : priorityLabel(l10n, p),
              onChanged: onPriority,
            ),
          ],
        ),
        const SizedBox(height: 20),
        AsyncSection(
          value: value,
          onRetry: () => ref.invalidate(apiTasksProvider(query)),
          builder: (page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.items.isEmpty) EmptyNotice(text: l10n.noRecords),
              for (final t in page.items) ...[
                TaskCard(
                  key: Key('api-task-${t.id}'),
                  title: t.title,
                  subtitle: [
                    '#${t.id}',
                    ?t.sprintName,
                    ?t.projectTitle,
                  ].join(' · '),
                  badge: StatusBadge(
                    label: apiTaskStatusLabel(l10n, t.status),
                    tone: apiTaskStatusTone(t.status),
                  ),
                  // Only what the server sent: no empty fields, no guesses.
                  // The employee role receives no task cost.
                  meta: [
                    if (t.assigneeName != null)
                      TaskMeta(
                        Icons.person_outline,
                        l10n.fieldEmployee,
                        t.assigneeName!,
                      ),
                    if (t.taskDate != null || t.start != null)
                      TaskMeta(
                        Icons.event_outlined,
                        l10n.startDate,
                        _isolate(
                          [
                            if (t.taskDate != null) date.format(t.taskDate!),
                            [
                              if (t.start != null) time.format(t.start!),
                              if (t.end != null) time.format(t.end!),
                            ].join(_joinedDash),
                          ].where((x) => x.isNotEmpty).join(' '),
                        ),
                      ),
                    if (t.duration != null)
                      TaskMeta(
                        Icons.timer_outlined,
                        l10n.duration,
                        durationLabel(t.duration!),
                      ),
                    if (t.priority != null)
                      TaskMeta(
                        Icons.flag_outlined,
                        l10n.priority,
                        priorityLabel(l10n, t.priority!),
                      ),
                    if (t.storyPoints != null)
                      TaskMeta(
                        Icons.star_outline,
                        l10n.storyPoints,
                        l10n.points(t.storyPoints!),
                        strong: true,
                      ),
                  ],
                  onView: () => showRecordDetails(
                    context,
                    title: t.title,
                    status: apiTaskStatusLabel(l10n, t.status),
                    tone: BadgeTone.info,
                    fields: [
                      DetailField(l10n.fieldProject, t.projectTitle ?? '—'),
                      DetailField(
                        l10n.priority,
                        t.priority == null
                            ? '—'
                            : priorityLabel(l10n, t.priority!),
                      ),
                      DetailField(l10n.fieldEmployee, t.assigneeName ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (page.lastPage > 1)
                Pager(
                  page: page.currentPage - 1,
                  pageSize: page.perPage,
                  total: page.total,
                  onPage: onPage,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
