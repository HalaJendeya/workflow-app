import 'package:flutter/widgets.dart' show TextDirection;
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Maps any error to a localized, user-facing sentence with a next step.
///
/// Every screen shows failures through this (or `ApiErrorCard` /
/// `AsyncSection`, which call it), so no raw exception, status code, URL or
/// server body reaches the UI. Each status keeps its own meaning: a 403 is a
/// missing permission, not an expired session (that is 401); a 404 is an
/// item that may be gone, not an outage (that is 5xx).
String localizedError(AppLocalizations l10n, Object error) {
  if (error is! ApiException) return l10n.errorUnknown;
  return switch (error.kind) {
    ApiFailureKind.network => l10n.errorNetwork,
    ApiFailureKind.timeout => l10n.errorTimeout,
    ApiFailureKind.unauthorized => l10n.errorSessionExpired,
    ApiFailureKind.forbidden => l10n.errorForbidden,
    ApiFailureKind.notFound => l10n.errorNotFound,
    ApiFailureKind.conflict => l10n.errorConflict,
    // A validation failure says what to fix when the server's first field
    // message is safe to show in this language; the form highlights the
    // fields either way.
    ApiFailureKind.validation =>
      _firstSafeFieldError(l10n, error) ?? l10n.errorValidation,
    ApiFailureKind.badRequest => l10n.errorBadRequest,
    ApiFailureKind.rateLimited => l10n.errorRateLimited(
      error.retryAfterSeconds ?? 60,
    ),
    // A response the app cannot read is a server-side fault for the user.
    ApiFailureKind.server || ApiFailureKind.invalidResponse => l10n.errorServer,
    ApiFailureKind.unknown => l10n.errorUnknown,
  };
}

/// Longest server sentence shown as is; longer text is likely a dump.
const _maxServerText = 160;

/// Markers of technical text that must never reach the UI: exceptions,
/// stack frames, SQL, file paths, URLs, routes and credentials.
final _technical = RegExp(
  r'exception|error:|stack|trace|sqlstate|sql\b|select\s|insert\s|'
  r'undefined|null\b|\.php|\.dart|vendor/|https?://|/api/|\bapi\b|'
  r'endpoint|route|token|bearer|password_hash|#\d+\s|\{|\}|<[a-z/]',
  caseSensitive: false,
);

/// [text] from the server when it is safe and readable to show: short, one
/// paragraph, free of technical markers, and written in the UI's language
/// (an English sentence is not shown in the Arabic UI). Otherwise null, and
/// the caller shows its localized sentence instead.
String? safeServerMessage(AppLocalizations l10n, String? text) {
  final t = text?.trim();
  if (t == null || t.isEmpty || t.length > _maxServerText) return null;
  if (t.contains('\n') || _technical.hasMatch(t)) return null;
  final rtlText = contentDirection(t) == TextDirection.rtl;
  final arabicUi = l10n.localeName.startsWith('ar');
  if (arabicUi != rtlText) return null;
  return t;
}

/// The message for one form field of a failed request: the server's own
/// words when [safeServerMessage] allows them, else "Check this field."
/// Null when the field has no error.
String? safeFieldError(AppLocalizations l10n, Object? error, String field) {
  if (error is! ApiException) return null;
  final raw = error.firstErrorFor(field);
  if (raw == null) return null;
  return safeServerMessage(l10n, raw) ?? l10n.errorFieldInvalid;
}

/// Every safe field message of a validation failure, in order, without
/// repeats (for a summary under a form).
List<String> safeFieldErrors(AppLocalizations l10n, ApiException error) => [
  ...{
    for (final list in error.fieldErrors.values)
      for (final m in list) ?safeServerMessage(l10n, m),
  },
];

String? _firstSafeFieldError(AppLocalizations l10n, ApiException e) =>
    safeFieldErrors(l10n, e).firstOrNull;
