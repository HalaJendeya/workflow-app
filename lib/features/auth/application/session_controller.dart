import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Owns the signed-in session: restores it on start, persists it on login and
/// clears it on logout or when the server answers 401.
class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final credentials = ref.watch(sessionCredentialsProvider)
      ..unauthorizedHandler = _expire;
    final stored = await ref.watch(sessionStorageProvider).readAll();
    Session? session;
    try {
      session = stored.isEmpty ? null : Session.fromStorage(stored);
    } on Object {
      // Corrupt or outdated entry: start signed out rather than crash.
      await ref.read(sessionStorageProvider).clear();
    }
    credentials.session = session;
    return session;
  }

  /// Throws [ApiException] on failure so forms can show field errors; state
  /// only changes on success.
  Future<void> login({
    required String email,
    required String password,
    required Portal portal,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password, portal: portal);
    await ref.read(sessionStorageProvider).writeAll(session.toStorage());
    ref.read(sessionCredentialsProvider).session = session;
    state = AsyncData(session);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // The token is discarded locally regardless; a failed revoke must not
      // keep the user signed in on this device.
    }
    await _clear();
  }

  void _expire() => unawaited(_clear());

  Future<void> _clear() async {
    ref.read(sessionCredentialsProvider).session = null;
    await ref.read(sessionStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
