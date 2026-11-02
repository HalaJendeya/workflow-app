import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Demo-mode stand-in, only wired when `APP_MODE=mock`. It never contacts the
/// server and the UI labels the whole app as demo data in this mode.
class MockAuthRepository implements AuthRepository {
  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async => Session(
    token: 'demo-token',
    tokenType: 'Bearer',
    userId: 1,
    companyId: 1,
    portal: portal,
  );

  @override
  Future<void> logout() async {}

  @override
  Future<RegistrationResult> registerClient({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async => const RegistrationResult(userId: 1, verificationRequired: true);

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {}

  @override
  Future<void> resendVerificationCode({required String email}) async {}

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {}
}
