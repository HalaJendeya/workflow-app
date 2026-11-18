import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// The less-used task filters, kept together in one sheet: project,
/// priority, assignee (demo team view) and sort. Status and scope stay on
/// the screen; search stays in the masthead.
@immutable
class TaskFilters {
  const new({
    this.project,
    this.priority,
    this.assignee,
    this.sort = TaskSort.newest,
  });

  /// API: a project id (`project_id`); demo: a project name.
  final Object? project;
  final TaskPriority? priority;
  final String? assignee;

  /// `newest` is the server's default and is not sent.
  final TaskSort sort;

  /// Filters that narrow the list (sort only reorders it).
  bool get narrows => project != null || priority != null || assignee != null;

  /// What the Filters button counts: everything that differs from the
  /// defaults, sort included.
  int get count =>
      (project != null ? 1 : 0) +
      (priority != null ? 1 : 0) +
      (assignee != null ? 1 : 0) +
      (sort != TaskSort.newest ? 1 : 0);

  bool get isDefault => count == 0;

  TaskFilters without({
    bool project = false,
    bool priority = false,
    bool assignee = false,
    bool sort = false,
  }) => TaskFilters(
    project: project ? null : this.project,
    priority: priority ? null : this.priority,
    assignee: assignee ? null : this.assignee,
    sort: sort ? TaskSort.newest : this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskFilters &&
      other.project == project &&
      other.priority == priority &&
      other.assignee == assignee &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(project, priority, assignee, sort);
}

String taskSortLabel(AppLocalizations l10n, TaskSort s) => switch (s) {
  TaskSort.newest => l10n.sortNewest,
  TaskSort.plannedDate => l10n.sortPlannedDate,
  TaskSort.title => l10n.sortTitle,
};

/// One sheet for project, priority, assignee and sort. Choices are drafted
/// and applied together with "Show results", so picking three options
/// sends one request, not three. Returns null when dismissed.
Future<TaskFilters?> showTaskFilterSheet(
  BuildContext context, {
  required TaskFilters current,
  required List<(Object, String)> projects,
  required String Function(TaskPriority) priorityLabel,
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

TaskFilters _withValue(TaskFilters f, Object? v) => switch (v) {
  _Project(:final id) => TaskFilters(
    project: id,
    priority: f.priority,
    assignee: f.assignee,
    sort: f.sort,
  ),
  _Priority(:final p) => TaskFilters(
    project: f.project,
    priority: p,
    assignee: f.assignee,
    sort: f.sort,
  ),
  _Assignee(:final name) => TaskFilters(
    project: f.project,
    priority: f.priority,
    assignee: name,
    sort: f.sort,
  ),
  final TaskSort s => TaskFilters(
    project: f.project,
    priority: f.priority,
    assignee: f.assignee,
    sort: s,
  ),
  _ => f,
};

/// An applied filter, shown under the status chips with a remove button.
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
    this.canReset = false,
    super.key,
  });

  final int count;
  final List<ActiveFilter> active;
  final VoidCallback onOpen;
  final VoidCallback onReset;

  /// Also true when only the status chip differs from "All".
  final bool canReset;

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
        if (canReset || on)
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
