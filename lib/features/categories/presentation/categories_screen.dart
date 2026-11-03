import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// One destination row inside a Categories section.
class CategoryItem {
  const new({required this.label, required this.icon, required this.onOpen});

  final String label;
  final String icon;
  final void Function(BuildContext context) onOpen;
}

/// One section card ("Overview", "Finance", …).
class CategorySection {
  const new({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pillIcon,
    required this.items,
  });

  final String title;
  final String subtitle;
  final String icon;
  final String pillIcon;
  final List<CategoryItem> items;
}

/// Shortcut offered by the "Create" FAB.
class CreateAction {
  const new(this.label, this.onOpen);
  final String label;
  final void Function(BuildContext context) onOpen;
}

/// Figma "Categories" (client 666:69807, employee 729:46349): filter pills,
/// section cards with module rows, and the Create FAB.
class CategoriesScreen extends ConsumerStatefulWidget {
  const new({required this.sections, required this.createActions, super.key});

  final List<CategorySection> sections;
  final List<CreateAction> createActions;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int? _section;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final total = widget.sections.fold<int>(0, (s, x) => s + x.items.length);
    final cards = <Widget>[];
    for (var i = 0; i < widget.sections.length; i++) {
      if (_section != null && _section != i) continue;
      final s = widget.sections[i];
      final items = s.items
          .where((it) => q.isEmpty || it.label.toLowerCase().contains(q))
          .toList();
      if (items.isEmpty) continue;
      cards.add(_SectionCard(section: s, items: items));
    }
    return ModulePage(
      title: l10n.categoriesTitle,
      description: l10n.categoriesDescription,
      onSearch: (v) => setState(() => _query = v),
      onCreate: widget.createActions.isEmpty ? null : _openCreate,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Pill(
                label: l10n.filterAll,
                icon: 'cat_pill_all',
                count: total,
                selected: _section == null,
                onTap: () => setState(() => _section = null),
              ),
              for (var i = 0; i < widget.sections.length; i++) ...[
                const SizedBox(width: 11),
                _Pill(
                  label: widget.sections[i].title,
                  icon: widget.sections[i].pillIcon,
                  selected: _section == i,
                  onTap: () => setState(() => _section = i),
                ),
              ],
            ],
          ),
        ),
        if (cards.isEmpty) EmptyNotice(text: l10n.noResults) else ...cards,
      ],
    );
  }

  Future<void> _openCreate() => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in widget.createActions)
            ListTile(
              title: Text(
                a.label,
                style: AppTextStyles.mobileBaseSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: const WfSvg('chevron'),
              onTap: () {
                Navigator.of(sheet).pop();
                a.onOpen(context);
              },
            ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ModuleColors.activePill : AppColors.white,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : const BorderSide(color: ModuleColors.pillBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WfSvg(
                  icon,
                  size: 16,
                  color: selected ? AppColors.white : ModuleColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style:
                      (selected
                              ? AppTextStyles.mobileXsSemiBold
                              : AppTextStyles.mobileXsMedium)
                          .copyWith(
                            color: selected
                                ? AppColors.white
                                : AppColors.textSecondary,
                          ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ModuleColors.activePillCount,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '$count',
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const new({required this.section, required this.items});

  final CategorySection section;
  final List<CategoryItem> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: ModuleColors.sectionDivider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ModuleColors.sectionDivider),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: WfSvg(section.icon, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppTextStyles.desktopBaseBold.copyWith(
                        color: AppColors.black,
                      ),
                    ),
                    Text(
                      section.subtitle,
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        fontSize: 10,
                        height: 15 / 10,
                        color: ModuleColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < items.length; i++)
          InkWell(
            key: Key('category-${items[i].label}'),
            onTap: () => items[i].onOpen(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: i < items.length - 1
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF8FAFC)),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.appBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox.square(
                      dimension: 24,
                      child: Center(child: WfSvg(items[i].icon)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i].label,
                      style: AppTextStyles.desktopXsSemiBold.copyWith(
                        color: AppColors.black,
                      ),
                    ),
                  ),
                  if (Directionality.of(context) == TextDirection.rtl)
                    Transform.flip(flipX: true, child: const WfSvg('chevron'))
                  else
                    const WfSvg('chevron'),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Opens a full-screen page on top of the shell (keeps back navigation).
void pushPage(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => page));

/// Switches to a shell tab by path.
void goTab(BuildContext context, String path) => context.go(path);
