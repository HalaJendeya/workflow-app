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
    bool remember = true,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password, portal: portal);
    // "Remember me" off keeps the token in memory only for this app run.
    final storage = ref.read(sessionStorageProvider);
    await (remember ? storage.writeAll(session.toStorage()) : storage.clear());
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

  /// The server refused the token (401). Sanctum tokens have no refresh
  /// route, so the session ends; if one was open the user is told why
  /// ([sessionExpiryProvider]) instead of silently landing on sign-in.
  void _expire() {
    if (state.value != null) ref.read(sessionExpiryProvider.notifier).bump();
    unawaited(_clear());
  }

  Future<void> _clear() async {
    ref.read(sessionCredentialsProvider).session = null;
    await ref.read(sessionStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// Counts sessions ended by the server (401), so the app can say so once
/// per expiry.
final sessionExpiryProvider = NotifierProvider<SessionExpiry, int>(
  SessionExpiry.new,
);

class SessionExpiry extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
