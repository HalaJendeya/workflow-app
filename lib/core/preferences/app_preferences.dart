import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Display language: follow the device, or force English / Arabic.
enum LanguagePreference { system, english, arabic }

/// Appearance: follow the device, or force light / dark.
enum AppearancePreference { system, light, dark }

/// The person's display preferences. They belong to the device, not to an
/// account: they survive restart, login and logout.
@immutable
class AppPreferences {
  const new({
    this.language = LanguagePreference.system,
    this.appearance = AppearancePreference.system,
  });

  factory fromStorage(Map<String, String> values) => AppPreferences(
    language:
        LanguagePreference.values
            .where((l) => l.name == values[_languageKey])
            .firstOrNull ??
        LanguagePreference.system,
    appearance:
        AppearancePreference.values
            .where((a) => a.name == values[_appearanceKey])
            .firstOrNull ??
        AppearancePreference.system,
  );

  static const _languageKey = 'language';
  static const _appearanceKey = 'appearance';

  final LanguagePreference language;
  final AppearancePreference appearance;

  /// `null` follows the device (resolved by [resolveLocale]).
  Locale? get locale => switch (language) {
    LanguagePreference.system => null,
    LanguagePreference.english => const Locale('en'),
    LanguagePreference.arabic => const Locale('ar'),
  };

  ThemeMode get themeMode => switch (appearance) {
    AppearancePreference.system => ThemeMode.system,
    AppearancePreference.light => ThemeMode.light,
    AppearancePreference.dark => ThemeMode.dark,
  };

  /// The brightness to draw with, given the device's.
  Brightness brightness(Brightness platform) => switch (appearance) {
    AppearancePreference.system => platform,
    AppearancePreference.light => Brightness.light,
    AppearancePreference.dark => Brightness.dark,
  };

  AppPreferences copyWith({
    LanguagePreference? language,
    AppearancePreference? appearance,
  }) => AppPreferences(
    language: language ?? this.language,
    appearance: appearance ?? this.appearance,
  );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.language == language &&
      other.appearance == appearance;

  @override
  int get hashCode => Object.hash(language, appearance);
}

/// The first device language the app supports, else English. (Flutter's
/// own fallback is the first supported locale, which is Arabic here.)
Locale resolveLocale(List<Locale>? device, Iterable<Locale> supported) {
  for (final l in device ?? const <Locale>[]) {
    for (final s in supported) {
      if (s.languageCode == l.languageCode) return s;
    }
  }
  return const Locale('en');
}

/// Where preferences are kept: their own keys in secure storage, apart
/// from the session (whose sign-out clear does not touch them).
abstract interface class PreferencesStore {
  Future<Map<String, String>> read();
  Future<void> write(String key, String value);
}

class SecurePreferencesStore implements PreferencesStore {
  new([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _prefix = 'wf.prefs.';

  @override
  Future<Map<String, String>> read() async {
    final all = await _storage.readAll();
    return {
      for (final e in all.entries)
        if (e.key.startsWith(_prefix)) e.key.substring(_prefix.length): e.value,
    };
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);
}

class InMemoryPreferencesStore implements PreferencesStore {
  new([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  @override
  Future<Map<String, String>> read() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final preferencesStoreProvider = Provider<PreferencesStore>(
  (_) => InMemoryPreferencesStore(),
);

/// What was stored when the app started (read before the first frame, so
/// a chosen language or theme never flashes the default first).
final initialPreferencesProvider = Provider<AppPreferences>(
  (_) => const AppPreferences(),
);

/// The one place the app reads and changes the display preferences.
class PreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => ref.read(initialPreferencesProvider);

  Future<void> setLanguage(LanguagePreference language) async {
    if (state.language == language) return;
    state = state.copyWith(language: language);
    await ref
        .read(preferencesStoreProvider)
        .write(AppPreferences._languageKey, language.name);
  }

  Future<void> setAppearance(AppearancePreference appearance) async {
    if (state.appearance == appearance) return;
    state = state.copyWith(appearance: appearance);
    await ref
        .read(preferencesStoreProvider)
        .write(AppPreferences._appearanceKey, appearance.name);
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesController, AppPreferences>(
      PreferencesController.new,
    );

/// Reads stored preferences before `runApp`; a storage failure falls back
/// to the device defaults rather than blocking launch.
Future<AppPreferences> loadPreferences(PreferencesStore store) async {
  try {
    return AppPreferences.fromStorage(await store.read());
  } on Object {
    return const AppPreferences();
  }
}
