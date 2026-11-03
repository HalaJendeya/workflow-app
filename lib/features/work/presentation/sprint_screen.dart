import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

const List<TaskStatus> _columns = [
  TaskStatus.todo,
  TaskStatus.inProgress,
  TaskStatus.completed,
];

/// Column tints: in progress uses the Figma #FFFDEB/#FFF9C2 pair; the other
/// columns reuse the same pattern with the neutral and success tokens.
(Color, Color) _columnColors(TaskStatus s) => switch (s) {
  TaskStatus.inProgress => (ModuleColors.warningBg, const Color(0xFFFFF9C2)),
  TaskStatus.completed => (ModuleColors.successBg, const Color(0xFFD5EED7)),
  _ => (AppColors.surfaceSubtle, AppColors.borderSubtle),
};

(Color, Color) _priorityColors(TaskPriority p) => switch (p) {
  TaskPriority.urgent => (ModuleColors.dangerBg, ModuleColors.dangerFg),
  TaskPriority.high => (ModuleColors.warningBg, const Color(0xFFAD3026)),
  TaskPriority.medium => (AppColors.surfaceSubtle, AppColors.textPrimary),
  TaskPriority.low => (AppColors.primary50, AppColors.primary),
};

/// Figma "Sprint & Backlog" (729:24447).
class SprintScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SprintScreen> createState() => _SprintScreenState();
}

class _SprintScreenState extends ConsumerState<SprintScreen> {
  bool _kanban = true;
  TaskStatus _column = TaskStatus.inProgress;
  String _query = '';
  String _project = workProjects.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final q = _query.trim().toLowerCase();
    final all = ref
        .watch(workTasksProvider)
        .where(
          (t) => q.isEmpty || '${t.title} ${t.code}'.toLowerCase().contains(q),
        )
        .toList();
    final inColumn = all
        .where((t) => t.status == _column && t.project == _project)
        .toList();
    final backlog = all.where((t) => t.status == TaskStatus.backlog).toList();
    final (bg, border) = _columnColors(_column);

    return ModulePage(
      title: l10n.sprintBacklog,
      description: l10n.sprintBacklogBody,
      onSearch: (v) => setState(() => _query = v),
      onCreate: () => openTaskForm(context),
      createLabel: l10n.addTask,
      children: [
        if (!demo) const BackendPendingNotice(),
        ModuleCard(
          onTap: () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              builder: (s) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in workProjects)
                      ListTile(
                        title: Text(p),
                        trailing: p == _project
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(s, p),
                      ),
                  ],
                ),
              ),
            );
            if (picked != null) setState(() => _project = picked);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.fieldProject,
                style: AppTextStyles.mobileXsRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _project,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral900,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  WfFilterPill(
                    label: l10n.kanban,
                    selected: _kanban,
                    onTap: () => setState(() => _kanban = true),
                  ),
                  WfFilterPill(
                    label: l10n.backlog,
                    selected: !_kanban,
                    onTap: () => setState(() => _kanban = false),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: const Key('create-sprint'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _createSprint(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Text(
                    l10n.createSprint,
                    style: AppTextStyles.mobileXsSemiBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_kanban) ...[
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final c in _columns)
                  Expanded(
                    child: InkWell(
                      key: Key('column-${c.name}'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _column = c),
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _column == c
                              ? AppColors.primary50.withValues(alpha: 0.6)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          taskStatusLabel(l10n, c),
                          style: AppTextStyles.mobileXsMedium.copyWith(
                            color: _column == c
                                ? AppColors.primaryStrong
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFA5B4C3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          taskStatusLabel(l10n, _column).toUpperCase(),
                          style: AppTextStyles.mobileXsSemiBold.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF233242),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${inColumn.length}',
                            style: AppTextStyles.mobileXsMedium.copyWith(
                              color: const Color(0xFF3D4E60),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: l10n.addTask,
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TaskFormScreen(initialStatus: _column),
                                ),
                              ),
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Color(0xFFA5B4C3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (inColumn.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.noTasksInColumn,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                for (final t in inColumn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _KanbanCard(task: t),
                  ),
              ],
            ),
          ),
        ] else ...[
          if (backlog.isEmpty) EmptyNotice(text: l10n.noRecords),
          for (final t in backlog) _KanbanCard(task: t),
        ],
      ],
    );
  }

  Future<void> _createSprint(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.createSprint),
        content: TextField(
          key: const Key('sprint-name'),
          controller: name,
          decoration: InputDecoration(hintText: l10n.sprintName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, name.text.trim().isNotEmpty),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    name.dispose();
    if ((ok ?? false) && context.mounted) showSnack(context, l10n.savedLocally);
  }
}

class _KanbanCard extends ConsumerWidget {
  const new({required this.task});

  final WorkTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = task;
    final (pbg, pfg) = _priorityColors(t.priority);
    return Material(
      key: Key('kanban-${t.id}'),
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ModuleColors.chipBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _move(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: Color(0xFFA5B4C3),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.code,
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.points(t.points),
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.title,
                style: AppTextStyles.mobileBaseSemiBold.copyWith(
                  color: const Color(0xFF233242),
                ),
              ),
              if (t.subtasksTotal > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.subtasksDone(t.subtasksDone, t.subtasksTotal),
                        style: AppTextStyles.mobileXsRegular.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${(t.progress * 100).round()}%',
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: t.progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: AppColors.surfaceSubtle,
                  color: AppColors.primary,
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1, color: ModuleColors.chipBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: pbg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      priorityLabel(l10n, t.priority).toUpperCase(),
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: pfg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${(t.duration.inMinutes / 60).toStringAsFixed(1)}h',
                    style: AppTextStyles.mobileXsRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  WfAvatar(initials: t.initials, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final target = await showModalBottomSheet<TaskStatus>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.moveTo,
                style: AppTextStyles.mobileLgSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            for (final c in TaskStatus.values)
              ListTile(
                key: Key('move-${c.name}'),
                title: Text(taskStatusLabel(l10n, c)),
                trailing: c == task.status
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(s, c),
              ),
            ListTile(
              title: Text(l10n.viewDetails),
              onTap: () {
                Navigator.pop(s);
                showTaskDetails(context, task);
              },
            ),
          ],
        ),
      ),
    );
    if (target != null && target != task.status) {
      ref
          .read(workTasksProvider.notifier)
          .replace(task.copyWith(status: target));
      if (context.mounted) showSnack(context, l10n.savedLocally);
    }
  }
}
