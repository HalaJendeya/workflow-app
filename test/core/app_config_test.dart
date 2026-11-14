import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/config/app_config.dart';

void main() {
  test('api mode requires a base URL', () {
    expect(
      const AppConfig(mode: AppMode.api, apiBaseUrl: '').validate,
      throwsA(isA<ConfigException>()),
    );
  });

  test('base URL must be host only (collection convention)', () {
    expect(
      const AppConfig(
        mode: AppMode.api,
        apiBaseUrl: 'https://api.test/api',
      ).validate,
      throwsA(isA<ConfigException>()),
    );
  });

  test('a base URL that already has /api/v1 is refused (no double prefix)', () {
    expect(
      const AppConfig(
        mode: AppMode.api,
        apiBaseUrl: 'https://api.workflownets.com/api/v1',
      ).validate,
      throwsA(isA<ConfigException>()),
    );
  });

  test('the WorkFlow backend host is a valid API base URL', () {
    const AppConfig(
      mode: AppMode.api,
      apiBaseUrl: 'https://api.workflownets.com',
    ).validate();
  });

  test('valid api config and mock config pass', () {
    const AppConfig(
      mode: AppMode.api,
      apiBaseUrl: 'https://api.test',
    ).validate();
    const AppConfig(mode: AppMode.mock, apiBaseUrl: '').validate();
  });
}
