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

class _ApiSprintViewState extends ConsumerState<ApiSprintView> {
  bool _kanban = true;
  ApiTaskStatus _column = ApiTaskStatus.inProgress;
  int? _projectId;
  String _query = '';

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
                  final picked = await showModalBottomSheet<int>(
                    context: context,
                    builder: (s) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final p in projects)
                            ListTile(
                              title: Text(p.title),
                              trailing: p.id == selected
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(s, p.id),
                            ),
                        ],
                      ),
                    ),
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
          AsyncSection(
            value: board,
            onRetry: () => ref.invalidate(kanbanProvider(_projectId)),
            builder: (b) => _Board(
              board: b,
              column: _column,
              matches: matches,
              onColumn: (c) => setState(() => _column = c),
              onMoved: () => ref.invalidate(kanbanProvider(_projectId)),
            ),
          )
        else
          _Backlog(projectId: selected, matches: matches),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const new({
    required this.board,
    required this.column,
    required this.matches,
    required this.onColumn,
    required this.onMoved,
  });

  final KanbanBoard board;
  final ApiTaskStatus column;
  final bool Function(ApiTask) matches;
  final ValueChanged<ApiTaskStatus> onColumn;
  final VoidCallback onMoved;

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
        .where((t) => t.status == column && matches(t))
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
                  child: InkWell(
                    key: Key('column-${c.name}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onColumn(c),
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: column == c
                            ? AppColors.primary50.withValues(alpha: 0.6)
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
                          '${board.byStatus[column] ?? inColumn.length}',
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
                  child: ApiTaskCard(task: t, onMoved: onMoved),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Backlog extends ConsumerWidget {
  const new({required this.projectId, required this.matches});

  final int? projectId;
  final bool Function(ApiTask) matches;

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
                onMoved: () => ref.invalidate(planningProvider(projectId)),
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
/// statuses; a status change is sent to the server and the board reloads.
class ApiTaskCard extends ConsumerStatefulWidget {
  const new({required this.task, required this.onMoved, super.key});

  final ApiTask task;
  final VoidCallback onMoved;

  @override
  ConsumerState<ApiTaskCard> createState() => _ApiTaskCardState();
}

class _ApiTaskCardState extends ConsumerState<ApiTaskCard> {
  bool _busy = false;

  Future<void> _move() async {
    final l10n = AppLocalizations.of(context);
    final t = widget.task;
    final target = await showModalBottomSheet<ApiTaskStatus>(
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
            for (final c in kanbanStatuses)
              ListTile(
                key: Key('move-${c.name}'),
                title: Text(apiTaskStatusLabel(l10n, c)),
                trailing: c == t.status
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(s, c),
              ),
          ],
        ),
      ),
    );
    if (target == null || target == t.status || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(boardRepositoryProvider).updateStatus(t.id, target);
      if (!mounted) return;
      showSnack(context, l10n.taskStatusUpdated);
      widget.onMoved();
    } on Object catch (e) {
      if (mounted) showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = widget.task;
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
        onTap: _busy || !canMove ? null : _move,
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
                  if (_busy)
                    const SizedBox.square(
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
