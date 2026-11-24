import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// The list-filter pattern approved on Employee Tasks (94975ae, e132ba9),
/// shared so every role's lists look and behave alike:
///
/// * search stays in the masthead (one field per screen);
/// * a "Filters (n)" button opens one sheet holding every filter and the
///   sort; choices are drafted and applied together with "Show results",
///   so several choices send one request and dismissing sends none;
/// * the applied filters show beside the button as removable chips, with
///   "Reset filters" while anything differs from the defaults;
/// * an action on the filtered list (Export) sits right after the button.

/// An applied filter, shown beside the Filters button with a remove button.
class ActiveFilter {
  const new(this.key, this.label, this.onRemove);
  final String key;
  final String label;
  final VoidCallback onRemove;
}

/// "Filters (n)" button, [trailing] (Export), the applied filters as
/// removable chips, and "Reset filters" when [count] is not zero.
class FilterBar extends StatelessWidget {
  const new({
    required this.count,
    required this.active,
    required this.onOpen,
    required this.onReset,
    this.trailing,
    this.buttonKey = const Key('filters'),
    this.resetKey = const Key('reset-filters'),
    super.key,
  });

  final int count;
  final List<ActiveFilter> active;
  final VoidCallback onOpen;
  final VoidCallback onReset;

  /// An action on the filtered list (Export CSV), right after the Filters
  /// button so it keeps its place whatever filters are active.
  final Widget? trailing;
  final Key buttonKey;
  final Key resetKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final on = count > 0;
    return Wrap(
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
              key: buttonKey,
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
        ?trailing,
        for (final f in active)
          _ActiveChip(key: Key('active-filter-${f.key}'), filter: f),
        if (on)
          TextButton(
            key: resetKey,
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

/// A titled group of choices inside a filter sheet.
class FilterSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
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
        ChipRow(children: children),
      ],
    ),
  );
}

/// One sheet for every filter of a list. [sections] is built from the
/// draft; `setDraft` changes it. Returns the draft on "Show results",
/// `null` when dismissed (the list stays as it was). "Reset filters" sets
/// the draft back to `defaults` without closing.
///
/// [id] names the keys: `<id>-filter-sheet`, `<id>-filters-apply`,
/// `<id>-filters-reset`.
Future<T?> showFilterSheet<T>(
  BuildContext context, {
  required String id,
  required String title,
  required T initial,
  required T defaults,
  required List<Widget> Function(
    BuildContext context,
    T draft,
    ValueChanged<T> setDraft,
  )
  sections,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  // The draft lives in a State, not in this builder: Android sends new
  // window metrics while the sheet is open and the route runs the builder
  // again (f6d3bc0).
  builder: (sheet) => _Draft<T>(
    initial: initial,
    builder: (context, draft, setDraft) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            key: Key('$id-filter-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                child: Text(
                  title,
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
                    children: sections(context, draft, setDraft),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    // Shrinks and wraps between words: Arabic "Reset
                    // filters" at 130 % text overflowed a 320 dp row.
                    Flexible(
                      child: TextButton(
                        key: Key('$id-filters-reset'),
                        onPressed: draft == defaults
                            ? null
                            : () => setDraft(defaults),
                        child: Text(
                          l10n.resetFilters,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: WfPrimaryButton(
                        key: Key('$id-filters-apply'),
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
  ),
);

class _Draft<T> extends StatefulWidget {
  const new({required this.initial, required this.builder});

  final T initial;
  final Widget Function(BuildContext, T, ValueChanged<T>) builder;

  @override
  State<_Draft<T>> createState() => _DraftState<T>();
}

class _DraftState<T> extends State<_Draft<T>> {
  late T _draft = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _draft, (next) => setState(() => _draft = next));
}
