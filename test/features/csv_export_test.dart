import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/export_csv_chip.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_exports.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';

/// CSV exports end to end on the app side: the server's file (collection,
/// "Added 2026-10-27": `text/csv; charset=UTF-8`, BOM, attachment) reaches
/// the save dialog byte for byte, whatever it holds. The app never parses
/// or rewrites a CSV, so escaping is the server's; these fixtures check
/// that commas, quotes, line breaks and Arabic survive the trip. Every
/// value is a test double; no live export was read for this file.

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 3;
  @override
  void onUnauthorized() {}
}

const _bom = [0xEF, 0xBB, 0xBF];

Uint8List _file(String text) =>
    Uint8List.fromList([..._bom, ...utf8.encode(text)]);

/// RFC 4180 rows (quoted fields may hold commas, `""` and CRLF/LF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\r' || c == '\n') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// The documented employee columns of each export (pay columns left out).
const _headers = {
  'tasks': [
    'Title',
    'Project',
    'Assignee',
    'Status',
    'Priority',
    'Date',
    'Start',
    'End',
    'Duration (min)',
  ],
  'projects': [
    'Title',
    'Client',
    'Company',
    'Leader',
    'Status',
    'Currency',
    'Created',
  ],
  'timesheets': [
    'Employee',
    'Company',
    'Month',
    'Payment type',
    'Rate',
    'Hours',
    'Total',
    'Currency',
    'Status',
  ],
  'backlog': ['Title', 'Assignee', 'Priority', 'Points', 'Status', 'Date'],
};

String _quote(String v) =>
    RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

/// A server-style CSV: header, then [rows] rows whose first field carries
/// a comma, a quote and a line break, and whose second field is Arabic.
String serverCsv(String kind, int rows) {
  final header = _headers[kind]!;
  final out = StringBuffer('${header.map(_quote).join(',')}\r\n');
  for (var r = 1; r <= rows; r++) {
    final fields = [
      'Row $r, "quoted"\nsecond line',
      'مشروع البوابة $r',
      for (var c = 2; c < header.length; c++) 'v$r.$c',
    ];
    out.write('${fields.map(_quote).join(',')}\r\n');
  }
  return out.toString();
}

/// Stands in for the platform's save dialog: what `saveFile` gets, and
/// (on "save") the file it would write.
class _Picker extends FilePickerPlatform {
  new(this.dir);

  final Directory dir;
  bool cancel = false;
  Exception? error;
  final calls = <({String name, String mime, Uint8List bytes})>[];

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls.add((name: fileName, mime: mimeType, bytes: bytes));
    if (error case final e?) throw e;
    if (cancel) return null;
    return (File(
      '${dir.path}${Platform.pathSeparator}$fileName',
    )..writeAsBytesSync(bytes, flush: true)).uri;
  }
}

void main() {
  late FakeHttpAdapter http;
  late EmployeeExportsRepository repo;

  setUp(() {
    http = FakeHttpAdapter();
    repo = EmployeeExportsRepository(
      ApiClient(
        baseUrl: 'https://api.test',
        credentials: _Creds(),
        adapter: http,
      ),
    );
  });

  void serve(String kind, String text, {String? name}) => http.reply(
    200,
    _file(text),
    headers: {
      'content-type': 'text/csv; charset=UTF-8',
      'content-disposition':
          'attachment; filename="${name ?? '$kind-2026-11-19.csv'}"',
    },
  );

  group('each export: route, filters, header, rows, bytes', () {
    final cases =
        <
          (
            String,
            Future<CsvFile> Function(EmployeeExportsRepository),
            String,
            Map<String, Object>,
          )
        >[
          (
            'tasks',
            (r) => r.tasks(
              const TaskQuery(
                search: 'login',
                status: ApiTaskStatus.inReview,
                priority: TaskPriority.low,
                projectId: 2,
                sprintId: 4,
                sort: TaskSort.plannedDate,
              ),
              assignedTo: 10,
            ),
            '/api/v1/employee/tasks/export',
            {
              'month': 'all',
              'assigned_to': 10,
              'search': 'login',
              'status': 'in_review',
              'priority': 'low',
              'project_id': 2,
              'sprint_id': 4,
              'sort': '-task_date',
            },
          ),
          (
            'projects',
            (r) => r.projects(
              search: ' بوابة ',
              status: ApiProjectStatus.completed,
            ),
            '/api/v1/employee/projects/export',
            {'search': 'بوابة', 'status': 'completed'},
          ),
          (
            'timesheets',
            (r) => r.timesheets(month: '2026-10', status: 'rejected'),
            '/api/v1/employee/timesheets/export',
            {'month': '2026-10', 'status': 'rejected'},
          ),
          (
            'backlog',
            (r) => r.backlog(projectId: 7, search: ' دخول '),
            '/api/v1/employee/sprints/backlog/export',
            {'project_id': 7, 'search': 'دخول'},
          ),
        ];

    for (final (kind, call, path, query) in cases) {
      test(kind, () async {
        final text = serverCsv(kind, 3);
        serve(kind, text);
        final file = await call(repo);

        final r = http.last;
        expect(r.method, 'GET');
        expect(r.path, path);
        expect(r.queryParameters, query);
        expect(r.queryParameters.containsKey('page'), isFalse);
        expect(r.queryParameters.containsKey('per_page'), isFalse);
        expect(r.headers['Accept'], 'text/csv');
        expect(r.headers['Authorization'], 'Bearer t');
        expect(r.headers['X-Company'], '3');

        expect(file.fileName, '$kind-2026-11-19.csv');
        // Byte for byte, BOM included: nothing re-encoded or trimmed.
        expect(file.bytes, _file(text));
        expect(file.bytes.sublist(0, 3), _bom);
        final rows = parseCsv(utf8.decode(file.bytes.sublist(3)));
        expect(rows.first, _headers[kind]);
        expect(rows.skip(1), hasLength(3));
        expect(rows[1][0], 'Row 1, "quoted"\nsecond line');
        expect(rows[3][1], 'مشروع البوابة 3');
        for (final row in rows) {
          expect(row, hasLength(_headers[kind]!.length));
        }
        // Employees never get pay columns (collection + live headers).
        expect(rows.first, isNot(contains('Cost')));
        expect(rows.first, isNot(contains('Budget')));
      });
    }

    test('no filters set: only what the list always sends', () async {
      for (final call in <Future<CsvFile> Function()>[
        () => repo.tasks(const TaskQuery()),
        () => repo.projects(),
        () => repo.timesheets(),
        () => repo.backlog(),
      ]) {
        serve('x', 'A\r\n');
        await call();
      }
      expect(
        [for (final r in http.requests) r.queryParameters],
        [
          // The default sort is the server's own (-created_at): not sent.
          {'month': 'all'},
          <String, Object>{},
          <String, Object>{},
          <String, Object>{},
        ],
      );
    });
  });

  group('file edge cases', () {
    test('an empty result is a header-only file, still saved', () async {
      serve('tasks', '${_headers['tasks']!.join(',')}\r\n');
      final file = await repo.tasks(const TaskQuery());
      final rows = parseCsv(utf8.decode(file.bytes.sublist(3)));
      expect(rows, [_headers['tasks']]);
    });

    test('a 0-byte 200 CSV is passed on as it is', () async {
      http.reply(
        200,
        Uint8List(0),
        headers: {'content-type': 'text/csv; charset=UTF-8'},
      );
      final file = await repo.backlog();
      expect(file.bytes, isEmpty);
      expect(file.fileName, 'backlog.csv');
    });

    test('file name: quoted, bare, path parts, missing', () async {
      Future<String> name(String? disposition) async {
        http.reply(
          200,
          _file('A\r\n'),
          headers: {
            'content-type': 'text/csv',
            'content-disposition': ?disposition,
          },
        );
        return (await repo.timesheets()).fileName;
      }

      expect(await name('attachment; filename=ts.csv'), 'ts.csv');
      expect(
        await name('attachment; filename="../../etc/ts 1.csv"'),
        'ts 1.csv',
      );
      expect(await name(r'attachment; filename="C:\x\ts.csv"'), 'ts.csv');
      expect(await name('attachment'), 'timesheets.csv');
      expect(await name(null), 'timesheets.csv');
      expect(await name('attachment; filename=""'), 'timesheets.csv');
    });

    test('download failures become typed errors, never a file', () async {
      http.failWith(DioExceptionType.connectionError);
      await expectLater(
        repo.projects(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'k',
            ApiFailureKind.network,
          ),
        ),
      );
      http.failWith(DioExceptionType.receiveTimeout);
      await expectLater(
        repo.projects(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'k',
            ApiFailureKind.timeout,
          ),
        ),
      );
      http.reply(500, failure('Server Error'));
      await expectLater(
        repo.projects(),
        throwsA(
          isA<ApiException>().having((e) => e.kind, 'k', ApiFailureKind.server),
        ),
      );
      // A non-JSON error body (an HTML 502 page) is still an error.
      http.reply(
        502,
        Uint8List.fromList(utf8.encode('<html>Bad gateway</html>')),
        headers: {'content-type': 'text/html'},
      );
      await expectLater(repo.projects(), throwsA(isA<ApiException>()));
    });
  });

  group('the save dialog (file_picker)', () {
    late Directory dir;
    late _Picker picker;
    late FilePickerPlatform original;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('wf_csv_');
      original = FilePickerPlatform.instance;
      picker = _Picker(dir);
      FilePickerPlatform.instance = picker;
    });
    tearDown(() {
      FilePickerPlatform.instance = original;
      dir.deleteSync(recursive: true);
    });

    test('save: the chosen file holds exactly the server bytes', () async {
      final text = serverCsv('timesheets', 5);
      final file = CsvFile(bytes: _file(text), fileName: 'ts-2026-11-19.csv');
      expect(await saveCsvWithPicker(file), isTrue);
      final call = picker.calls.single;
      expect(call.name, 'ts-2026-11-19.csv');
      expect(call.mime, 'text/csv');
      final saved = File('${dir.path}/ts-2026-11-19.csv').readAsBytesSync();
      expect(saved, _file(text));
      // Opens as UTF-8 with its BOM (what spreadsheet apps need for Arabic).
      final rows = parseCsv(utf8.decode(saved.sublist(3)));
      expect(rows, hasLength(6));
      expect(rows[5][1], 'مشروع البوابة 5');
    });

    test('cancel: nothing written, reported as not saved', () async {
      picker.cancel = true;
      final ok = await saveCsvWithPicker(
        CsvFile(bytes: _file('A\r\n'), fileName: 'a.csv'),
      );
      expect(ok, isFalse);
      expect(dir.listSync(), isEmpty);
    });
  });

  group('Export CSV chip', () {
    Future<void> pumpChip(
      WidgetTester tester,
      Future<CsvFile> Function() download, {
      CsvSaver? saver,
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (saver != null) csvSaverProvider.overrideWithValue(saver),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(child: ExportCsvChip(download: download)),
            ),
          ),
        ),
      );
    }

    final file = CsvFile(bytes: _file('A\r\n'), fileName: 'tasks-x.csv');

    testWidgets('saved: says where; the chip is ready again', (tester) async {
      final saved = <CsvFile>[];
      await pumpChip(
        tester,
        () async => file,
        saver: (f) async {
          saved.add(f);
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saved.single, same(file));
      expect(find.text('Saved tasks-x.csv.'), findsOneWidget);
      expect(find.byKey(const Key('export-csv-busy')), findsNothing);
    });

    testWidgets('cancelled save dialog: no message, no error', (tester) async {
      var saves = 0;
      await pumpChip(
        tester,
        () async => file,
        saver: (_) async {
          saves++;
          return false;
        },
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.byType(SnackBar), findsNothing);
      // And it can be tried again.
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saves, 2);
    });

    testWidgets('the save dialog failing is a friendly error', (tester) async {
      await pumpChip(
        tester,
        () async => file,
        saver: (_) async =>
            throw PlatformException(code: 'unknown', message: 'raw detail'),
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't export: Something went wrong. Please try again."),
        findsOneWidget,
      );
      expect(find.textContaining('raw detail'), findsNothing);
    });

    testWidgets('offline: says so, saves nothing', (tester) async {
      var saves = 0;
      await pumpChip(
        tester,
        () async => throw const ApiException(
          kind: ApiFailureKind.network,
          message: 'SocketException: failed host lookup',
        ),
        saver: (_) async {
          saves++;
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(
        find.text(
          "Couldn't export: You're offline. Check your connection and try "
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('too many rows (422): the server reason is shown', (
      tester,
    ) async {
      await pumpChip(
        tester,
        () async => throw const ApiException(
          kind: ApiFailureKind.validation,
          message: 'Too many rows to export.',
          statusCode: 422,
        ),
        saver: (_) async => true,
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't export:"), findsOneWidget);
    });

    testWidgets('a second tap while exporting sends nothing more', (
      tester,
    ) async {
      var downloads = 0;
      await pumpChip(tester, () async {
        downloads++;
        await Future<void>.delayed(const Duration(seconds: 1));
        return file;
      }, saver: (_) async => true);
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pump();
      expect(find.byKey(const Key('export-csv-busy')), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(downloads, 1);
    });

    testWidgets('Arabic: the chip and messages are translated', (tester) async {
      await pumpChip(
        tester,
        () async => file,
        saver: (_) async => true,
        locale: const Locale('ar'),
      );
      expect(find.text('Export CSV'), findsNothing);
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(find.textContaining('tasks-x.csv'), findsOneWidget);
      expect(find.textContaining('Saved'), findsNothing);
    });
  });
}
