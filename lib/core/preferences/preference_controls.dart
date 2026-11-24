import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Language and appearance controls, shared by the sign-in screens
/// ([PreferenceChips]) and the More screen ([PreferencesCard]). Both read
/// and write the one [preferencesProvider]; a change applies at once and
/// keeps whatever was typed on the screen.

String languageLabel(AppLocalizations l10n, LanguagePreference l) =>
    switch (l) {
      LanguagePreference.system => l10n.systemDefault,
      LanguagePreference.english => l10n.languageEnglish,
      LanguagePreference.arabic => l10n.languageArabic,
    };

String appearanceLabel(AppLocalizations l10n, AppearancePreference a) =>
    switch (a) {
      AppearancePreference.system => l10n.systemDefault,
      AppearancePreference.light => l10n.appearanceLight,
      AppearancePreference.dark => l10n.appearanceDark,
    };

IconData appearanceIcon(AppearancePreference a) => switch (a) {
  AppearancePreference.system => Icons.brightness_auto_outlined,
  AppearancePreference.light => Icons.light_mode_outlined,
  AppearancePreference.dark => Icons.dark_mode_outlined,
};

Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  return _pick<LanguagePreference>(
    context,
    key: const Key('language-sheet'),
    title: l10n.language,
    options: LanguagePreference.values,
    current: ref.read(preferencesProvider).language,
    label: (l) => languageLabel(l10n, l),
    subtitle: (l) => l == LanguagePreference.system ? l10n.followsDevice : null,
    onPick: (l) => ref.read(preferencesProvider.notifier).setLanguage(l),
  );
}

Future<void> showAppearancePicker(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  return _pick<AppearancePreference>(
    context,
    key: const Key('appearance-sheet'),
    title: l10n.appearance,
    options: AppearancePreference.values,
    current: ref.read(preferencesProvider).appearance,
    label: (a) => appearanceLabel(l10n, a),
    subtitle: (a) =>
        a == AppearancePreference.system ? l10n.followsDevice : null,
    icon: appearanceIcon,
    onPick: (a) => ref.read(preferencesProvider.notifier).setAppearance(a),
  );
}

Future<void> _pick<T extends Enum>(
  BuildContext context, {
  required Key key,
  required String title,
  required List<T> options,
  required T current,
  required String Function(T) label,
  required String? Function(T) subtitle,
  required Future<void> Function(T) onPick,
  IconData Function(T)? icon,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (sheet) => SafeArea(
    child: Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Text(
            title,
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.neutral900,
            ),
          ),
        ),
        for (final o in options)
          ListTile(
            key: Key('option-${o.name}'),
            leading: icon == null
                ? null
                : Icon(icon(o), color: AppColors.textSecondary),
            title: Text(
              label(o),
              style: AppTextStyles.mobileBaseSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: subtitle(o) == null
                ? null
                : Text(
                    subtitle(o)!,
                    style: AppTextStyles.mobileXsRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
            trailing: o == current
                ? Icon(Icons.check, color: AppColors.primary)
                : null,
            selected: o == current,
            onTap: () {
              Navigator.of(sheet).pop();
              unawaited(onPick(o));
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

/// Two compact chips (language, appearance) for screens before sign-in.
class PreferenceChips extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 8,
        children: [
          _Chip(
            key: const Key('pref-language'),
            icon: Icons.language,
            // The language in use (also when it follows the device).
            label: Localizations.localeOf(context).languageCode == 'ar'
                ? l10n.languageArabic
                : l10n.languageEnglish,
            tooltip: l10n.changeLanguage,
            onTap: () => showLanguagePicker(context, ref),
          ),
          _Chip(
            key: const Key('pref-appearance'),
            icon: appearanceIcon(prefs.appearance),
            label: prefs.appearance == AppearancePreference.system
                ? l10n.appearanceAuto
                : appearanceLabel(l10n, prefs.appearance),
            tooltip: l10n.changeAppearance,
            onTap: () => showAppearancePicker(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: '$tooltip: $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: AppColors.borderSubtle)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            // A 44 px touch target with a compact look.
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.mobileXsSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Preferences" on the More screen: language and appearance rows.
class PreferencesCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);
    Widget row(
      Key key,
      IconData icon,
      String title,
      String value,
      VoidCallback onTap,
    ) => InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            // The title keeps its own width and the value takes the rest,
            // wrapping between its words: at 320 dp with 130 % text
            // "System default" squeezed the title into "Langu / age".
            Text(
              title,
              key: Key('${(key as ValueKey<String>).value}-title'),
              style: AppTextStyles.mobileBaseSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                key: Key('${key.value}-value'),
                textAlign: TextAlign.end,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Icons.chevron_right mirrors itself in RTL (matchTextDirection):
            // picking chevron_left there flipped it back to point right.
            Icon(
              Icons.chevron_right,
              key: const Key('settings-row-chevron'),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
    return ModuleCard(
      key: const Key('preferences-card'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.preferences,
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          row(
            const Key('settings-language'),
            Icons.language,
            l10n.language,
            languageLabel(l10n, prefs.language),
            () => showLanguagePicker(context, ref),
          ),
          Divider(height: 1, color: ModuleColors.sectionDivider),
          row(
            const Key('settings-appearance'),
            appearanceIcon(prefs.appearance),
            l10n.appearance,
            appearanceLabel(l10n, prefs.appearance),
            () => showAppearancePicker(context, ref),
          ),
        ],
      ),
    );
  }
}
