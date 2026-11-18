import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';

class NavDestination {
  const new({required this.icon, required this.label});
  final AppIcon icon;
  final String label;
}

/// Hosts a portal's tabs with the Figma "Navigation surface" (643:40732 for
/// client, 729:45527 for employee) floating over the content.
///
/// Android Back follows the tabs the user went through. Tabs are switched
/// with `go` (the bar, More's Projects/Sprints/Chat entries, dashboard
/// cards), which leaves no route to pop, so Back on a tab's first screen
/// used to close the app: More → Projects → Back exited instead of going
/// back to More (Redmi 8 acceptance run). Now, when nothing is open above
/// the tab (no pushed screen, sheet or dialog), Back returns to the
/// previously visited tab, then to Home, and only Home's Back leaves the
/// app.
class AppShell extends StatefulWidget {
  const new({
    required this.navigationShell,
    required this.destinations,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavDestination> destinations;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Visited tabs per shell route, oldest first, each at most once; the
  /// last is the current tab. Kept on the route, not in this state: the
  /// router may rebuild the shell with a new state on a tab switch.
  static final _history = Expando<List<int>>('visited tabs');

  List<int> get _visited => _history[widget.navigationShell.route] ??= [0];

  void _record(int tab) {
    final visited = _visited;
    if (visited.isEmpty || visited.last != tab) {
      visited
        ..remove(tab)
        ..add(tab);
    }
  }

  /// Back on a tab's first screen: the previous tab, else Home. Returns
  /// false (the router's own Back) when something can be popped first.
  Future<bool> _onBack() async {
    if (Navigator.of(context, rootNavigator: true).canPop()) return false;
    final shell = widget.navigationShell;
    final branch = shell.route.branches[shell.currentIndex];
    if (branch.navigatorKey.currentState?.canPop() ?? false) return false;
    if (shell.currentIndex == 0) return false;
    final visited = _visited;
    if (visited.isNotEmpty && visited.last == shell.currentIndex) {
      visited.removeLast();
    }
    shell.goBranch(visited.isEmpty ? 0 : visited.last);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    _record(shell.currentIndex);
    return BackButtonListener(
      onBackButtonPressed: _onBack,
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: WfNavigationSurface(
          destinations: widget.destinations,
          currentIndex: shell.currentIndex,
          onSelect: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.navSurface),
        boxShadow: [
          BoxShadow(
            color: AppColors.navShadow,
            offset: const Offset(0, -4),
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
            // "Companies" was clipped to "Compan" at 320 px with 130 % text.
            FitText(
              destination.label,
              minScale: 0.75,
              textAlign: TextAlign.center,
              style: AppTextStyles.mobileXsRegular.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
