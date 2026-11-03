import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/auth_flow.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/auth/presentation/auth_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "Mobile / Light / Login" (137:26573).
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(
            email: _email.text.trim(),
            password: _password.text,
            portal: ref.read(selectedPortalProvider),
            remember: _remember,
          );
      // The router redirects to the portal home once the session is set.
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = AuthValidators(l10n);
    final portal = ref.watch(selectedPortalProvider);
    return AuthScaffold(
      children: [
        AuthHeading(
          lead: l10n.loginWelcome,
          accent: l10n.loginWelcomeAccent,
          secondLine: l10n.loginTitle,
        ),
        Form(
          key: _form,
          child: AutofillGroup(
            child: AuthFields(
              children: [
                WfTextField(
                  key: const Key('login-email'),
                  label: l10n.emailLabel,
                  hint: l10n.emailHint,
                  icon: AppIcon.message,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: v.email,
                  errorText: fieldError(_error, 'email'),
                ),
                WfTextField(
                  key: const Key('login-password'),
                  label: l10n.passwordLabel,
                  hint: l10n.passwordHint,
                  icon: AppIcon.lock,
                  controller: _password,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: v.required,
                  errorText: fieldError(_error, 'password'),
                  onSubmitted: (_) => _submit(),
                ),
                Row(
                  children: [
                    WfCheckbox(
                      value: _remember,
                      onChanged: (x) => setState(() => _remember = x),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.rememberMe,
                        style: AppTextStyles.desktopXsMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(Routes.forgotPassword),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        l10n.forgotPasswordLink,
                        style: AppTextStyles.desktopXsMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WfPrimaryButton(
                key: const Key('login-submit'),
                label: l10n.loginButton,
                loading: _busy,
                onPressed: _submit,
              ),
              // Only clients self-register; employees get credentials from
              // their Company Admin.
              if (portal == Portal.client) ...[
                const SizedBox(height: AppSpacing.sm),
                WfPromptLink(
                  prompt: l10n.signUpPrompt,
                  action: l10n.signUp,
                  onTap: () => context.push(Routes.register),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
