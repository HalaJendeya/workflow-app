import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/preferences/preference_controls.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/auth_flow.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "WorkFlow / Account type / Mobile" (150:2174).
class AccountTypeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(selectedPortalProvider);
    void select(Portal p) =>
        ref.read(selectedPortalProvider.notifier).select(p);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const PreferenceChips(),
                  const SizedBox(height: AppSpacing.sm),
                  const WfLogo(height: 72),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.authCard),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.accountTypeTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.accountTypeTitle.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ChoiceCard(
                          key: const Key('portal-client'),
                          icon: AppIcon.accountClient,
                          title: l10n.accountTypeClientTitle,
                          body: l10n.accountTypeClientBody,
                          selected: selected == Portal.client,
                          onTap: () => select(Portal.client),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChoiceCard(
                          key: const Key('portal-employee'),
                          icon: AppIcon.accountEmployee,
                          title: l10n.accountTypeEmployeeTitle,
                          body: l10n.accountTypeEmployeeBody,
                          selected: selected == Portal.employee,
                          onTap: () => select(Portal.employee),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        WfPrimaryButton(
                          label: l10n.next,
                          color: AppColors.primaryStrong,
                          textStyle: AppTextStyles.desktopLgBold,
                          onPressed: () => context.push(Routes.login),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${l10n.noAccountPrompt} ',
                              style: AppTextStyles.mobileXsRegular.copyWith(
                                fontSize: 11,
                                color: AppColors.ink,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                select(Portal.client);
                                unawaited(context.push(Routes.register));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  l10n.createClientAccount,
                                  style: AppTextStyles.desktopXsMedium.copyWith(
                                    color: AppColors.primaryStrong,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppIcon icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryStrong : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: selected
              ? BorderSide.none
              : BorderSide(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Icon beside the text: one row per choice instead of a 190 px
          // centred stack, so Next stays on screen on a 640 px phone.
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SvgIcon(icon, size: 36, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.choiceTitle.copyWith(color: fg),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: AppTextStyles.desktopBaseRegular.copyWith(
                          color: selected
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.white : AppColors.borderDefault,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
