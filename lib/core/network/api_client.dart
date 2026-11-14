import 'package:dio/dio.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// Credentials the HTTP layer needs per request. Kept as a small interface so
/// the network layer does not depend on the auth feature.
abstract interface class ApiCredentials {
  String? get token;

  /// Active tenant, sent as `X-Company` on role-scoped routes.
  int? get companyId;

  /// Called when the server rejects the token (401) so the session can end.
  void onUnauthorized();
}

/// Thin typed wrapper around Dio. All requests go through here; widgets and
/// controllers never touch HTTP directly.
class ApiClient {
  new({
    required String baseUrl,
    required ApiCredentials credentials,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
           headers: const {'Accept': 'application/json'},
         ),
       ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(_AuthInterceptor(credentials));
  }

  final Dio _dio;

  /// [headers] are added to this request only. A request that carries its
  /// own `Authorization` keeps it: the session token is not swapped in.
  Future<Response<Object?>> get(
    String path, {
    Json? query,
    Map<String, String>? headers,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
    ),
  );

  Future<Response<Object?>> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: headers == null ? null : Options(headers: headers),
    ),
  );

  Future<Response<Object?>> put(String path, {Object? body}) =>
      _send(() => _dio.put<Object?>(path, data: body));

  Future<Response<Object?>> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<Object?>(path, data: body));

  Future<Response<Object?>> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<Object?>(path, data: body));

  Future<Response<Object?>> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiEnvelope.fromDio(e);
    } on ApiException {
      rethrow;
    }
  }
}

/// Routes under these prefixes are tenant-scoped and carry `X-Company`
/// (collection §4: "Sent on every role-folder request; never on 01 Auth").
const _tenantPrefixes = ['/api/v1/client/', '/api/v1/employee/'];

/// Public auth routes: no bearer token, no tenant header. Of the `01 Auth`
/// folder only `logout` and `account/setup/resend` are authenticated.
const _publicPaths = {
  '/api/v1/login',
  '/api/v1/register',
  '/api/v1/verify-email-otp',
  '/api/v1/verify-email-token',
  '/api/v1/resend-verification-code',
  '/api/v1/forgot-password',
  '/api/v1/verify-otp-forgot-password',
  '/api/v1/reset-password-form',
  '/api/v1/reset-password',
  '/api/v1/account/setup',
};

class _AuthInterceptor extends Interceptor {
  new(this._credentials);

  final ApiCredentials _credentials;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.uri.path;
    if (!_publicPaths.contains(path)) {
      final token = _credentials.token;
      if (token != null && !options.headers.containsKey('Authorization')) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      final companyId = _credentials.companyId;
      if (companyId != null && _tenantPrefixes.any(path.startsWith)) {
        options.headers['X-Company'] = companyId.toString();
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isPublic = _publicPaths.contains(err.requestOptions.uri.path);
    if (err.response?.statusCode == 401 && !isPublic) {
      _credentials.onUnauthorized();
    }
    handler.next(err);
  }
}
