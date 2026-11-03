import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/auth_flow.dart';
import 'package:workflow_app/features/auth/presentation/auth_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

Widget _backToLogin(BuildContext context) => Center(
  child: TextButton(
    onPressed: () => context.go(Routes.login),
    child: Text(
      AppLocalizations.of(context).backToLogin,
      style: AppTextStyles.desktopXsMedium.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  ),
);

/// Figma "Mobile / Light / Forgot Password?" (137:26526).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await ref.read(authFlowProvider).requestPasswordReset(email);
      if (mounted) {
        await context.push(
          Routes.verifyLocation(OtpPurpose.passwordReset, email),
        );
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
    return AuthScaffold(
      children: [
        AuthHeading(title: l10n.forgotTitle, body: l10n.forgotBody),
        Form(
          key: _form,
          child: WfTextField(
            key: const Key('forgot-email'),
            label: l10n.emailLabel,
            hint: l10n.emailHint,
            icon: AppIcon.message,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: AuthValidators(l10n).email,
            errorText: fieldError(_error, 'email'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WfPrimaryButton(
                key: const Key('forgot-submit'),
                label: l10n.sendCode,
                loading: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              _backToLogin(context),
            ],
          ),
        ),
      ],
    );
  }
}

/// Figma "Mobile / Light / Verification Code" (137:26665): four 64 px boxes,
/// 10 px apart, 16 px radius, #F5F5F5 stroke and a soft shadow.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const new({required this.purpose, required this.email, super.key});

  final OtpPurpose purpose;
  final String email;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _resending = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    if (_code.text.length != kOtpLength) {
      setState(() => _localError = l10n.validationOtp);
      return;
    }
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await ref
          .read(authFlowProvider)
          .verifyOtp(
            purpose: widget.purpose,
            email: widget.email,
            otp: _code.text,
          );
      if (!mounted) return;
      switch (widget.purpose) {
        case OtpPurpose.emailVerification:
          context.go(Routes.authSuccess(SuccessKind.accountCreated));
        case OtpPurpose.passwordReset:
          await context.push(
            Routes.resetPassword,
            extra: ResetArgs(email: widget.email, otp: _code.text),
          );
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _localError = fieldError(e, 'otp'));
      showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref
          .read(authFlowProvider)
          .resendOtp(purpose: widget.purpose, email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).codeResent)),
      );
    } on Object catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final digits = _code.text;
    return AuthScaffold(
      children: [
        AuthHeading(
          title: l10n.verifyTitle,
          body: l10n.verifyBody(kOtpLength, widget.email),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // Real input: invisible but focusable, drives the boxes.
                Opacity(
                  opacity: 0,
                  child: TextField(
                    key: const Key('otp-input'),
                    controller: _code,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: kOtpLength,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _verify(),
                  ),
                ),
                GestureDetector(
                  onTap: _focus.requestFocus,
                  child: Row(
                    children: [
                      for (var i = 0; i < kOtpLength; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _OtpBox(
                            digit: i < digits.length ? digits[i] : null,
                            active: _focus.hasFocus && i == digits.length,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_localError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _localError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.desktopXsRegular.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WfPrimaryButton(
                key: const Key('otp-submit'),
                label: l10n.verifyButton,
                loading: _busy,
                onPressed: _verify,
              ),
              const SizedBox(height: AppSpacing.sm),
              WfPromptLink(
                prompt: l10n.noCodePrompt,
                action: l10n.resend,
                promptStyle: AppTextStyles.desktopXsMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                onTap: _resending ? () {} : _resend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const new({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: active ? AppColors.primary : AppColors.surfaceSubtle,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          offset: Offset(0, 4),
          blurRadius: 12,
        ),
      ],
    ),
    child: Text(
      digit ?? '',
      style: AppTextStyles.authTitle.copyWith(color: AppColors.black),
    ),
  );
}

/// Figma "Mobile / Light / Create New Password" (137:26453).
class NewPasswordScreen extends ConsumerStatefulWidget {
  const new({required this.args, super.key});

  final ResetArgs args;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
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
          .read(authFlowProvider)
          .resetPassword(
            email: widget.args.email,
            otp: widget.args.otp,
            password: _password.text,
            confirmation: _confirm.text,
          );
      if (mounted) context.go(Routes.authSuccess(SuccessKind.passwordReset));
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
    return AuthScaffold(
      children: [
        AuthHeading(title: l10n.newPasswordTitle, body: l10n.newPasswordBody),
        Form(
          key: _form,
          child: AuthFields(
            children: [
              WfTextField(
                key: const Key('new-password'),
                label: l10n.newPasswordLabel,
                hint: l10n.passwordHint,
                icon: AppIcon.lock,
                controller: _password,
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: v.password(kMinPasswordLength),
                errorText: fieldError(_error, 'password'),
              ),
              WfTextField(
                key: const Key('confirm-password'),
                label: l10n.confirmPasswordLabel,
                hint: l10n.passwordHint,
                icon: AppIcon.lock,
                controller: _confirm,
                obscure: true,
                validator: (x) =>
                    v.required(x) ??
                    (x != _password.text ? l10n.validationPasswordMatch : null),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WfPrimaryButton(
                key: const Key('new-password-submit'),
                label: l10n.save,
                loading: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              _backToLogin(context),
            ],
          ),
        ),
      ],
    );
  }
}

/// Figma "Mobile / Light / Success" (137:26652).
class AuthSuccessScreen extends StatelessWidget {
  const new({required this.kind, super.key});

  final SuccessKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      showLogo: false,
      topSpacing: 120,
      children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: AppColors.primary50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 56, color: AppColors.primary),
          ),
        ),
        AuthHeading(
          title: kind == SuccessKind.accountCreated
              ? l10n.successAccountTitle
              : l10n.successPasswordTitle,
          body: l10n.successAccountBody,
        ),
        Padding(
          padding: EdgeInsets.zero,
          child: WfPrimaryButton(
            label: l10n.loginButton,
            onPressed: () => context.go(Routes.login),
          ),
        ),
      ],
    );
  }
}
