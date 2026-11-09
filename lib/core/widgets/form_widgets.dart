import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Full-screen form from the Figma create frames (Create Invoice 643:36437,
/// Add Payment 643:35666, add project 643:34778…): #F7F7F7 page, 22 px Bold
/// title, white card of fields 16 px apart, Save + Cancel actions.
class FormPage extends StatelessWidget {
  const new({
    required this.title,
    required this.formKey,
    required this.fields,
    required this.onSave,
    this.saving = false,
    this.saveLabel,
    super.key,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final VoidCallback onSave;
  final bool saving;
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Form(
          key: formKey,
          // Built all at once (not lazily) so a field scrolled out of view
          // keeps its value and its validation error.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const BackButtonIcon(),
                        color: AppColors.textPrimary,
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.mobile2xlSemiBold.copyWith(
                          fontSize: 22,
                          height: 31 / 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        fields[i],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const Key('form-save'),
                    onPressed: saving ? null : onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        side: const BorderSide(color: AppColors.borderDefault),
                      ),
                      textStyle: AppTextStyles.mobileBaseSemiBold,
                    ),
                    child: Text(saveLabel ?? l10n.save),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: ModuleColors.chipBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                      textStyle: AppTextStyles.mobileBaseSemiBold,
                    ),
                    child: Text(l10n.cancel),
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

/// Validates [form] and, when a field is invalid, scrolls the first one on
/// screen so its message is seen even if the user tapped Save far below it.
bool validateAndReveal(GlobalKey<FormState> form) {
  final state = form.currentState;
  if (state == null) return false;
  final invalid = state.validateGranularly();
  if (invalid.isEmpty) return true;
  FormFieldState<Object?>? first;
  var top = double.infinity;
  for (final f in invalid) {
    final box = f.context.findRenderObject();
    if (box is! RenderBox || !box.attached) continue;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y < top) {
      top = y;
      first = f;
    }
  }
  if (first != null) {
    Scrollable.ensureVisible(
      first.context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
    );
  }
  return false;
}

class _Labeled extends StatelessWidget {
  const new({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: AppTextStyles.mobileBaseSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

InputDecoration _decoration({String? hint, Widget? suffix}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.input),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    filled: true,
    fillColor: AppColors.white,
    hintText: hint,
    hintStyle: AppTextStyles.mobileBaseRegular.copyWith(
      color: AppColors.textPrimary,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    constraints: const BoxConstraints(minHeight: 48),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 20),
    // Long messages wrap instead of being cut off on small phones.
    errorMaxLines: 3,
    border: b(ModuleColors.chipBorder),
    enabledBorder: b(ModuleColors.chipBorder),
    focusedBorder: b(AppColors.primary),
    errorBorder: b(ModuleColors.dangerFg),
    focusedErrorBorder: b(ModuleColors.dangerFg),
  );
}

String? requiredValidator(BuildContext context, Object? v) =>
    (v == null || (v is String && v.trim().isEmpty))
    ? AppLocalizations.of(context).validationRequired
    : null;

/// "select" field with the Figma down-arrow; picks from [options].
class SelectField<T> extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.required = true,
    super.key,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) => _Labeled(
    label: label,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const WfSvg('field_arrow_down', size: 20),
      decoration: _decoration(hint: AppLocalizations.of(context).selectHint)
          .copyWith(),
      borderRadius: BorderRadius.circular(AppRadii.input),
      style: AppTextStyles.mobileBaseRegular.copyWith(
        color: AppColors.textPrimary,
      ),
      validator: required ? (v) => requiredValidator(context, v) : null,
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(labelOf(o))),
      ],
      onChanged: onChanged,
    ),
  );
}

/// Text input with the form styling.
class TextInputField extends StatelessWidget {
  const new({
    required this.label,
    required this.controller,
    this.hint,
    this.number = false,
    this.maxLines = 1,
    this.required = true,
    this.fieldKey,
    this.validator,
    this.keyboardType,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool number;
  final int maxLines;
  final bool required;
  final Key? fieldKey;

  /// Extra check run after the required/number rules pass.
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => _Labeled(
    label: label,
    child: TextFormField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : null,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : keyboardType,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))]
          : null,
      style: AppTextStyles.mobileBaseRegular.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: _decoration(hint: hint).copyWith(
        hintStyle: AppTextStyles.mobileBaseRegular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return AppLocalizations.of(context).validationRequired;
        }
        if (number && v != null && v.isNotEmpty && double.tryParse(v) == null) {
          return AppLocalizations.of(context).validationNumber;
        }
        return validator?.call(v);
      },
    ),
  );
}

/// Rejects anything but a number greater than zero (an amount).
String? positiveAmount(BuildContext context, String? v) {
  final n = double.tryParse(v ?? '');
  return n != null && n <= 0
      ? AppLocalizations.of(context).validationPositive
      : null;
}

/// Rejects anything but a whole number (story points).
String? wholeNumber(BuildContext context, String? v) =>
    v == null || v.isEmpty || int.tryParse(v) != null
    ? null
    : AppLocalizations.of(context).validationWholeNumber;

/// Date input showing dd-MM-yyyy with the Figma calendar icon. It is a form
/// field, so [validator] errors show under it like the other inputs.
class DateField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
    super.key,
  });

  /// Range offered by the picker.
  static final first = DateTime(2020);
  static final last = DateTime(2035, 12, 31);

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? Function(DateTime value)? validator;

  @override
  Widget build(BuildContext context) => _Labeled(
    label: label,
    child: FormField<DateTime>(
      key: ValueKey(value),
      initialValue: value,
      validator: validator == null ? null : (_) => validator!(value),
      builder: (field) => InkWell(
        key: Key('date-$label'),
        borderRadius: BorderRadius.circular(AppRadii.input),
        onTap: () async {
          // A stored date outside the range used to trip the picker's
          // assertion; open on the nearest allowed day instead.
          final initial = value.isBefore(first)
              ? first
              : value.isAfter(last)
              ? last
              : value;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: _decoration(
            suffix: const WfSvg('field_calendar', size: 20),
          ).copyWith(errorText: field.errorText, errorMaxLines: 3),
          child: Text(
            DateFormat('dd-MM-yyyy').format(value),
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}
