import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/features/auth/presentation/auth_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/viewport.dart';

/// Every failure reaches the user as a localized sentence with a next
/// step: no raw exception, status code, URL, route or untranslated server
/// text. 401, 403, 404 and 5xx keep their own meanings.

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _ar = lookupAppLocalizations(const Locale('ar'));

ApiException _status(int code, [Map<String, Object?> body = const {}]) =>
    ApiEnvelope.fromBody(code, {...body});

DioException _dio(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/employee/tasks'),
  type: type,
  message: 'SocketException: Failed host lookup: api.example.test',
);

/// Arabic letters, and none of the Latin technical words.
final _latin = RegExp('[A-Za-z]');

void main() {
  group('status and transport mapping', () {
    test('timeouts and lost connections are told apart', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(ApiEnvelope.fromDio(_dio(t)).kind, ApiFailureKind.timeout);
      }
      expect(
        ApiEnvelope.fromDio(_dio(DioExceptionType.connectionError)).kind,
        ApiFailureKind.network,
      );
    });

    test('each status has its own kind', () {
      expect(
        {
          for (final c in [
            400,
            401,
            403,
            404,
            409,
            422,
            429,
            500,
            502,
            503,
            418,
          ])
            c: _status(c).kind,
        },
        {
          400: ApiFailureKind.badRequest,
          401: ApiFailureKind.unauthorized,
          403: ApiFailureKind.forbidden,
          404: ApiFailureKind.notFound,
          409: ApiFailureKind.conflict,
          422: ApiFailureKind.validation,
          429: ApiFailureKind.rateLimited,
          500: ApiFailureKind.server,
          502: ApiFailureKind.server,
          503: ApiFailureKind.server,
          418: ApiFailureKind.unknown,
        },
      );
    });

    test('a malformed response is a server-side fault, not a crash text', () {
      Object? caught;
      try {
        missingField('data.tasks');
      } on Object catch (e) {
        caught = e;
      }
      expect(localizedError(_en, caught), _en.errorServer);
      expect(localizedError(_en, caught), isNot(contains('data.tasks')));
    });
  });

  group('localized sentences', () {
    final cases = <String, Object>{
      'offline': ApiEnvelope.fromDio(_dio(DioExceptionType.connectionError)),
      'timeout': ApiEnvelope.fromDio(_dio(DioExceptionType.receiveTimeout)),
      '400': _status(400, {'message': 'Bad Request'}),
      '401': _status(401, {'message': 'Unauthenticated.'}),
      '403': _status(403, {'message': 'This action is unauthorized.'}),
      '404': _status(404, {'message': 'No query results for model [Task].'}),
      '409': _status(409, {'message': 'Timesheet approved'}),
      '422': _status(422, {'message': 'The given data was invalid.'}),
      '429': _status(429, {'message': 'Too Many Attempts.', 'retry_after': 30}),
      '500': _status(500, {'message': 'Server Error'}),
      'state': StateError('Bad state: No element'),
      'format': const FormatException('Unexpected character at 1'),
    };

    test('English matches the product wording', () {
      final got = {
        for (final e in cases.entries) e.key: localizedError(_en, e.value),
      };
      expect(
        got['offline'],
        "You're offline. Check your connection and try again.",
      );
      expect(
        got['timeout'],
        'This is taking longer than expected. Please try again.',
      );
      expect(got['500'], 'Something went wrong. Please try again later.');
      expect(got['403'], "You don't have permission to perform this action.");
      expect(got['401'], 'Your session has expired. Please sign in again.');
      expect(got['404'], contains('may no longer be available'));
      expect(got['409'], contains('Refresh and try again'));
      expect(got['429'], contains('30'));
      expect(got['400'], contains('Check the details'));
      expect(got['state'], _en.errorUnknown);
      expect(got['format'], _en.errorUnknown);
      // 403 is not an expired session; 404 is not an outage.
      expect(got['403'], isNot(got['401']));
      expect(got['404'], isNot(got['500']));
    });

    test('no raw server or exception text in either language', () {
      for (final l10n in [_en, _ar]) {
        for (final e in cases.entries) {
          final text = localizedError(l10n, e.value);
          for (final leak in [
            'Exception',
            'Bad state',
            'Unauthenticated',
            'unauthorized',
            'No query results',
            'Server Error',
            'api.example.test',
            '/api/',
            'HTTP',
            '500',
            '404',
          ]) {
            expect(text, isNot(contains(leak)), reason: '${e.key}: $text');
          }
        }
      }
    });

    test('Arabic sentences are Arabic only', () {
      for (final e in cases.entries) {
        final text = localizedError(_ar, e.value);
        expect(text, isNot(contains(_latin)), reason: '${e.key}: $text');
      }
    });
  });

  group('server validation details', () {
    ApiException invalid(Map<String, List<String>> errors) => _status(422, {
      'message': 'The given data was invalid.',
      'errors': errors,
    });

    test('a safe message in the UI language is kept, per field', () {
      final e = invalid({
        'title': ['The title field is required.'],
      });
      expect(localizedError(_en, e), 'The title field is required.');
      expect(safeFieldError(_en, e, 'title'), 'The title field is required.');
      expect(safeFieldError(_en, e, 'priority'), isNull);
    });

    test('an English message is not shown in the Arabic UI', () {
      final e = invalid({
        'title': ['The title field is required.'],
      });
      expect(localizedError(_ar, e), _ar.errorValidation);
      expect(safeFieldError(_ar, e, 'title'), _ar.errorFieldInvalid);
    });

    test('an Arabic message is shown in the Arabic UI', () {
      final e = invalid({
        'title': ['حقل العنوان مطلوب.'],
      });
      expect(localizedError(_ar, e), 'حقل العنوان مطلوب.');
    });

    test('technical or oversized text is never shown', () {
      for (final m in [
        'SQLSTATE[23000]: Integrity constraint violation',
        r'Call to undefined method App\Models\Task::foo()',
        'See https://api.example.test/api/v1/tasks for details',
        'Token mismatch for bearer abc',
        'x' * 200,
        'Line one\nLine two',
      ]) {
        final e = invalid({
          'title': [m],
        });
        expect(localizedError(_en, e), _en.errorValidation, reason: m);
        expect(safeFieldError(_en, e, 'title'), _en.errorFieldInvalid);
      }
    });

    test('a summary lists each safe message once', () {
      final e = invalid({
        'title': ['Title is too long.'],
        'name': ['Title is too long.', 'SQLSTATE boom'],
        'date': ['The date must be today or later.'],
      });
      expect(safeFieldErrors(_en, e), [
        'Title is too long.',
        'The date must be today or later.',
      ]);
    });
  });

  Future<void> pumpIn(
    WidgetTester tester,
    Locale locale,
    Brightness brightness,
    Widget Function(BuildContext) child,
  ) async {
    useViewport(tester, const Size(360, 740));
    await loadAppFonts();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Builder(builder: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (locale, brightness) in [
    (const Locale('en'), Brightness.light),
    (const Locale('ar'), Brightness.dark),
  ]) {
    final name = '${locale.languageCode} ${brightness.name}';

    testWidgets('a failed load shows the sentence and Retry: $name', (
      tester,
    ) async {
      var retried = 0;
      await pumpIn(
        tester,
        locale,
        brightness,
        (_) => AsyncSection<List<int>>(
          value: AsyncError(
            _status(500, {'message': 'SQLSTATE[HY000] boom'}),
            StackTrace.empty,
          ),
          onRetry: () => retried++,
          builder: (_) => const Text('rows'),
        ),
      );
      final l10n = locale.languageCode == 'ar' ? _ar : _en;
      expect(find.text(l10n.errorServer), findsOneWidget);
      expect(find.textContaining('SQLSTATE'), findsNothing);
      await tester.tap(find.byKey(const Key('api-retry')));
      expect(retried, 1);
      expect(
        Directionality.of(tester.element(find.text(l10n.errorServer))),
        locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    });

    testWidgets('an empty list is not a failure: $name', (tester) async {
      await pumpIn(
        tester,
        locale,
        brightness,
        (_) => AsyncSection<List<int>>(
          value: const AsyncData([]),
          onRetry: () {},
          builder: (rows) => Text('rows ${rows.length}'),
        ),
      );
      expect(find.text('rows 0'), findsOneWidget);
      expect(find.byKey(const Key('api-retry')), findsNothing);
    });

    testWidgets('sign-in refusals: $name', (tester) async {
      final l10n = locale.languageCode == 'ar' ? _ar : _en;
      for (final (code, english, fallback) in [
        (401, 'Invalid credentials.', l10n.errorSignInFailed),
        (403, 'Your account is deactivated.', l10n.errorSignInBlocked),
      ]) {
        await pumpIn(
          tester,
          locale,
          brightness,
          (context) => TextButton(
            onPressed: () =>
                showAuthError(context, _status(code, {'message': english})),
            child: const Text('go'),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        // English UI: the server's own safe reason. Arabic UI: the
        // localized sentence, never the English text.
        expect(
          find.text(locale.languageCode == 'ar' ? fallback : english),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        // Not "session expired" on the sign-in screen.
        expect(find.text(l10n.errorSessionExpired), findsNothing);
      }
    });
  }
}
