import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Layout shared by the mobile auth frames ("Mobile / Light / *", 390 wide):
/// #FBFBFB background, 24/16/32 padding, logo 248×88, 24 px gap, white card
/// with 16 px radius and 20×32 padding whose children are 32 px apart.
class AuthScaffold extends StatelessWidget {
  const new({
    required this.children,
    this.showLogo = true,
    this.topSpacing = 0,
    super.key,
  });

  final List<Widget> children;
  final bool showLogo;
  final double topSpacing;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.authBackground,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                if (topSpacing > 0) SizedBox(height: topSpacing),
                if (showLogo) ...[
                  const SizedBox(height: 88, child: Center(child: WfLogo())),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.authCard),
                    border: Border.all(color: AppColors.authCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced(children, AppSpacing.xl),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  static List<Widget> _spaced(List<Widget> items, double gap) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      items[i],
    ],
  ];
}

/// Heading block: Inter Bold 28/36 lines, optional accent word in primary,
/// optional 16/24 secondary body; 8 px between lines.
class AuthHeading extends StatelessWidget {
  const new({
    this.lead,
    this.accent,
    this.secondLine,
    this.title,
    this.body,
    super.key,
  });

  final String? lead;
  final String? accent;
  final String? secondLine;
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.authTitle.copyWith(color: AppColors.black);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(title!, textAlign: TextAlign.center, style: style),
        if (lead != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: lead),
                if (accent != null)
                  TextSpan(
                    text: accent,
                    style: const TextStyle(color: AppColors.primary),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
            style: style,
          ),
        if (secondLine != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(secondLine!, textAlign: TextAlign.center, style: style),
        ],
        if (body != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: AppTextStyles.desktopBaseRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Column of fields separated by 16 px ("Login form").
class AuthFields extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        children[i],
      ],
    ],
  );
}

/// Shared form validators, localized.
class AuthValidators {
  new(this.l10n);

  final AppLocalizations l10n;
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? l10n.validationRequired : null;

  String? email(String? v) =>
      required(v) ?? (_email.hasMatch(v!.trim()) ? null : l10n.validationEmail);

  String? Function(String?) password(int min) =>
      (v) =>
          required(v) ??
          (v!.length < min ? l10n.validationPasswordMin(min) : null);
}

/// Shows a failed request: field errors stay on the form; anything else is a
/// localized snackbar. 403/422 server messages are shown as given because
/// they explain the reason (unverified email, deactivated account, ...).
void showAuthError(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  var text = localizedError(l10n, error);
  if (error is PortalMismatch) {
    text = switch (error.chosen) {
      Portal.client => l10n.wrongPortalClient,
      Portal.employee => l10n.wrongPortalEmployee,
    };
  }
  if (error is ApiException &&
      (error.kind == ApiFailureKind.forbidden ||
          (error.kind == ApiFailureKind.validation &&
              error.fieldErrors.isEmpty) ||
          error.kind == ApiFailureKind.unauthorized)) {
    text = error.message;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String? fieldError(Object? error, String field) =>
    error is ApiException ? error.firstErrorFor(field) : null;
