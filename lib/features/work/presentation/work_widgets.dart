import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// "Summary card" with a tinted 40 px icon tile (Tasks 729:24059 and
/// Timesheets 729:37832): radius 18, value 25 Bold, caption 12.
class IconMetricCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    this.caption = '',
    this.iconSize = 24,
    super.key,
  });

  final String icon;
  final Color tint;
  final String title;
  final String value;
  final String caption;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ModuleColors.chipBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: WfSvg(icon, size: iconSize),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: AppTextStyles.mobile5xlBold.copyWith(
            fontSize: 25,
            height: 35 / 25,
            color: AppColors.textPrimary,
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: AppTextStyles.mobileXsRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

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

/// "Record card" with title, subtitle, amount and stacked label/value rows.
class StackedRecordCard extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.rows,
    required this.actions,
    this.badge,
    super.key,
  });

  final String title;
  final String subtitle;
  final String amount;
  final List<(String, String)> rows;
  final Widget actions;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => ModuleCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.mobileLgSemiBold.copyWith(
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: AppTextStyles.mobileBaseRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (badge != null) ...[const SizedBox(height: 14), badge!],
        const SizedBox(height: 14),
        Text(
          amount,
          style: AppTextStyles.mobile2xlSemiBold.copyWith(
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 14),
        for (final (label, value) in rows) ...[
          Text(
            label,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        actions,
      ],
    ),
  );
}

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
