import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Status chips of Figma "Tasks Management" (node 729:24295), plus "To do":
/// the status most of an employee's open work is in. Since the Redmi 8
/// acceptance run they live in the Filters sheet, not on the screen.
enum TaskStatusTab { all, todo, inProgress, inReview, completed }

/// Every task filter, kept together in one sheet: status, project,
/// priority, assignee (demo team view) and sort. Scope (My/Team) stays on
/// the screen; search stays in the masthead.
@immutable
class TaskFilters {
  const new({
    this.status = TaskStatusTab.all,
    this.project,
    this.priority,
    this.assignee,
    this.sort = TaskSort.newest,
  });

  final TaskStatusTab status;

  /// API: a project id (`project_id`); demo: a project name.
  final Object? project;
  final TaskPriority? priority;
  final String? assignee;

  /// `newest` is the server's default and is not sent.
  final TaskSort sort;

  /// Filters other than status that narrow the list. The status counts are
  /// totals for the scope, so they show only while this is false.
  bool get narrowsBeyondStatus =>
      project != null || priority != null || assignee != null;

  /// Filters that narrow the list (sort only reorders it).
  bool get narrows => status != TaskStatusTab.all || narrowsBeyondStatus;

  /// What the Filters button counts: everything that differs from the
  /// defaults, status and sort included.
  int get count =>
      (status != TaskStatusTab.all ? 1 : 0) +
      (project != null ? 1 : 0) +
      (priority != null ? 1 : 0) +
      (assignee != null ? 1 : 0) +
      (sort != TaskSort.newest ? 1 : 0);

  bool get isDefault => count == 0;

  TaskFilters without({
    bool status = false,
    bool project = false,
    bool priority = false,
    bool assignee = false,
    bool sort = false,
  }) => TaskFilters(
    status: status ? TaskStatusTab.all : this.status,
    project: project ? null : this.project,
    priority: priority ? null : this.priority,
    assignee: assignee ? null : this.assignee,
    sort: sort ? TaskSort.newest : this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskFilters &&
      other.status == status &&
      other.project == project &&
      other.priority == priority &&
      other.assignee == assignee &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(status, project, priority, assignee, sort);
}

String taskSortLabel(AppLocalizations l10n, TaskSort s) => switch (s) {
  TaskSort.newest => l10n.sortNewest,
  TaskSort.plannedDate => l10n.sortPlannedDate,
  TaskSort.title => l10n.sortTitle,
};

/// One sheet for status, project, priority, assignee and sort. Choices are
/// drafted and applied together with "Show results", so picking three
/// options sends one request, not three. Returns null when dismissed, and
/// the list stays as it was.
///
/// [statusCount] gives the scope's total for a status (null: unknown). The
/// totals describe the whole scope, so they show only while the draft
/// narrows nothing else and [countsApply] (no search) holds.
Future<TaskFilters?> showTaskFilterSheet(
  BuildContext context, {
  required TaskFilters current,
  required List<(Object, String)> projects,
  required String Function(TaskPriority) priorityLabel,
  required String Function(TaskStatusTab) statusLabel,
  int? Function(TaskStatusTab)? statusCount,
  bool countsApply = true,
  List<String> assignees = const [],
  bool sortable = true,
}) => showModalBottomSheet<TaskFilters>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) {
    var draft = current;
    return StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        Widget section(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.mobileBaseSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ChipRow(children: chips),
            ],
          ),
        );
        Widget choice<T>(String key, String label, T value, T selected) =>
            FilterChipBox(
              key: Key('filter-$key'),
              label: label,
              selected: value == selected,
              onTap: () => setState(() => draft = _withValue(draft, value)),
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              key: const Key('task-filter-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                  child: Text(
                    l10n.taskFiltersTitle,
                    style: AppTextStyles.mobileLgSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        section(l10n.fieldStatus, [
                          for (final tab in TaskStatusTab.values)
                            choice<TaskStatusTab>(
                              'status-${tab.name}',
                              switch (countsApply && !draft.narrowsBeyondStatus
                                  ? statusCount?.call(tab)
                                  : null) {
                                final n? => '${statusLabel(tab)} $n',
                                null => statusLabel(tab),
                              },
                              tab,
                              draft.status,
                            ),
                        ]),
                        if (projects.isNotEmpty)
                          section(l10n.filterProject, [
                            choice<_Project>(
                              'project-all',
                              l10n.allProjects,
                              const _Project(null),
                              _Project(draft.project),
                            ),
                            for (final (id, title) in projects)
                              choice<_Project>(
                                'project-$id',
                                title,
                                _Project(id),
                                _Project(draft.project),
                              ),
                          ]),
                        section(l10n.priority, [
                          choice<_Priority>(
                            'priority-any',
                            l10n.anyPriority,
                            const _Priority(null),
                            _Priority(draft.priority),
                          ),
                          for (final p in TaskPriority.values)
                            choice<_Priority>(
                              'priority-${p.name}',
                              priorityLabel(p),
                              _Priority(p),
                              _Priority(draft.priority),
                            ),
                        ]),
                        if (assignees.isNotEmpty)
                          section(l10n.assignee, [
                            choice<_Assignee>(
                              'assignee-all',
                              l10n.allAssignees,
                              const _Assignee(null),
                              _Assignee(draft.assignee),
                            ),
                            for (final a in assignees)
                              choice<_Assignee>(
                                'assignee-$a',
                                a,
                                _Assignee(a),
                                _Assignee(draft.assignee),
                              ),
                          ]),
                        if (sortable)
                          section(l10n.sortBy, [
                            for (final s in TaskSort.values)
                              choice<TaskSort>(
                                'sort-${s.name}',
                                taskSortLabel(l10n, s),
                                s,
                                draft.sort,
                              ),
                          ]),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('task-filters-reset'),
                        onPressed: draft.isDefault
                            ? null
                            : () => setState(() => draft = const TaskFilters()),
                        child: Text(l10n.resetFilters),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: WfPrimaryButton(
                          key: const Key('task-filters-apply'),
                          label: l10n.showResults,
                          height: 48,
                          textStyle: AppTextStyles.mobileBaseSemiBold,
                          onPressed: () => Navigator.of(sheet).pop(draft),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

// Wrappers so "no choice" (null) of each kind is a distinct value.
@immutable
class _Project {
  const new(this.id);
  final Object? id;
  @override
  bool operator ==(Object o) => o is _Project && o.id == id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class _Priority {
  const new(this.p);
  final TaskPriority? p;
  @override
  bool operator ==(Object o) => o is _Priority && o.p == p;
  @override
  int get hashCode => p.hashCode;
}

@immutable
class _Assignee {
  const new(this.name);
  final String? name;
  @override
  bool operator ==(Object o) => o is _Assignee && o.name == name;
  @override
  int get hashCode => name.hashCode;
}

TaskFilters _withValue(TaskFilters f, Object? v) => TaskFilters(
  status: v is TaskStatusTab ? v : f.status,
  project: v is _Project ? v.id : f.project,
  priority: v is _Priority ? v.p : f.priority,
  assignee: v is _Assignee ? v.name : f.assignee,
  sort: v is TaskSort ? v : f.sort,
);

/// An applied filter, shown beside the Filters button with a remove button.
class ActiveFilter {
  const new(this.key, this.label, this.onRemove);
  final String key;
  final String label;
  final VoidCallback onRemove;
}

/// "Filters (n)" button, the applied filters as removable chips, and
/// "Reset filters" when anything differs from the defaults.
class TaskFilterBar extends StatelessWidget {
  const new({
    required this.count,
    required this.active,
    required this.onOpen,
    required this.onReset,
    super.key,
  });

  final int count;
  final List<ActiveFilter> active;
  final VoidCallback onOpen;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final on = count > 0;
    return Wrap(
      key: const Key('task-filter-bar'),
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          button: true,
          child: Material(
            color: on ? AppColors.primary50 : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: on
                    ? ModuleColors.selectedChipBorder
                    : ModuleColors.chipBorder,
              ),
            ),
            child: InkWell(
              key: const Key('task-filters'),
              borderRadius: BorderRadius.circular(12),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 16,
                      color: on ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      on ? l10n.taskFiltersActive(count) : l10n.taskFilters,
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: on ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        for (final f in active)
          _ActiveChip(key: Key('active-filter-${f.key}'), filter: f),
        if (on)
          TextButton(
            key: const Key('reset-filters'),
            onPressed: onReset,
            child: Text(l10n.resetFilters),
          ),
      ],
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const new({required this.filter, super.key});

  final ActiveFilter filter;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary50,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: ModuleColors.selectedChipBorder),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              filter.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mobileXsSemiBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).removeFilter(filter.label),
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: filter.onRemove,
            icon: Icon(Icons.close, color: AppColors.primary),
          ),
        ],
      ),
    ),
  );
}
