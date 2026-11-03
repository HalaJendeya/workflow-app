import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/design_pending_screen.dart';
import 'package:workflow_app/features/auth/application/auth_flow.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/auth/presentation/account_type_screen.dart';
import 'package:workflow_app/features/auth/presentation/login_screen.dart';
import 'package:workflow_app/features/auth/presentation/password_screens.dart';
import 'package:workflow_app/features/auth/presentation/register_screen.dart';
import 'package:workflow_app/features/overview/presentation/overview_screen.dart';
import 'package:workflow_app/features/shell/app_shell.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

export 'routes.dart';

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
    return Routes.public.contains(location) ? null : Routes.welcome;
  }
  final home = Routes.homeFor(current.portal);
  // Keep each role inside its own area.
  if (!location.startsWith(home)) return home;
  return null;
}

class _Splash extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.authBackground,
    body: Center(child: CircularProgressIndicator()),
  );
}

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

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
      GoRoute(path: Routes.splash, builder: (_, _) => const _Splash()),
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const AccountTypeScreen(),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.verify,
        builder: (_, state) => VerifyCodeScreen(
          purpose:
              OtpPurpose.values
                  .asNameMap()[state.uri.queryParameters['purpose']] ??
              OtpPurpose.emailVerification,
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        redirect: (_, state) =>
            state.extra is ResetArgs ? null : Routes.forgotPassword,
        builder: (_, state) =>
            NewPasswordScreen(args: state.extra! as ResetArgs),
      ),
      GoRoute(
        path: Routes.success,
        builder: (_, state) => AuthSuccessScreen(
          kind:
              SuccessKind.values
                  .asNameMap()[state.uri.queryParameters['kind']] ??
              SuccessKind.accountCreated,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final l10n = AppLocalizations.of(context);
          return AppShell(
            navigationShell: shell,
            destinations: [
              NavDestination(icon: AppIcon.navHome, label: l10n.navHome),
              NavDestination(
                icon: AppIcon.navCompanies,
                label: l10n.navCompanies,
              ),
              NavDestination(
                icon: AppIcon.navInvoices,
                label: l10n.navInvoices,
              ),
              NavDestination(icon: AppIcon.navChat, label: l10n.navChat),
              NavDestination(icon: AppIcon.navMore, label: l10n.navMore),
            ],
          );
        },
        branches: [
          _branch(Routes.client, const OverviewScreen()),
          _branch(
            Routes.clientCompanies,
            const DesignPendingScreen(routeName: 'client/companies'),
          ),
          _branch(
            Routes.clientInvoices,
            const DesignPendingScreen(routeName: 'client/invoices'),
          ),
          _branch(
            Routes.clientChat,
            const DesignPendingScreen(routeName: 'client/chat'),
          ),
          _branch(Routes.clientMore, const MoreScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final l10n = AppLocalizations.of(context);
          return AppShell(
            navigationShell: shell,
            destinations: [
              NavDestination(icon: AppIcon.navHome, label: l10n.navHome),
              NavDestination(icon: AppIcon.navTasks, label: l10n.navTasks),
              NavDestination(
                icon: AppIcon.navProjects,
                label: l10n.navProjects,
              ),
              NavDestination(icon: AppIcon.navChat, label: l10n.navChat),
              NavDestination(icon: AppIcon.navMore, label: l10n.navMore),
            ],
          );
        },
        branches: [
          _branch(Routes.employee, const OverviewScreen()),
          _branch(
            Routes.employeeTasks,
            const DesignPendingScreen(routeName: 'employee/tasks'),
          ),
          _branch(
            Routes.employeeProjects,
            const DesignPendingScreen(routeName: 'employee/projects'),
          ),
          _branch(
            Routes.employeeChat,
            const DesignPendingScreen(routeName: 'employee/chat'),
          ),
          _branch(Routes.employeeMore, const MoreScreen()),
        ],
      ),
    ],
  );
});

/// Temporary "More" tab: hosts logout until the Figma "More" menu is built.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            ListTile(
              key: const Key('logout'),
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
              onTap: () =>
                  ref.read(sessionControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
