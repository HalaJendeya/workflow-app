import 'package:dio/dio.dart';
import 'package:workflow_app/core/network/api_exception.dart';

typedef Json = Map<String, dynamic>;

/// Unwraps the `{success, message, data}` envelope or converts any failure
/// into an [ApiException]. This is the single place response bodies are
/// interpreted, so repositories never handle raw HTTP details.
class ApiEnvelope {
  const new _();

  static Object? unwrapData(Response<Object?> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Expected a JSON object.',
        statusCode: response.statusCode,
      );
    }
    if (body['success'] != true) {
      throw fromBody(response.statusCode, body);
    }
    return body['data'];
  }

  /// The whole successful body, for list endpoints that put `stats`,
  /// `totals`, `series` or `facets` beside `data` (collection: "Work pages
  /// full-stack" and "Finance full-stack", 2026-10-26/27).
  static Json unwrapBody(Response<Object?> response) {
    unwrapData(response);
    return response.data! as Json;
  }

  static Json unwrapObject(Response<Object?> response) {
    final data = unwrapData(response);
    if (data is Map<String, dynamic>) return data;
    throw ApiException(
      kind: ApiFailureKind.invalidResponse,
      message: '`data` is not an object.',
      statusCode: response.statusCode,
    );
  }

  static String? message(Response<Object?> response) {
    final body = response.data;
    return body is Map<String, dynamic> ? body['message'] as String? : null;
  }

  static ApiException fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          kind: ApiFailureKind.network,
          message: error.message ?? 'Network error',
        );
      case DioExceptionType.badResponse:
        final response = error.response!;
        final body = response.data;
        return fromBody(
          response.statusCode,
          body is Map<String, dynamic> ? body : const {},
          retryAfterHeader: response.headers.value('retry-after'),
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ApiException(
          kind: ApiFailureKind.unknown,
          message: error.message ?? 'Unexpected error',
        );
    }
  }

  static ApiException fromBody(
    int? status,
    Json body, {
    String? retryAfterHeader,
  }) {
    final message = body['message'] is String
        ? body['message'] as String
        : 'Request failed';
    final rawErrors = body['errors'];
    final fieldErrors = <String, List<String>>{};
    if (rawErrors is Map<String, dynamic>) {
      rawErrors.forEach((key, value) {
        if (value is List) {
          fieldErrors[key] = value.map((e) => e.toString()).toList();
        } else if (value is String) {
          fieldErrors[key] = [value];
        }
      });
    }
    final retryAfter =
        _int(body['retry_after']) ??
        (rawErrors is Map<String, dynamic>
            ? _int(rawErrors['retry_after'])
            : null) ??
        int.tryParse(retryAfterHeader ?? '');

    return ApiException(
      kind: _kindFor(status),
      message: message,
      statusCode: status,
      fieldErrors: fieldErrors,
      retryAfterSeconds: retryAfter,
    );
  }

  static ApiFailureKind _kindFor(int? status) => switch (status) {
    401 => ApiFailureKind.unauthorized,
    403 => ApiFailureKind.forbidden,
    404 => ApiFailureKind.notFound,
    409 => ApiFailureKind.conflict,
    422 => ApiFailureKind.validation,
    429 => ApiFailureKind.rateLimited,
    final int s when s >= 500 => ApiFailureKind.server,
    _ => ApiFailureKind.unknown,
  };

  static int? _int(Object? v) =>
      v is int ? v : (v is String ? int.tryParse(v) : null);
}
