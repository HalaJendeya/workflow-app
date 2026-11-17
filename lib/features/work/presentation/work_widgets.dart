import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// View / Edit / Delete tinted actions used by task and timesheet records.
class TintedActions extends StatelessWidget {
  const new({required this.onView, this.onEdit, this.onDelete, super.key});

  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget b(String label, Color bg, Color fg, VoidCallback onTap, Key key) =>
        Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Text(
                label,
                style: AppTextStyles.mobileXsSemiBold.copyWith(color: fg),
              ),
            ),
          ),
        );
    return Wrap(
      spacing: 8,
      children: [
        b(
          l10n.view,
          ModuleColors.warningBg,
          ModuleColors.warningFg,
          onView,
          const Key('action-view'),
        ),
        if (onEdit != null)
          b(
            l10n.edit,
            ModuleColors.successBg,
            ModuleColors.successFg,
            onEdit!,
            const Key('action-edit'),
          ),
        if (onDelete != null)
          b(
            l10n.delete,
            ModuleColors.dangerBg,
            ModuleColors.dangerFg,
            onDelete!,
            const Key('action-delete'),
          ),
      ],
    );
  }
}

/// A task in a list: only what tells the employee what the work is — the
/// title with its status at the top end, up to two lines of description
/// (when the task has one) and the due date (when it has one). Everything
/// else (code, sprint, project, priority, time, points) is in the details,
/// which a tap on the card opens; there are no actions on the card.
class TaskCard extends StatelessWidget {
  const new({
    required this.title,
    required this.status,
    required this.onOpen,
    this.description,
    this.due,
    super.key,
  });

  final String title;

  /// The status badge.
  final Widget status;

  /// Shown as written, two lines at most; nothing is shown without one.
  final String? description;

  /// A formatted due date; null when the task has none.
  final String? due;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button + 4),
        side: BorderSide(color: ModuleColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        hint: l10n.openTaskHint,
        child: InkWell(
          key: const Key('action-view'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ContentText(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mobileBaseSemiBold.copyWith(
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    status,
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ContentText(
                    description!,
                    key: const Key('task-description'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mobileXsRegular.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ],
                if (due != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    key: const Key('task-due'),
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(child: Text(l10n.dueOn(due!), style: secondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Priority as a small badge (shared by task cards and Kanban cards).
BadgeTone priorityTone(TaskPriority p) => switch (p) {
  TaskPriority.urgent => BadgeTone.danger,
  TaskPriority.high => BadgeTone.warning,
  TaskPriority.medium => BadgeTone.neutral,
  TaskPriority.low => BadgeTone.info,
};

/// "Showing x–y of n" with numbered pages.
class Pager extends StatelessWidget {
  const new({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
    super.key,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = (total / pageSize).ceil().clamp(1, 999);
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.showingRange(from, to, total),
          style: AppTextStyles.mobileXsRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < pages; i++)
              ChoiceChip(
                label: Text('${i + 1}'),
                selected: i == page,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: AppTextStyles.mobileXsSemiBold.copyWith(
                  color: i == page ? AppColors.white : AppColors.textPrimary,
                ),
                shape: const StadiumBorder(),
                onSelected: (_) => onPage(i),
              ),
          ],
        ),
      ],
    );
  }
}
