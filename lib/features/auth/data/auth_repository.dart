import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Authentication operations. Every method maps 1:1 to a request in the
/// `01 Auth` folder of the WorkFlow Postman collection.
abstract interface class AuthRepository {
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  });

  Future<void> logout();

  /// Clients are the only self-registering role; `account_type` is fixed to
  /// `client`. Employees receive credentials from their Company Admin.
  Future<RegistrationResult> registerClient({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  });

  Future<void> verifyEmailOtp({required String email, required String otp});
  Future<void> resendVerificationCode({required String email});
  Future<void> requestPasswordReset({required String email});
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  });
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  });
}

class ApiAuthRepository implements AuthRepository {
  new(this._client);

  final ApiClient _client;

  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post(
        '/api/v1/login',
        body: {'email': email, 'password': password},
      ),
    );
    final user = data['user'];
    final token = data['token'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Login response is missing data.token or data.user.',
      );
    }
    final userId = _asInt(user['id']);
    if (userId == null) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Login response is missing data.user.id.',
      );
    }
    final session = Session(
      token: token,
      tokenType: data['token_type'] as String? ?? 'Bearer',
      userId: userId,
      companyId: _asInt(user['company_id']),
      portal: portal,
    );
    await _confirmPortal(session);
    return session;
  }

  /// The login response names no role, so the chosen portal is checked
  /// with that portal's profile route (read-only, `account.view`), which
  /// its `role:` gate refuses with 403 for any other role. No `X-Company`
  /// is sent: the tenant falls back to the account's own company.
  ///
  /// If the check fails for any reason the new token is revoked
  /// (best effort) so no usable token is left behind, and nothing is
  /// stored; a 403 becomes [PortalMismatch].
  Future<void> _confirmPortal(Session session) async {
    final auth = {'Authorization': 'Bearer ${session.token}'};
    try {
      ApiEnvelope.unwrapData(
        await _client.get(
          '/api/v1/${session.portal.name}/account',
          headers: auth,
        ),
      );
    } on ApiException catch (e) {
      try {
        await _client.post('/api/v1/logout', headers: auth);
      } on ApiException {
        // Revocation is best effort; the token is never stored either way.
      }
      if (e.kind == ApiFailureKind.forbidden) {
        throw PortalMismatch(session.portal);
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    ApiEnvelope.unwrapData(await _client.post('/api/v1/logout'));
  }

  @override
  Future<RegistrationResult> registerClient({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post(
        '/api/v1/register',
        body: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'account_type': 'client',
        },
      ),
    );
    final user = data['user'];
    final userId = user is Map<String, dynamic> ? _asInt(user['id']) : null;
    if (userId == null) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Register response is missing data.user.id.',
      );
    }
    return RegistrationResult(
      userId: userId,
      verificationRequired: data['verification_required'] == true,
    );
  }

  @override
  Future<void> verifyEmailOtp({required String email, required String otp}) =>
      _postOk('/api/v1/verify-email-otp', {'email': email, 'otp': otp});

  @override
  Future<void> resendVerificationCode({required String email}) =>
      _postOk('/api/v1/resend-verification-code', {'email': email});

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _postOk('/api/v1/forgot-password', {'email': email});

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) => _postOk('/api/v1/verify-otp-forgot-password', {
    'email': email,
    'otp': otp,
  });

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) => _postOk('/api/v1/reset-password', {
    'email': email,
    'otp': otp,
    'password': password,
    'password_confirmation': passwordConfirmation,
  });

  Future<void> _postOk(String path, Json body) async {
    ApiEnvelope.unwrapData(await _client.post(path, body: body));
  }
}

int? _asInt(Object? v) => v is int ? v : (v is String ? int.tryParse(v) : null);
