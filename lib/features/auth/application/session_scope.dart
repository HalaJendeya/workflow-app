import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';

/// One period of the session in one account and one company: the
/// `(userId, companyId)` the app works in, plus a number that is new every
/// time either changes. Sign-out, another account and a company switch
/// (also A → B → A) each start a new scope.
///
/// Long-lived controllers outlive a switch: Riverpod keeps a notifier
/// across rebuilds and its `ref.mounted` stays true, so a request started
/// for company A could otherwise apply its answer to company B's screen.
/// They capture the scope (`ref.captureScope()`) before awaiting and
/// apply results, side effects and follow-up requests only while
/// `ref.inScope(scope)` says the same scope is still current. A request
/// already sent keeps the company it was sent with; a stale answer is
/// dropped, never retried.
final class SessionScope {
  const new(this.userId, this.companyId, this.serial);

  final int? userId;
  final int? companyId;

  /// Increases with every new scope, so two periods in the same account
  /// and company are still told apart.
  final int serial;

  @override
  String toString() => 'SessionScope(#$serial: $userId @ $companyId)';
}

int _serial = 0;

/// The current [SessionScope]. Rebuilt — with a new [SessionScope.serial] —
/// whenever the account or the company changes. Never disposed, so an
/// unchanged scope is always the same object.
final sessionScopeProvider = Provider<SessionScope>((ref) {
  final (userId, companyId) = ref.watch(
    sessionControllerProvider.select(
      (s) => (s.value?.userId, s.value?.companyId),
    ),
  );
  return SessionScope(userId, companyId, ++_serial);
});

/// The same check for widgets that await a request themselves: a snack,
/// preview or follow-up request is shown or sent only while [inScope].
extension SessionScopeWidgetRef on WidgetRef {
  SessionScope captureScope() => read(sessionScopeProvider);

  bool inScope(SessionScope scope) =>
      identical(read(sessionScopeProvider), scope);
}

extension SessionScopeRef on Ref {
  /// The scope an asynchronous operation starts in.
  SessionScope captureScope() => read(sessionScopeProvider);

  /// Whether [scope] is still the current one (and this provider is still
  /// alive): only then may an answer obtained in it be applied.
  bool inScope(SessionScope scope) =>
      mounted && identical(read(sessionScopeProvider), scope);
}
