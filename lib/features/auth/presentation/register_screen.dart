import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/auth_flow.dart';
import 'package:workflow_app/features/auth/presentation/auth_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "Mobile / Light / Individual registration" (137:26681). Creates a
/// client account (`account_type=client`).
class RegisterScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.validationTerms)));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final result = await ref
          .read(authFlowProvider)
          .registerClient(
            name: _name.text.trim(),
            email: email,
            password: _password.text,
          );
      if (!mounted) return;
      if (result.verificationRequired) {
        context.go(Routes.verifyLocation(OtpPurpose.emailVerification, email));
      } else {
        context.go(Routes.authSuccess(SuccessKind.accountCreated));
      }
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
    final small = AppTextStyles.mobileXsRegular.copyWith(
      fontSize: 11,
      color: AppColors.black,
    );
    final link = small.copyWith(color: AppColors.primary);
    return AuthScaffold(
      children: [
        AuthHeading(
          lead: l10n.registerTitleLead,
          accent: l10n.registerTitleAccent,
          secondLine: l10n.registerSubtitle,
        ),
        Form(
          key: _form,
          child: AuthFields(
            children: [
              WfTextField(
                key: const Key('register-name'),
                label: l10n.userNameLabel,
                hint: l10n.userNameHint,
                icon: AppIcon.profile,
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: v.required,
                errorText: fieldError(_error, 'name'),
              ),
              WfTextField(
                key: const Key('register-email'),
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
                key: const Key('register-password'),
                label: l10n.passwordLabel,
                hint: l10n.passwordHint,
                icon: AppIcon.lock,
                controller: _password,
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: v.password(kMinPasswordLength),
                errorText: fieldError(_error, 'password'),
              ),
              Row(
                children: [
                  WfCheckbox(
                    key: const Key('register-terms'),
                    value: _agreed,
                    onChanged: (x) => setState(() => _agreed = x),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: l10n.agreeTermsLead, style: small),
                          TextSpan(text: l10n.agreeTermsTerms, style: link),
                          TextSpan(text: l10n.agreeTermsAnd, style: small),
                          TextSpan(
                            text: l10n.agreeTermsConditions,
                            style: link,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WfPrimaryButton(
              key: const Key('register-submit'),
              label: l10n.signInButton,
              loading: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            WfPromptLink(
              prompt: l10n.haveAccountPrompt,
              action: l10n.loginLink,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(Routes.login),
            ),
          ],
        ),
      ],
    );
  }
}
