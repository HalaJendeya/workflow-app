import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Maps an error to a localized, user-facing sentence.
String localizedError(AppLocalizations l10n, Object error) {
  if (error is! ApiException) return l10n.errorUnknown;
  return switch (error.kind) {
    ApiFailureKind.network => l10n.errorNetwork,
    ApiFailureKind.unauthorized => l10n.errorSessionExpired,
    ApiFailureKind.forbidden => l10n.errorForbidden,
    ApiFailureKind.notFound => l10n.errorNotFound,
    ApiFailureKind.validation => l10n.errorValidation,
    ApiFailureKind.rateLimited => l10n.errorRateLimited(
      error.retryAfterSeconds ?? 60,
    ),
    ApiFailureKind.server => l10n.errorServer,
    ApiFailureKind.conflict ||
    ApiFailureKind.invalidResponse ||
    ApiFailureKind.unknown => l10n.errorUnknown,
  };
}
