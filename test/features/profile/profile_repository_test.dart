import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/features/profile/presentation/profile_screen.dart';

import '../../helpers/fake_http_adapter.dart';

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 25;
  @override
  void onUnauthorized() {}
}

void main() {
  late FakeHttpAdapter http;
  ApiProfileRepository repoFor(Portal p) => ApiProfileRepository(
    ApiClient(
      baseUrl: 'https://api.test',
      credentials: _Creds(),
      adapter: http,
    ),
    p,
  );

  setUp(() => http = FakeHttpAdapter());

  test('update sends only changed fields and parses the user', () async {
    http.reply(
      200,
      ok({
        'id': 7,
        'email': 'jane@workflow.com',
        'name': 'Jane Doe',
        'image_url': null,
      }),
    );
    final p = await repoFor(Portal.client).update(name: 'Jane Doe');
    expect(http.last.method, 'PATCH');
    expect(http.last.path, '/api/v1/client/account');
    expect(http.lastJsonBody, {'name': 'Jane Doe'});
    expect(p.name, 'Jane Doe');
    expect(p.email, 'jane@workflow.com');
  });

  test('invalid email surfaces 422 field errors', () async {
    http.reply(
      422,
      failure(
        'The email field must be a valid email address.',
        errors: {
          'email': ['The email field must be a valid email address.'],
        },
      ),
    );
    await expectLater(
      repoFor(Portal.employee).update(email: 'not-an-email'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiFailureKind.validation)
            .having((e) => e.firstErrorFor('email'), 'email', isNotNull),
      ),
    );
    expect(http.last.path, '/api/v1/employee/account');
  });

  test('change password posts the documented body', () async {
    http.reply(200, ok(null));
    await repoFor(Portal.client)
        .changePassword(oldPassword: 'old', newPassword: 'NewPassword123!');
    expect(http.last.method, 'PATCH');
    expect(http.last.path, '/api/v1/client/account/password');
    expect(http.lastJsonBody, {
      'old_password': 'old',
      'new_password': 'NewPassword123!',
      'new_password_confirmation': 'NewPassword123!',
    });
  });

  test('delete account calls the delete route', () async {
    http.reply(200, ok(null));
    await repoFor(Portal.employee).deleteAccount();
    expect(http.last.method, 'DELETE');
    expect(http.last.path, '/api/v1/employee/account/delete');
  });

  test('password rule needs letters, numbers and symbols', () {
    expect(isStrongPassword('abc12345'), isFalse);
    expect(isStrongPassword('abc1234!'), isTrue);
    expect(isStrongPassword('a1!'), isFalse);
  });
}
