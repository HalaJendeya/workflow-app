import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Opens the full details of a demo task above the shell (back returns to
/// where the task was tapped).
Future<void> openTaskDetails(BuildContext context, WorkTask task) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoTaskDetailsScreen(taskId: task.id),
      ),
    );

/// Opens the full details of a task row from the API.
Future<void> openApiTaskDetails(BuildContext context, ApiTask task) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => ApiTaskDetailsScreen(row: task)),
    );

final _day = DateFormat('yyyy/MM/dd', 'en');
final _time = DateFormat('HH:mm', 'en');

/// Day and time as figures that keep their order in Arabic.
String _at(DateTime d) => ltrIsolate('${_day.format(d)} ${_time.format(d)}');

/// One entry of the task's action menu.
class TaskAction {
  const new({
    required this.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

/// A titled group of label/value rows.
typedef TaskSection = ({String title, List<DetailField> fields});

/// The details page both modes share: title, status and the full
/// description first, then the sections the task has data for. Actions
/// the user may take sit in the top-end menu (edit, delete) and under the
/// status (change status); none is shown without permission.
class TaskDetailsView extends StatelessWidget {
  const new({
    required this.title,
    required this.status,
    required this.sections,
    this.description,
    this.subtasks,
    this.actions = const [],
    this.onChangeStatus,
    this.changingStatus = false,
    this.notice,
    super.key,
  });

  final String title;
  final Widget status;
  final String? description;
  final List<TaskSection> sections;

  /// Done and total subtasks, when the task has any.
  final (int, int)? subtasks;
  final List<TaskAction> actions;

  /// Null hides "Change status" (no permission or no route).
  final VoidCallback? onChangeStatus;
  final bool changingStatus;

  /// A message above the content (e.g. a failed refresh with a retry).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = AppTextStyles.mobileXsSemiBold.copyWith(
      color: AppColors.textSecondary,
      letterSpacing: 0.3,
    );
    return Scaffold(
      key: const Key('task-details'),
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed: back and the actions stay in reach however far the
            // details scroll.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('task-details-back'),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const BackButtonIcon(),
                    color: AppColors.textPrimary,
                  ),
                  Expanded(
                    child: Text(
                      l10n.taskDetails,
                      style: AppTextStyles.mobileLgSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty)
                    PopupMenuButton<TaskAction>(
                      key: const Key('task-actions'),
                      tooltip: l10n.taskActions,
                      icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
                      onSelected: (a) => a.onSelected(),
                      itemBuilder: (_) => [
                        for (final a in actions)
                          PopupMenuItem(
                            key: a.key,
                            value: a,
                            child: Row(
                              children: [
                                Icon(
                                  a.icon,
                                  size: 20,
                                  color: a.destructive
                                      ? ModuleColors.dangerFg
                                      : AppColors.textPrimary,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Text(
                                  a.label,
                                  style: AppTextStyles.mobileBaseRegular
                                      .copyWith(
                                        color: a.destructive
                                            ? ModuleColors.dangerFg
                                            : AppColors.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  if (notice != null) ...[
                    notice!,
                    const SizedBox(height: AppSpacing.md),
                  ],
                  ModuleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          key: const Key('task-details-title'),
                          style: AppTextStyles.mobileLgSemiBold.copyWith(
                            color: AppColors.neutral900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            status,
                            if (changingStatus)
                              const SizedBox(
                                key: Key('task-status-pending'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (onChangeStatus != null)
                              TextButton.icon(
                                key: const Key('task-change-status'),
                                onPressed: onChangeStatus,
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                label: Text(l10n.changeStatus),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(l10n.description.toUpperCase(), style: heading),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          description ?? l10n.noDescription,
                          key: const Key('task-details-description'),
                          style: AppTextStyles.mobileBaseRegular.copyWith(
                            color: description == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subtasks case (final done, final total)) ...[
                    const SizedBox(height: AppSpacing.md),
                    ModuleCard(
                      key: const Key('task-details-subtasks'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.subtasks.toUpperCase(), style: heading),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.subtasksProgress(done, total),
                            style: AppTextStyles.mobileBaseRegular.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : done / total,
                              minHeight: 6,
                              color: AppColors.primary,
                              backgroundColor: AppColors.surfaceSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  for (final s in sections)
                    if (s.fields.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      ModuleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.title.toUpperCase(), style: heading),
                            for (final f in s.fields) _FieldRow(field: f),
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label at the start, value at the end; a long value wraps under its
/// label instead of squeezing it.
class _FieldRow extends StatelessWidget {
  const new({required this.field});

  final DetailField field;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm + 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: AppSpacing.md,
      runSpacing: 2,
      children: [
        Text(
          field.label,
          style: AppTextStyles.mobileXsRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          field.value,
          style: AppTextStyles.mobileXsSemiBold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// A demo task. Demo mode grants every action; edits stay on the device.
/// The task's cost is not shown: employees never receive it from the API.
class DemoTaskDetailsScreen extends ConsumerWidget {
  const new({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref
        .watch(workTasksProvider)
        .where((t) => t.id == taskId)
        .firstOrNull;
    // Deleted (or never there): nothing left to show.
    if (t == null) {
      return const Scaffold(key: Key('task-details-gone'));
    }
    final notifier = ref.read(workTasksProvider.notifier);
    return TaskDetailsView(
      title: t.title,
      status: StatusBadge(
        key: const Key('task-details-status'),
        label: taskStatusLabel(l10n, t.status),
        tone: taskStatusTone(t.status),
      ),
      description: t.description,
      subtasks: t.subtasksTotal > 0 ? (t.subtasksDone, t.subtasksTotal) : null,
      onChangeStatus: () async {
        final target = await showOptionSheet<TaskStatus>(
          context,
          title: l10n.changeStatus,
          options: TaskStatus.values,
          labelOf: (s) => taskStatusLabel(l10n, s),
          selected: t.status,
          keyOf: (s) => Key('status-${s.name}'),
        );
        if (target == null || target == t.status) return;
        final applied = notifier.replace(t.copyWith(status: target));
        if (context.mounted) {
          showSnack(
            context,
            applied ? l10n.taskStatusUpdated : l10n.actionNeedsBackend,
          );
        }
      },
      actions: [
        TaskAction(
          key: const Key('action-edit'),
          label: l10n.edit,
          icon: Icons.edit_outlined,
          onSelected: () => openTaskForm(context, existing: t),
        ),
        TaskAction(
          key: const Key('action-delete'),
          label: l10n.delete,
          icon: Icons.delete_outline,
          destructive: true,
          onSelected: () async {
            if (!await confirmDelete(context, t.code)) return;
            final removed = notifier.remove(t.id);
            if (!context.mounted) return;
            showLocalOutcome(context, applied: removed, deleted: true);
            if (removed) Navigator.of(context).pop();
          },
        ),
      ],
      sections: [
        (
          title: l10n.workDetails,
          fields: [
            DetailField(l10n.taskCode, t.code),
            DetailField(l10n.fieldProject, t.project),
            DetailField(l10n.fieldSprint, t.sprint),
            DetailField(l10n.priority, priorityLabel(l10n, t.priority)),
            DetailField(l10n.assignee, t.assignee),
            DetailField(l10n.storyPoints, l10n.points(t.points)),
          ],
        ),
        (
          title: l10n.scheduleAndTime,
          fields: [
            if (t.due case final due?)
              DetailField(l10n.dueDate, ltrIsolate(_day.format(due))),
            DetailField(l10n.startDate, _at(t.start)),
            DetailField(l10n.endDate, _at(t.end)),
            DetailField(l10n.duration, durationLabel(t.duration)),
          ],
        ),
      ],
    );
  }
}

/// A task from `GET /employee/tasks`. The list row shows at once; the
/// task is then read again from `GET /employee/tasks/{task}`. If that
/// fails, the row stays on screen with a notice and a retry.
///
/// Only fields the server sent are listed. The API has no due date (the
/// collection: `task_date` is the planned work date), no subtasks,
/// attachments or comments for tasks, and gives employees no cost.
/// Status changes use `POST /employee/kanban/update-status`, offered only
/// when the task says `can.update: true`; edit and delete have no
/// employee form or route in the app, so the menu is not shown.
class ApiTaskDetailsScreen extends ConsumerStatefulWidget {
  const new({required this.row, super.key});

  final ApiTask row;

  @override
  ConsumerState<ApiTaskDetailsScreen> createState() =>
      _ApiTaskDetailsScreenState();
}

class _ApiTaskDetailsScreenState extends ConsumerState<ApiTaskDetailsScreen> {
  bool _changing = false;

  Future<void> _changeStatus(ApiTask t) async {
    final l10n = AppLocalizations.of(context);
    final target = await showOptionSheet<ApiTaskStatus>(
      context,
      title: l10n.changeStatus,
      options: kanbanStatuses,
      labelOf: (s) => apiTaskStatusLabel(l10n, s),
      selected: t.status,
      keyOf: (s) => Key('status-${s.name}'),
    );
    if (target == null || target == t.status || !mounted) return;
    setState(() => _changing = true);
    try {
      await ref.read(boardRepositoryProvider).updateStatus(t.id, target);
      ref
        ..invalidate(apiTaskProvider(t.id))
        ..invalidate(apiTasksProvider)
        ..invalidate(scopedTaskStatsProvider)
        ..invalidate(kanbanProvider);
      if (mounted) showSnack(context, l10n.taskStatusUpdated);
    } on Object catch (e) {
      // A refusal (403, 409, 422) is shown as the server worded it; the
      // status on screen stays what the server last said.
      if (mounted) showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiTaskProvider(widget.row.id));
    final t = value.value ?? widget.row;
    final failed = value.hasError && !value.isLoading;
    return TaskDetailsView(
      title: t.title,
      status: StatusBadge(
        key: const Key('task-details-status'),
        label: t.status == ApiTaskStatus.other && t.rawStatus.isNotEmpty
            ? t.rawStatus
            : apiTaskStatusLabel(l10n, t.status),
        tone: apiTaskStatusTone(t.status),
      ),
      description: t.description,
      notice: failed
          ? ModuleCard(
              key: const Key('task-details-stale'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.taskDetailsStale,
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(apiTaskProvider(widget.row.id)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : null,
      changingStatus: _changing,
      onChangeStatus: t.canUpdate == true ? () => _changeStatus(t) : null,
      sections: [
        (
          title: l10n.workDetails,
          fields: [
            DetailField(l10n.taskCode, ltrIsolate('#${t.id}')),
            if (t.projectTitle case final p?) DetailField(l10n.fieldProject, p),
            if (t.sprintName case final s?) DetailField(l10n.fieldSprint, s),
            if (t.priority case final p?)
              DetailField(l10n.priority, priorityLabel(l10n, p)),
            if (t.assigneeName case final a?) DetailField(l10n.assignee, a),
            if (t.storyPoints case final p?)
              DetailField(l10n.storyPoints, l10n.points(p)),
          ],
        ),
        (
          title: l10n.scheduleAndTime,
          fields: [
            if (t.taskDate case final d?)
              DetailField(l10n.taskDate, ltrIsolate(_day.format(d))),
            if (t.start case final s?)
              DetailField(l10n.startDate, ltrIsolate(_time.format(s))),
            if (t.end case final e?)
              DetailField(l10n.endDate, ltrIsolate(_time.format(e))),
            if (t.duration case final d?)
              DetailField(l10n.duration, durationLabel(d)),
          ],
        ),
      ],
    );
  }
}
