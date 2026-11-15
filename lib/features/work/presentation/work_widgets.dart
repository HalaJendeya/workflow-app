import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
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

/// One piece of task metadata: an icon and a short value. [label] names
/// it for screen readers (the icon stands in for it on screen).
class TaskMeta {
  const new(this.icon, this.label, this.value, {this.strong = false});

  final IconData icon;
  final String label;
  final String value;

  /// The figure the reader looks for first (cost, points).
  final bool strong;
}

/// A task in a list, content first: the title with its badge at the top
/// end, then identifier · sprint · project on one line, then icon-labelled
/// metadata that wraps only when it must, with compact edit/delete icons at
/// the end. Tapping the card opens the details.
///
/// Typically two or three rows (~110 px) instead of a label above every
/// value (~430 px).
class TaskCard extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onView,
    this.badge,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<TaskMeta> meta;
  final Widget? badge;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    Widget icon(IconData i, String tip, VoidCallback onTap, Key key, Color c) =>
        IconButton(
          key: key,
          tooltip: tip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: Icon(i, size: 20, color: c),
        );
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button + 4),
        side: BorderSide(color: ModuleColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('action-view'),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mobileBaseSemiBold.copyWith(
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 8), badge!],
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [for (final m in meta) _MetaItem(m)],
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    icon(
                      Icons.edit_outlined,
                      l10n.edit,
                      onEdit!,
                      const Key('action-edit'),
                      AppColors.textSecondary,
                    ),
                  if (onDelete != null)
                    icon(
                      Icons.delete_outline,
                      l10n.delete,
                      onDelete!,
                      const Key('action-delete'),
                      ModuleColors.dangerFg,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const new(this.meta);

  final TaskMeta meta;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${meta.label}: ${meta.value}',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(meta.icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            meta.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (meta.strong
                        ? AppTextStyles.mobileXsSemiBold
                        : AppTextStyles.mobileXsRegular)
                    .copyWith(
                      color: meta.strong
                          ? AppColors.neutral900
                          : AppColors.textPrimary,
                    ),
          ),
        ),
      ],
    ),
  );
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
