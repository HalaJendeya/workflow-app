import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';

import '../../helpers/fake_http_adapter.dart';

class _Creds implements ApiCredentials {
  @override
  String? token = 'tkn';
  @override
  int? companyId = 25;
  int unauthorizedCalls = 0;
  @override
  void onUnauthorized() => unauthorizedCalls++;
}

void main() {
  late FakeHttpAdapter http;
  late _Creds creds;
  late ApiClient client;

  setUp(() {
    http = FakeHttpAdapter();
    creds = _Creds();
    client = ApiClient(
      baseUrl: 'https://api.test',
      credentials: creds,
      adapter: http,
    );
  });

  group('headers', () {
    test('public auth routes carry neither bearer nor X-Company', () async {
      http.reply(200, ok({}));
      await client.post('/api/v1/login', body: {});
      expect(http.last.headers.containsKey('Authorization'), isFalse);
      expect(http.last.headers.containsKey('X-Company'), isFalse);
      expect(http.last.headers['Accept'], 'application/json');
    });

    test('role routes carry bearer token and decimal X-Company', () async {
      http.reply(200, ok({}));
      await client.get('/api/v1/client/dashboard');
      expect(http.last.headers['Authorization'], 'Bearer tkn');
      expect(http.last.headers['X-Company'], '25');
    });

    test('logout carries bearer but no X-Company', () async {
      http.reply(200, ok(null));
      await client.post('/api/v1/logout');
      expect(http.last.headers['Authorization'], 'Bearer tkn');
      expect(http.last.headers.containsKey('X-Company'), isFalse);
    });

    test('X-Company omitted when no company is known', () async {
      creds.companyId = null;
      http.reply(200, ok({}));
      await client.get('/api/v1/employee/tasks');
      expect(http.last.headers.containsKey('X-Company'), isFalse);
    });
  });

  group('error mapping', () {
    Future<ApiException> errorFor(int status, Object body) async {
      http.reply(status, body, headers: {'retry-after': '17'});
      try {
        await client.get('/api/v1/client/projects');
      } on ApiException catch (e) {
        return e;
      }
      fail('expected ApiException');
    }

    test('422 exposes Laravel field errors', () async {
      final e = await errorFor(
        422,
        failure(
          'The given data was invalid.',
          errors: {
            'email': ['The email field is required.'],
          },
        ),
      );
      expect(e.kind, ApiFailureKind.validation);
      expect(e.firstErrorFor('email'), 'The email field is required.');
    });

    test('401 ends the session via onUnauthorized', () async {
      final e = await errorFor(401, failure('Unauthenticated.'));
      expect(e.kind, ApiFailureKind.unauthorized);
      expect(creds.unauthorizedCalls, 1);
    });

    test('401 on login does not end a session', () async {
      http.reply(401, failure('Invalid credentials'));
      await expectLater(
        client.post('/api/v1/login', body: {}),
        throwsA(isA<ApiException>()),
      );
      expect(creds.unauthorizedCalls, 0);
    });

    test('403 maps to forbidden', () async {
      expect(
        (await errorFor(403, failure('Forbidden'))).kind,
        ApiFailureKind.forbidden,
      );
    });

    test('429 reads retry_after from the body before the header', () async {
      final e = await errorFor(429, {
        ...failure('Too many attempts'),
        'retry_after': 42,
      });
      expect(e.kind, ApiFailureKind.rateLimited);
      expect(e.retryAfterSeconds, 42);
    });

    test('429 falls back to the Retry-After header', () async {
      final e = await errorFor(429, failure('Too many attempts'));
      expect(e.retryAfterSeconds, 17);
    });

    test('5xx maps to server', () async {
      expect(
        (await errorFor(500, failure('Server Error'))).kind,
        ApiFailureKind.server,
      );
    });

    test('connection failures map to network', () async {
      http.failWith(DioExceptionType.connectionError);
      await expectLater(
        client.get('/api/v1/client/projects'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.network,
          ),
        ),
      );
    });
  });

  group('envelope', () {
    test('success:false with 200 is still an error', () async {
      http.reply(200, failure('Nope'));
      final response = await client.get('/api/v1/client/projects');
      expect(
        () => ApiEnvelope.unwrapData(response),
        throwsA(isA<ApiException>()),
      );
    });

    test('non-object body is invalidResponse', () async {
      http.reply(200, [1, 2]);
      final response = await client.get('/api/v1/client/projects');
      expect(
        () => ApiEnvelope.unwrapObject(response),
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
}
