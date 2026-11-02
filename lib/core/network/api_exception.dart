/// Failure categories of the WorkFlow API.
///
/// Contract (Postman collection, §5): every error is
/// `{success: false, message, errors}`. Login answers 403 — not 401 — for a
/// deactivated, unverified or never-activated account; 429 carries
/// `retry_after`.
enum ApiFailureKind {
  network,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  server,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  const new({
    required this.kind,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  final ApiFailureKind kind;

  /// Server-provided message when available. UI should prefer localized text
  /// per [kind] and show this only as detail.
  final String message;
  final int? statusCode;

  /// Laravel validation errors keyed by request field.
  final Map<String, List<String>> fieldErrors;
  final int? retryAfterSeconds;

  String? firstErrorFor(String field) {
    final errors = fieldErrors[field];
    return (errors == null || errors.isEmpty) ? null : errors.first;
  }

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
