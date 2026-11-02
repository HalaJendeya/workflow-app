import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/core/widgets/design_pending_screen.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Route paths in one place.
abstract final class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const client = '/client';
  static const employee = '/employee';

  static String homeFor(Portal portal) =>
      portal == Portal.client ? client : employee;
}

/// Pure redirect rule, unit-tested separately from the widget tree.
String? redirectFor({
  required AsyncValue<Session?> session,
  required String location,
}) {
  if (session.isLoading && !session.hasValue) {
    return location == Routes.splash ? null : Routes.splash;
  }
  final current = session.value;
  if (current == null) {
    return location == Routes.welcome ? null : Routes.welcome;
  }
  final home = Routes.homeFor(current.portal);
  // Keep each role inside its own area.
  if (!location.startsWith(home)) return home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      session: ref.read(sessionControllerProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const DesignPendingScreen(routeName: 'splash'),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const DesignPendingScreen(routeName: 'auth'),
      ),
      GoRoute(
        path: Routes.client,
        builder: (_, _) => const DesignPendingScreen(routeName: 'client'),
      ),
      GoRoute(
        path: Routes.employee,
        builder: (_, _) => const DesignPendingScreen(routeName: 'employee'),
      ),
    ],
  );
});
