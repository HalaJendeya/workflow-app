import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/features/profile/presentation/profile_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "Workspace header" used at the top of every app masthead:
/// 40 px avatar, "WorkFlow" 18 SemiBold, "email · role" 12, bell button.
class WorkspaceHeader extends ConsumerWidget {
  const new({this.onBellTap, super.key});

  /// Defaults to opening the portal home, where the notification inbox lives.
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portal =
        ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
    final profile = ref.watch(profileProvider).value;
    final role = portal == Portal.client ? l10n.roleClient : l10n.roleEmployee;
    const white = AppColors.white;
    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.accountMenu,
          child: InkWell(
            key: const Key('account-menu'),
            customBorder: const CircleBorder(),
            onTap: () => _showAccountMenu(context, ref),
            child: WfAvatar(initials: profile?.initials ?? ''),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appTitle,
                style: AppTextStyles.mobileXlSemiBold.copyWith(color: white),
              ),
              const SizedBox(height: 2),
              Text(
                [?profile?.email, role].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mobileXsRegular.copyWith(color: white),
              ),
            ],
          ),
        ),
        _BellButton(
          onTap: onBellTap ?? () => context.go(Routes.homeFor(portal)),
        ),
      ],
    );
  }
}

class _BellButton extends ConsumerStatefulWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  ConsumerState<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends ConsumerState<_BellButton> {
  /// The badge would otherwise keep the count from before the app went to
  /// the background.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(notificationsControllerProvider.notifier).refreshIfStale(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final unread = ref
        .watch(notificationsControllerProvider)
        .value
        ?.unreadCount;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).notificationsTitle,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Badge(
              isLabelVisible: (unread ?? 0) > 0,
              smallSize: 8,
              backgroundColor: AppColors.primary,
              child: const Center(
                child: SvgIcon(AppIcon.notification, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Account menu opened from the masthead avatar.
Future<void> _showAccountMenu(
  BuildContext context,
  WidgetRef ref,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (sheet) {
    final l10n = AppLocalizations.of(sheet);
    final style = AppTextStyles.mobileBaseSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('account-profile'),
            leading: const SvgIcon(AppIcon.profile),
            title: Text(l10n.profileDetails, style: style),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            key: const Key('logout'),
            leading: const Icon(Icons.logout, color: AppColors.textPrimary),
            title: Text(l10n.logout, style: style),
            onTap: () {
              Navigator.of(sheet).pop();
              unawaited(ref.read(sessionControllerProvider.notifier).logout());
            },
          ),
        ],
      ),
    );
  },
);
