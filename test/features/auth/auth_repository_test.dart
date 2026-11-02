import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../../helpers/fake_http_adapter.dart';

class _NoCreds implements ApiCredentials {
  @override
  String? get token => null;
  @override
  int? get companyId => null;
  @override
  void onUnauthorized() {}
}

void main() {
  late FakeHttpAdapter http;
  late ApiAuthRepository repo;

  setUp(() {
    http = FakeHttpAdapter();
    repo = ApiAuthRepository(
      ApiClient(
        baseUrl: 'https://api.test',
        credentials: _NoCreds(),
        adapter: http,
      ),
    );
  });

  group('login (POST /api/v1/login)', () {
    test('sends email/password and builds a session', () async {
      http.reply(
        200,
        ok({
          'token': '1|abc',
          'token_type': 'Bearer',
          'user': {'id': 7, 'company_id': 25},
        }),
      );
      final s = await repo.login(
        email: 'a@b.co',
        password: 'secret',
        portal: Portal.employee,
      );
      expect(http.last.method, 'POST');
      expect(http.last.path, '/api/v1/login');
      expect(http.lastJsonBody, {'email': 'a@b.co', 'password': 'secret'});
      expect(s.token, '1|abc');
      expect(s.userId, 7);
      expect(s.companyId, 25);
      expect(s.portal, Portal.employee);
    });

    test('accepts a client without a company', () async {
      http.reply(
        200,
        ok({
          'token': 't',
          'token_type': 'Bearer',
          'user': {'id': 3, 'company_id': null},
        }),
      );
      final s = await repo.login(
        email: 'a@b.co',
        password: 'x',
        portal: Portal.client,
      );
      expect(s.companyId, isNull);
    });

    test('403 (unverified / deactivated) surfaces as forbidden', () async {
      http.reply(403, failure('Please verify your email.'));
      await expectLater(
        repo.login(email: 'a@b.co', password: 'x', portal: Portal.client),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.forbidden,
          ),
        ),
      );
    });

    test('missing token is rejected, not silently accepted', () async {
      http.reply(
        200,
        ok({
          'user': {'id': 1},
        }),
      );
      await expectLater(
        repo.login(email: 'a@b.co', password: 'x', portal: Portal.client),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  test('registerClient always sends account_type=client', () async {
    http.reply(
      201,
      ok({
        'user': {'id': 9},
        'verification_required': true,
      }),
    );
    final r = await repo.registerClient(
      name: 'Jane',
      email: 'j@d.co',
      password: 'secret1',
      passwordConfirmation: 'secret1',
    );
    expect(http.last.path, '/api/v1/register');
    expect(http.lastJsonBody['account_type'], 'client');
    expect(http.lastJsonBody.containsKey('company_name'), isFalse);
    expect(r.userId, 9);
    expect(r.verificationRequired, isTrue);
  });

  test('password reset flow hits the documented routes', () async {
    for (var i = 0; i < 3; i++) {
      http.reply(200, ok(null));
    }
    await repo.requestPasswordReset(email: 'a@b.co');
    await repo.verifyPasswordResetOtp(email: 'a@b.co', otp: '123456');
    await repo.resetPassword(
      email: 'a@b.co',
      otp: '123456',
      password: 'newpass',
      passwordConfirmation: 'newpass',
    );
    expect(http.requests.map((r) => r.path), [
      '/api/v1/forgot-password',
      '/api/v1/verify-otp-forgot-password',
      '/api/v1/reset-password',
    ]);
    expect(http.lastJsonBody, {
      'email': 'a@b.co',
      'otp': '123456',
      'password': 'newpass',
      'password_confirmation': 'newpass',
    });
  });

  test('email verification and resend', () async {
    http
      ..reply(200, ok(null))
      ..reply(200, ok(null));
    await repo.verifyEmailOtp(email: 'a@b.co', otp: '123456');
    await repo.resendVerificationCode(email: 'a@b.co');
    expect(http.requests.map((r) => r.path), [
      '/api/v1/verify-email-otp',
      '/api/v1/resend-verification-code',
    ]);
  });
}
