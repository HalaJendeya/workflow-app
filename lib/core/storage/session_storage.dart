import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the minimal session (token + identifiers). Implementations must
/// keep the token out of plain-text preferences.
abstract interface class SessionStorage {
  Future<Map<String, String>> readAll();
  Future<void> writeAll(Map<String, String> values);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  new([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _prefix = 'wf.session.';

  @override
  Future<Map<String, String>> readAll() async {
    final all = await _storage.readAll();
    return {
      for (final e in all.entries)
        if (e.key.startsWith(_prefix)) e.key.substring(_prefix.length): e.value,
    };
  }

  @override
  Future<void> writeAll(Map<String, String> values) async {
    await clear();
    for (final e in values.entries) {
      await _storage.write(key: '$_prefix${e.key}', value: e.value);
    }
  }

  @override
  Future<void> clear() async {
    final all = await _storage.readAll();
    for (final key in all.keys.where((k) => k.startsWith(_prefix))) {
      await _storage.delete(key: key);
    }
  }
}

/// Non-persistent storage for tests and mock mode.
class InMemorySessionStorage implements SessionStorage {
  final Map<String, String> _values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);

  @override
  Future<void> writeAll(Map<String, String> values) async {
    _values
      ..clear()
      ..addAll(values);
  }

  @override
  Future<void> clear() async => _values.clear();
}
