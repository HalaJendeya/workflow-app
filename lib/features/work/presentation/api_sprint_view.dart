import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/kanban_drag.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Board columns: the kanban statuses minus backlog, which has its own tab.
const List<ApiTaskStatus> _columns = [
  ApiTaskStatus.todo,
  ApiTaskStatus.inProgress,
  ApiTaskStatus.inReview,
  ApiTaskStatus.completed,
];

String apiTaskStatusLabel(AppLocalizations l10n, ApiTaskStatus s) =>
    switch (s) {
      ApiTaskStatus.backlog => l10n.backlog,
      ApiTaskStatus.todo => l10n.toDo,
      ApiTaskStatus.pending => l10n.statusPending,
      ApiTaskStatus.inProgress => l10n.statusInProgress,
      ApiTaskStatus.inReview => l10n.inReview,
      ApiTaskStatus.completed => l10n.statusCompleted,
      ApiTaskStatus.other => '—',
    };

(Color, Color) _columnColors(ApiTaskStatus s) => switch (s) {
  ApiTaskStatus.inProgress => (ModuleColors.warningBg, const Color(0xFFFFF9C2)),
  ApiTaskStatus.completed => (ModuleColors.successBg, const Color(0xFFD5EED7)),
  _ => (AppColors.surfaceSubtle, AppColors.borderSubtle),
};

(Color, Color) _priorityColors(TaskPriority p) => switch (p) {
  TaskPriority.urgent => (ModuleColors.dangerBg, ModuleColors.dangerFg),
  TaskPriority.high => (ModuleColors.warningBg, const Color(0xFFAD3026)),
  TaskPriority.medium => (AppColors.surfaceSubtle, AppColors.textPrimary),
  TaskPriority.low => (AppColors.primary50, AppColors.primary),
};

/// "Sprint & Backlog" (729:24447) from `GET /employee/kanban` and
/// `GET /employee/sprints`. Moving a card calls
/// `POST /employee/kanban/update-status`.
class ApiSprintView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ApiSprintView> createState() => _ApiSprintViewState();
}

class _ApiSprintViewState extends ConsumerState<ApiSprintView>
    with KanbanDropBarHost {
  bool _kanban = true;
  ApiTaskStatus _column = ApiTaskStatus.inProgress;
  int? _projectId;
  String _query = '';

  /// Moves sent to the server and not yet confirmed, by task id. The card
  /// is shown in its destination with a spinner meanwhile; a second move
  /// of the same task is refused until this one settles.
  final Map<int, ApiTaskStatus> _pending = {};

  /// Whether [t] may be moved to [target]: a documented kanban status other
  /// than its current one, a task the server lets the user update, and no
  /// move already in flight. The server still decides (leader/assignee
  /// rules) and its refusal is shown as is.
  bool _canMove(ApiTask t, ApiTaskStatus target) =>
      kanbanStatuses.contains(target) &&
      target != (_pending[t.id] ?? t.status) &&
      t.canUpdate != false &&
      !_pending.containsKey(t.id);

  Future<void> _move(ApiTask t, ApiTaskStatus target) async {
    if (!_canMove(t, target)) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _pending[t.id] = target);
    try {
      await ref.read(boardRepositoryProvider).updateStatus(t.id, target);
      if (!mounted) return;
      showSnack(context, l10n.taskStatusUpdated);
      // Reconcile with the server before dropping the local placement.
      ref
        ..invalidate(kanbanProvider(_projectId))
        // Every backlog page, whichever project key it was read with.
        ..invalidate(planningProvider);
      try {
        await ref.read(kanbanProvider(_projectId).future);
      } on Object {
        // The board shows its own error and retry.
      }
    } on Object catch (e) {
      // The card returns to where it was; the server's reason is shown.
      if (mounted) showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _pending.remove(t.id));
    }
  }

  Future<void> _chooseMove(ApiTask t) async {
    final l10n = AppLocalizations.of(context);
    final target = await showOptionSheet<ApiTaskStatus>(
      context,
      title: l10n.moveTo,
      options: kanbanStatuses,
      labelOf: (c) => apiTaskStatusLabel(l10n, c),
      selected: _pending[t.id] ?? t.status,
      keyOf: (c) => Key('move-${c.name}'),
    );
    if (target != null && mounted) await _move(t, target);
  }

  Widget _board(KanbanBoard b, bool Function(ApiTask) matches) => _Board(
    board: b,
    column: _column,
    matches: matches,
    pending: _pending,
    onColumn: (c) => setState(() => _column = c),
    onTapTask: _chooseMove,
    accepts: _canMove,
    onDrop: _move,
    onDragStarted: _startDrag,
    onDragEnd: hideDropBar,
  );

  void _startDrag(ApiTask t) {
    final l10n = AppLocalizations.of(context);
    showDropBar(
      (_) => KanbanDropBar<ApiTask, ApiTaskStatus>(
        title: l10n.moveTo,
        statuses: kanbanStatuses,
        labelOf: (c) => apiTaskStatusLabel(l10n, c),
        held: t,
        accepts: _canMove,
        onDrop: _move,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(kanbanProvider(_projectId));
    final projects = board.value?.projects ?? const <BoardProject>[];
    final selected = board.value?.selectedProjectId ?? _projectId;
    final projectTitle = projects
        .where((p) => p.id == selected)
        .map((p) => p.title)
        .firstOrNull;

    bool matches(ApiTask t) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty || '${t.title} #${t.id}'.toLowerCase().contains(q);
    }

    return ModulePage(
      title: l10n.sprintBacklog,
      description: l10n.sprintBacklogBody,
      onSearch: (v) => setState(() => _query = v),
      children: [
        ModuleCard(
          key: const Key('sprint-project'),
          onTap: projects.length < 2
              ? null
              : () async {
                  final picked = await showOptionSheet<int>(
                    context,
                    options: [for (final p in projects) p.id],
                    labelOf: (id) =>
                        projects.firstWhere((p) => p.id == id).title,
                    selected: selected,
                  );
                  if (picked != null) setState(() => _projectId = picked);
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
                projectTitle ?? '—',
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
                onTap: () => showSnack(context, l10n.sprintCreateUnavailable),
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
        if (_kanban)
          // While a move is being reconciled the board keeps its cards on
          // screen instead of flashing a spinner.
          if (board.hasValue && !board.hasError)
            _board(board.requireValue, matches)
          else
            AsyncSection(
              value: board,
              onRetry: () => ref.invalidate(kanbanProvider(_projectId)),
              builder: (b) => _board(b, matches),
            )
        else
          _Backlog(
            projectId: selected,
            matches: matches,
            pending: _pending,
            onTapTask: _chooseMove,
          ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const new({
    required this.board,
    required this.column,
    required this.matches,
    required this.pending,
    required this.onColumn,
    required this.onTapTask,
    required this.accepts,
    required this.onDrop,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  final KanbanBoard board;
  final ApiTaskStatus column;
  final bool Function(ApiTask) matches;
  final Map<int, ApiTaskStatus> pending;
  final ValueChanged<ApiTaskStatus> onColumn;
  final ValueChanged<ApiTask> onTapTask;
  final bool Function(ApiTask, ApiTaskStatus) accepts;
  final void Function(ApiTask, ApiTaskStatus) onDrop;
  final ValueChanged<ApiTask> onDragStarted;
  final VoidCallback onDragEnd;

  ApiTaskStatus _statusOf(ApiTask t) => pending[t.id] ?? t.status;

  /// The server's whole-sprint count, shifted by moves still pending.
  int _count(ApiTaskStatus c) {
    var n = board.byStatus[c] ?? board.tasks.where((t) => t.status == c).length;
    for (final t in board.tasks) {
      final to = pending[t.id];
      if (to == null) continue;
      if (t.status == c) n--;
      if (to == c) n++;
    }
    return n < 0 ? 0 : n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sprint = board.sprint;
    if (sprint == null) {
      return EmptyNotice(text: l10n.noActiveSprint);
    }
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    final date = DateFormat('yyyy-MM-dd', 'en');
    final inColumn = board.tasks
        .where((t) => _statusOf(t) == column && matches(t))
        .toList();
    final (bg, border) = _columnColors(column);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleCard(
          key: const Key('sprint-summary'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sprint.name,
                      style: AppTextStyles.mobileLgSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (board.daysRemaining != null)
                    StatusBadge(
                      label: l10n.daysLeft(board.daysRemaining!),
                      tone: BadgeTone.info,
                    ),
                ],
              ),
              if (sprint.goal?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(sprint.goal!, style: secondary),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  if (sprint.startDate != null) date.format(sprint.startDate!),
                  if (sprint.endDate != null) date.format(sprint.endDate!),
                ].join(' → '),
                style: secondary,
              ),
              if (board.pointsTotal != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.sprintPoints(
                    board.pointsDone ?? 0,
                    board.pointsTotal!,
                    board.percentDone ?? 0,
                  ),
                  style: AppTextStyles.mobileXsSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (board.percentDone ?? 0).clamp(0, 100) / 100,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: AppColors.surfaceSubtle,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
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
                  child: KanbanDropTarget<ApiTask, ApiTaskStatus>(
                    status: c,
                    accepts: accepts,
                    onDrop: onDrop,
                    builder: (context, {required hovering}) => InkWell(
                      key: Key('column-${c.name}'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onColumn(c),
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hovering
                              ? AppColors.primary50
                              : column == c
                              ? AppColors.primary50.withValues(alpha: 0.6)
                              : null,
                          border: hovering
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          apiTaskStatusLabel(l10n, c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.mobileXsMedium.copyWith(
                            color: column == c
                                ? AppColors.primaryStrong
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
                      Flexible(
                        child: Text(
                          apiTaskStatusLabel(l10n, column).toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.mobileXsSemiBold.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF233242),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        key: const Key('column-count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        // The whole-sprint count from stats, which can be
                        // larger than the cards when scope is "mine".
                        child: Text(
                          '${_count(column)}',
                          style: AppTextStyles.mobileXsMedium.copyWith(
                            color: const Color(0xFF3D4E60),
                          ),
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
                    style: secondary,
                  ),
                ),
              for (final t in inColumn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: KanbanDraggable<ApiTask>(
                    key: Key('drag-${t.id}'),
                    data: t,
                    enabled: t.canUpdate != false && !pending.containsKey(t.id),
                    onDragStarted: () => onDragStarted(t),
                    onDragEnd: onDragEnd,
                    child: ApiTaskCard(
                      task: t,
                      pending: pending.containsKey(t.id),
                      onTap: () => onTapTask(t),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Backlog extends ConsumerWidget {
  const new({
    required this.projectId,
    required this.matches,
    required this.pending,
    required this.onTapTask,
  });

  final int? projectId;
  final bool Function(ApiTask) matches;
  final Map<int, ApiTaskStatus> pending;
  final ValueChanged<ApiTask> onTapTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(planningProvider(projectId));
    return AsyncSection(
      value: value,
      onRetry: () => ref.invalidate(planningProvider(projectId)),
      builder: (p) {
        final rows = p.backlog.items.where(matches).toList();
        final total = p.backlogCount ?? p.backlog.total;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModuleCard(
              key: const Key('sprints-list'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sprintsCount(p.sprints.length),
                    style: AppTextStyles.mobileLgSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  for (final s in p.sprints) ...[
                    const SizedBox(height: 12),
                    Text(
                      s.name,
                      style: AppTextStyles.mobileBaseSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (s.pointsTotal != null)
                      Text(
                        l10n.sprintPoints(
                          s.pointsDone ?? 0,
                          s.pointsTotal!,
                          s.pointsTotal! == 0
                              ? 0
                              : ((s.pointsDone ?? 0) * 100 ~/ s.pointsTotal!),
                        ),
                        style: AppTextStyles.mobileXsRegular.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (rows.isEmpty) EmptyNotice(text: l10n.noRecords),
            for (final t in rows) ...[
              ApiTaskCard(
                task: t,
                pending: pending.containsKey(t.id),
                onTap: () => onTapTask(t),
              ),
              const SizedBox(height: 10),
            ],
            if (total > p.backlog.items.length)
              Text(
                l10n.backlogFirstPage(p.backlog.items.length, total),
                style: AppTextStyles.mobileXsRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A task card in the Figma kanban style. Tapping it offers the kanban
/// statuses (the accessible alternative to dragging); [pending] shows a
/// spinner while a move is being saved and disables the card.
class ApiTaskCard extends StatelessWidget {
  const new({
    required this.task,
    required this.onTap,
    this.pending = false,
    super.key,
  });

  final ApiTask task;
  final VoidCallback onTap;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = task;
    final canMove = t.canUpdate ?? true;
    final d = t.duration;
    return Material(
      key: Key('kanban-${t.id}'),
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ModuleColors.chipBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: pending || !canMove ? null : onTap,
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
                      [
                        '#${t.id}',
                        if (t.sprintName != null) t.sprintName!,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (t.storyPoints != null)
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
                        l10n.points(t.storyPoints!),
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
              const SizedBox(height: 8),
              const Divider(height: 1, color: ModuleColors.chipBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (t.priority case final p?) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _priorityColors(p).$1,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        priorityLabel(l10n, p).toUpperCase(),
                        style: AppTextStyles.mobileXsSemiBold.copyWith(
                          color: _priorityColors(p).$2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  if (d != null) ...[
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${(d.inMinutes / 60).toStringAsFixed(1)}h',
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (pending)
                    const SizedBox.square(
                      key: Key('kanban-pending'),
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (t.initials.isNotEmpty)
                    WfAvatar(initials: t.initials, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
