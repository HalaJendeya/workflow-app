import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Number of OTP boxes in the Figma "Verification Code" frame (137:26665).
/// The API does not document the code length (see the backend gap report).
const kOtpLength = 4;

/// Minimum password length enforced by `POST /api/v1/register` and
/// `POST /api/v1/reset-password` (`min:6`).
const kMinPasswordLength = 6;

/// Portal chosen on the Account Type screen (Figma 150:2174). Employee is the
/// preselected card in the design.
final selectedPortalProvider = NotifierProvider<PortalSelection, Portal>(
  PortalSelection.new,
);

class PortalSelection extends Notifier<Portal> {
  @override
  Portal build() => Portal.employee;

  // A named method reads better than a setter at call sites.
  // ignore: use_setters_to_change_properties
  void select(Portal portal) => state = portal;
}

enum OtpPurpose { emailVerification, passwordReset }

/// Application-layer entry points for the public auth screens, so widgets
/// never call the repository directly.
class AuthFlow {
  const new(this._repo);

  final AuthRepository _repo;

  Future<RegistrationResult> registerClient({
    required String name,
    required String email,
    required String password,
  }) => _repo.registerClient(
    name: name,
    email: email,
    password: password,
    // The Figma registration form has no confirmation field; the API
    // requires `password_confirmation`, so the single entry is confirmed.
    passwordConfirmation: password,
  );

  Future<void> verifyOtp({
    required OtpPurpose purpose,
    required String email,
    required String otp,
  }) => switch (purpose) {
    OtpPurpose.emailVerification => _repo.verifyEmailOtp(
      email: email,
      otp: otp,
    ),
    OtpPurpose.passwordReset => _repo.verifyPasswordResetOtp(
      email: email,
      otp: otp,
    ),
  };

  Future<void> resendOtp({
    required OtpPurpose purpose,
    required String email,
  }) => switch (purpose) {
    OtpPurpose.emailVerification => _repo.resendVerificationCode(email: email),
    OtpPurpose.passwordReset => _repo.requestPasswordReset(email: email),
  };

  Future<void> requestPasswordReset(String email) =>
      _repo.requestPasswordReset(email: email);

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmation,
  }) => _repo.resetPassword(
    email: email,
    otp: otp,
    password: password,
    passwordConfirmation: confirmation,
  );
}

final authFlowProvider = Provider<AuthFlow>(
  (ref) => AuthFlow(ref.watch(authRepositoryProvider)),
);
