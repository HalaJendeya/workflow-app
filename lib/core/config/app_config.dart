/// Runtime configuration supplied at build time via `--dart-define` or
/// `--dart-define-from-file=.env`. Nothing secret is hardcoded here.
enum AppMode {
  /// Talks to the real WorkFlow backend at [AppConfig.apiBaseUrl].
  api,

  /// Uses typed local fixtures. Never presents fixture data as server data;
  /// the UI shows a visible "Demo data" marker in this mode.
  mock,
}

class AppConfig {
  const new({required this.mode, required this.apiBaseUrl});

  factory fromEnvironment() {
    const rawMode = String.fromEnvironment('APP_MODE', defaultValue: 'api');
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    final mode = AppMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => throw const ConfigException('Unknown APP_MODE "$rawMode".'),
    );
    return AppConfig(mode: mode, apiBaseUrl: baseUrl)..validate();
  }

  final AppMode mode;

  /// Host only, without `/api` (e.g. `https://api.example.com`), matching the
  /// Postman collection's `base_url` convention.
  final String apiBaseUrl;

  bool get isMock => mode == AppMode.mock;

  void validate() {
    if (mode == AppMode.mock) return;
    final uri = Uri.tryParse(apiBaseUrl);
    if (apiBaseUrl.isEmpty || uri == null || !uri.hasScheme) {
      throw const ConfigException(
        'API_BASE_URL is required in api mode. '
        'Run with --dart-define-from-file=.env (see .env.example).',
      );
    }
    if (uri.path.endsWith('/api') || uri.path.contains('/api/')) {
      throw const ConfigException(
        'API_BASE_URL must be the host only, without the /api path.',
      );
    }
  }
}

/// The source commit this build was made from, passed at build time
/// (`--dart-define=BUILD_SHA=$(git rev-parse --short HEAD)`); `local` when
/// not given. Shown in the account menu so a tester can tell which build
/// is installed.
const buildSha = String.fromEnvironment('BUILD_SHA', defaultValue: 'local');

class ConfigException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
