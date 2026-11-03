import 'package:workflow_app/features/auth/application/auth_flow.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

enum SuccessKind { accountCreated, passwordReset }

/// Arguments for the new-password screen (kept out of the URL).
class ResetArgs {
  const new({required this.email, required this.otp});
  final String email;
  final String otp;
}

/// Route paths in one place.
abstract final class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verify = '/verify';
  static const resetPassword = '/reset-password';
  static const success = '/success';

  static const client = '/client';
  static const clientCompanies = '/client/companies';
  static const clientInvoices = '/client/invoices';
  static const clientChat = '/client/chat';
  static const clientMore = '/client/more';

  static const employee = '/employee';
  static const employeeSprints = '/employee/sprints';
  static const employeeProjects = '/employee/projects';
  static const employeeChat = '/employee/chat';
  static const employeeMore = '/employee/more';

  /// Routes reachable without a session.
  static const Set<String> public = {
    welcome,
    login,
    register,
    forgotPassword,
    verify,
    resetPassword,
    success,
  };

  static String homeFor(Portal portal) =>
      portal == Portal.client ? client : employee;

  static String verifyLocation(OtpPurpose purpose, String email) => Uri(
    path: verify,
    queryParameters: {'purpose': purpose.name, 'email': email},
  ).toString();

  static String authSuccess(SuccessKind kind) =>
      Uri(path: success, queryParameters: {'kind': kind.name}).toString();
}
