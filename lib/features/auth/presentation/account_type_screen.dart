import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const WfLogo(height: 89.7),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
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
                            color: AppColors.black,
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
                                color: AppColors.black,
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
    final fg = selected ? AppColors.white : AppColors.black;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryStrong : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: selected
              ? BorderSide.none
              : const BorderSide(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 190),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(icon, size: 48, color: fg),
                const SizedBox(height: 9),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.choiceTitle.copyWith(color: fg),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.desktopBaseRegular.copyWith(
                    color: selected ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
