import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';

class NavDestination {
  const new({required this.icon, required this.label});
  final AppIcon icon;
  final String label;
}

/// Hosts a portal's tabs with the Figma "Navigation surface" (643:40732 for
/// client, 729:45527 for employee) floating over the content.
class AppShell extends StatelessWidget {
  const new({
    required this.navigationShell,
    required this.destinations,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: navigationShell,
    bottomNavigationBar: WfNavigationSurface(
      destinations: destinations,
      currentIndex: navigationShell.currentIndex,
      onSelect: (i) => navigationShell.goBranch(
        i,
        initialLocation: i == navigationShell.currentIndex,
      ),
    ),
  );
}

/// White 28 px-radius surface, 104 px tall, soft upward shadow; five 70 px
/// destinations with a 24 px icon over an Inter 12 label. The selected item
/// is drawn in `action/primary`.
class WfNavigationSurface extends StatelessWidget {
  const new({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.navSurface),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navShadow,
            offset: Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        heightFactor: 1,
        // 350 x 63 in Figma; it grows with the system text size instead of
        // clipping its labels (63 px overflowed by 5 px at 130 % text).
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350, minHeight: 63),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _Destination(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Center(child: SvgIcon(destination.icon, color: color)),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppTextStyles.mobileXsRegular.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
