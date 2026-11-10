import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';

/// WorkFlow logo (Figma "WorkFlow logo", 248×88 in auth frames).
class WfLogo extends StatelessWidget {
  const new({this.width = 248, this.height = 88, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'WorkFlow',
    image: true,
    child: Image.asset(
      'assets/brand/workflow_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    ),
  );
}

/// "Mobile / Light / Primary Button" (Figma 114:18788): 52 px tall, radius 12,
/// primary fill, 1 px #D2D2D2 stroke, Inter Bold 16 white.
class WfPrimaryButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
    this.color = AppColors.primary,
    this.textStyle,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final Color color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: onPressed == null ? 0.6 : 1,
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: (textStyle ?? AppTextStyles.desktopBaseBold)
                            .copyWith(color: AppColors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labeled auth input: Inter Bold 16 label, 8 px gap, 16 px radius field with
/// a leading Iconly icon and optional password visibility toggle.
class WfTextField extends StatefulWidget {
  const new({
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.errorText,
    this.autofillHints,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final AppIcon icon;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  /// Server-side error for this field (e.g. Laravel 422 field error).
  final String? errorText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<WfTextField> createState() => _WfTextFieldState();
}

class _WfTextFieldState extends State<WfTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.desktopBaseBold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.input),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _hidden,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            style: AppTextStyles.desktopBaseMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.white,
              hintText: widget.hint,
              hintStyle: AppTextStyles.desktopBaseMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              errorText: widget.errorText,
              errorMaxLines: 2,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                0,
                12,
                16,
                12,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
                child: SvgIcon(widget.icon),
              ),
              prefixIconConstraints: const BoxConstraints(minHeight: 24),
              constraints: const BoxConstraints(minHeight: 48),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Show' : 'Hide',
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: _hidden
                          ? const SvgIcon(AppIcon.hide)
                          : const Icon(
                              Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                            ),
                    )
                  : null,
              border: border(AppColors.borderSubtle),
              enabledBorder: border(AppColors.borderSubtle),
              focusedBorder: border(AppColors.primary),
              errorBorder: border(Theme.of(context).colorScheme.error),
              focusedErrorBorder: border(Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

/// Square checkbox from the auth frames (24 px, radius 8, #E9F9FB fill).
class WfCheckbox extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    child: InkResponse(
      radius: 20,
      onTap: () => onChanged(!value),
      child: value
          ? const SvgIcon(AppIcon.checkboxChecked)
          : Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDefault),
              ),
            ),
    ),
  );
}

/// Filter pill ("Filter" in Figma): selected = primary fill + white text,
/// otherwise white with subtle border and secondary text.
class WfFilterPill extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary : AppColors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            label,
            style: AppTextStyles.mobileXsMedium.copyWith(
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// White content card: 20 px radius, subtle border, 16 px padding.
class WfCard extends StatelessWidget {
  const new({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: const BorderSide(color: AppColors.borderSubtle),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Info status chip ("Status" in Figma): 5 px dot, Inter SemiBold 12.
class WfStatusChip extends StatelessWidget {
  const new({
    required this.label,
    this.foreground = AppColors.statusInfo,
    this.background = AppColors.statusInfoBackground,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.mobileXsSemiBold.copyWith(color: foreground),
        ),
      ],
    ),
  );
}

/// Initials avatar ("Avatar", size M = 40 px).
class WfAvatar extends StatelessWidget {
  const new({required this.initials, this.size = 40, super.key});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.surfaceSubtle,
      shape: BoxShape.circle,
    ),
    // Group initials ("#gen") wrapped inside the circle at 320 px with large
    // text; they now shrink to stay on one line within it.
    child: Padding(
      padding: EdgeInsets.all(size * 0.12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initials,
          maxLines: 1,
          softWrap: false,
          style: AppTextStyles.desktopXsSemiBold.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
    ),
  );
}

/// Two-tone rich text ("Already have an account? login").
class WfPromptLink extends StatelessWidget {
  const new({
    required this.prompt,
    required this.action,
    required this.onTap,
    this.promptStyle,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;
  final TextStyle? promptStyle;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        '$prompt ',
        style:
            promptStyle ??
            AppTextStyles.desktopXsRegular.copyWith(color: AppColors.black),
      ),
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(action, style: AppTextStyles.link),
        ),
      ),
    ],
  );
}
