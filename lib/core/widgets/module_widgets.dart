import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/features/shell/workspace_header.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// SVG exported from Figma into `assets/icons/<name>.svg`.
class WfSvg extends StatelessWidget {
  const new(this.name, {this.size, this.color, super.key});

  final String name;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

/// Extra tokens used by the module frames (Payments, Invoices, Projects…).
abstract final class ModuleColors {
  static const successBg = Color(0xFFEDF7EE);
  static const successFg = Color(0xFF367C39);
  static const warningBg = Color(0xFFFFFDEB);
  static const warningFg = Color(0xFF8C8120);
  static const dangerBg = Color(0xFFFEECEB);
  static const dangerFg = Color(0xFFAD3026);
  static const selectedChipBorder = Color(0xFFB0D3FE);
  static const chipBorder = Color(0xB3E1E1E1);
  static const muted = Color(0xFF9E9E9E);
  static const sectionDivider = Color(0xFFF1F5F9);
  static const pillBorder = Color(0xCCE2E8F0);
  static const activePill = Color(0xFF0166E6);
  static const activePillCount = Color(0xFF559FFE);
  static const chartYellow = Color(0xFFE8D636);

  // Employee dashboard (731:47939) icon tiles and accents.
  static const tintTeal = Color(0xFFF0FDFA);
  static const tintPurple = Color(0xFFFAF5FF);
  static const chartCyan = Color(0xFF38BDF8);
  static const chartAmber = Color(0xFFFBBF24);
  static const chartMuted = Color(0xFFCBD5E1);
  static const chartTrack = Color(0xFFE2E8F0);
}

/// Scrollable page under a solid `action/primary` masthead (Figma
/// "Mobile masthead" 292 px on Categories, Companies, Payments, Invoices,
/// Projects…). [children] are laid out 20 px apart with 24/20/40 padding.
class ModulePage extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.children,
    this.searchHint,
    this.onSearch,
    this.onCreate,
    this.createLabel,
    this.gap = 20,
    super.key,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onCreate;
  final String? createLabel;
  final double gap;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBackground,
    floatingActionButton: onCreate == null
        ? null
        : Padding(
            // 96 px above the shell's 103 px navigation surface, which
            // grows by the system navigation bar; 0 outside the shell.
            padding: EdgeInsets.only(
              bottom: math.max(0, MediaQuery.paddingOf(context).bottom - 7),
            ),
            child: CreateFab(onPressed: onCreate!, label: createLabel),
          ),
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ModuleMasthead(
            title: title,
            description: description,
            searchHint: searchHint,
            onSearch: onSearch,
          ),
        ),
        SliverPadding(
          // Clears the floating navigation surface the shell reports in
          // `padding.bottom` (103 px, plus any system navigation bar), with
          // the same 47 px breathing room as before.
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            47 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.list(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ModuleMasthead extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    this.searchHint,
    this.onSearch,
    super.key,
  });

  final String title;
  final String description;
  final String? searchHint;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    const white = AppColors.white;
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.masthead),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkspaceHeader(),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (canPop) ...[
                    IconButton(
                      key: const Key('masthead-back'),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_forward
                            : Icons.arrow_back,
                        color: white,
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.mobile5xlBold.copyWith(color: white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: AppTextStyles.mobileBaseRegular.copyWith(color: white),
              ),
              if (onSearch != null) ...[
                const SizedBox(height: 20),
                WfSearchBox(
                  hint: searchHint ?? AppLocalizations.of(context).searchHint,
                  onChanged: onSearch!,
                  radius: AppRadii.input,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// White search field: 48 px, 14 px padding, Iconly search 20 px.
class WfSearchBox extends StatelessWidget {
  const new({
    required this.hint,
    required this.onChanged,
    this.radius = 12,
    this.fieldKey,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double radius;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ModuleColors.chipBorder),
    ),
    child: Row(
      children: [
        const SvgIcon(AppIcon.search, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: fieldKey,
            onChanged: onChanged,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppTextStyles.mobileBaseRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Metric card": title 14 SemiBold, value 20 Bold, green/red delta label.
class MetricCard extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.delta,
    this.negative = false,
    super.key,
  });

  final String title;
  final String value;
  final String delta;
  final bool negative;

  @override
  Widget build(BuildContext context) => ModuleCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.mobileBaseSemiBold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: AppTextStyles.mobile2xlSemiBold.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        StatusBadge(
          label: delta,
          tone: negative ? BadgeTone.danger : BadgeTone.success,
          radius: 6,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ],
    ),
  );
}

/// White card with 20 px radius and the 70 % #E1E1E1 stroke.
class ModuleCard extends StatelessWidget {
  const new({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: ModuleColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

enum BadgeTone { success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  const new({
    required this.label,
    required this.tone,
    this.radius = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    super.key,
  });

  final String label;
  final BadgeTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (ModuleColors.successBg, ModuleColors.successFg),
      BadgeTone.warning => (ModuleColors.warningBg, ModuleColors.warningFg),
      BadgeTone.danger => (ModuleColors.dangerBg, ModuleColors.dangerFg),
      BadgeTone.info => (AppColors.statusInfoBackground, AppColors.statusInfo),
      BadgeTone.neutral => (AppColors.surfaceSubtle, AppColors.textSecondary),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: AppTextStyles.mobileXsSemiBold.copyWith(color: fg),
      ),
    );
  }
}

/// Rounded-rect "Filter" chip (r12, 8/12 padding, 12 SemiBold). Selected
/// chips use the light-blue fill with the #B0D3FE stroke.
class FilterChipBox extends StatelessWidget {
  const new({
    required this.label,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.primary50 : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? ModuleColors.selectedChipBorder
              : ModuleColors.chipBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: AppTextStyles.mobileXsSemiBold.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A [FilterChipBox] showing "Label ⌄" that opens a bottom sheet of options.
class DropdownChip<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => FilterChipBox(
    label: '${labelOf(value)} ⌄',
    onTap: () async {
      final picked = await showOptionSheet<T>(
        context,
        options: options,
        labelOf: labelOf,
        selected: value,
      );
      if (picked != null) onChanged(picked);
    },
  );
}

/// Bottom sheet listing [options] with a check on [selected]. The list
/// scrolls inside the sheet, so long option lists never overflow a small
/// phone. [extra] tiles (e.g. "View details") follow the options.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  String? title,
  Key Function(T)? keyOf,
  List<Widget> Function(BuildContext sheet) extra = _noExtra,
}) => showModalBottomSheet<T>(
  context: context,
  // Above the shell's floating navigation surface, which would otherwise
  // cover the last options and take their taps.
  useRootNavigator: true,
  builder: (sheet) => SafeArea(
    child: ListView(
      key: const Key('option-sheet'),
      shrinkWrap: true,
      children: [
        if (title != null)
          ListTile(
            title: Text(
              title,
              style: AppTextStyles.mobileLgSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        for (final o in options)
          ListTile(
            key: keyOf?.call(o),
            title: Text(labelOf(o), style: AppTextStyles.mobileBaseRegular),
            trailing: o == selected
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () => Navigator.of(sheet).pop(o),
          ),
        ...extra(sheet),
      ],
    ),
  ),
);

List<Widget> _noExtra(BuildContext _) => const [];

/// Horizontal wrap of chips, 8 px apart.
class ChipRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class DetailField {
  const new(this.label, this.value);
  final String label;
  final String value;
}

/// "Content card" record: blue reference + status, big amount, subtitle,
/// two-column details, then "View Details" with edit/delete actions.
class RecordCard extends StatelessWidget {
  const new({
    required this.reference,
    required this.title,
    required this.status,
    required this.tone,
    required this.fields,
    required this.onView,
    this.subtitle,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String reference;
  final String title;
  final String status;
  final BadgeTone tone;
  final String? subtitle;
  final List<DetailField> fields;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Field(fields[i])),
            const SizedBox(width: 16),
            Expanded(
              child: i + 1 < fields.length
                  ? _Field(fields[i + 1])
                  : const SizedBox(),
            ),
          ],
        ),
      );
    }
    return ModuleCard(
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reference,
                  style: AppTextStyles.mobileBaseSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: status, tone: tone),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.mobile2xlSemiBold.copyWith(
              fontSize: 22,
              height: 31 / 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 16),
            Text(
              subtitle!,
              style: AppTextStyles.mobileXsRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          for (final r in rows) ...[const SizedBox(height: 16), r],
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                onTap: onView,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l10n.viewDetails,
                    style: AppTextStyles.mobileXsSemiBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (onEdit != null)
                _ActionIcon('action_edit', l10n.edit, onEdit!),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                _ActionIcon('action_delete', l10n.delete, onDelete!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const new(this.field);
  final DetailField field;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        field.label,
        style: AppTextStyles.mobileXsRegular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        field.value,
        style: AppTextStyles.mobileBaseSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

class _ActionIcon extends StatelessWidget {
  const new(this.icon, this.tooltip, this.onTap);
  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    icon: SizedBox.square(dimension: 20, child: Center(child: WfSvg(icon))),
  );
}

/// "Create" FAB: 56 px primary circle inside a 6 px white ring with a
/// 0/4/12 primary@19 % shadow.
class CreateFab extends StatelessWidget {
  const new({required this.onPressed, this.label, super.key});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label ?? AppLocalizations.of(context).create,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('create-fab'),
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x300170FD),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const WfSvg('fab_plus', size: 16),
          ),
        ),
      ),
    ),
  );
}

/// Shown in API mode on screens whose backend contract is not final yet.
class BackendPendingNotice extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.statusInfoBackground,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Text(
      AppLocalizations.of(context).backendPending,
      style: AppTextStyles.mobileBaseRegular.copyWith(
        color: AppColors.statusInfo,
      ),
    ),
  );
}

/// Empty state used inside module lists.
class EmptyNotice extends StatelessWidget {
  const new({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.mobileBaseRegular.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Confirms a destructive local action.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteTitle),
      content: Text(l10n.deleteBody(what)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: ModuleColors.dangerFg),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}
