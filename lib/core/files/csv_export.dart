import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// A CSV file the server produced: its bytes and the name its
/// `Content-Disposition` gives (`tasks-2026-11-18.csv`). Kept in memory
/// until the person saves it; the app keeps no copy.
class CsvFile {
  const new({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// `GET …/export` on a CSV route (collection, "Added 2026-10-27"): the
/// list's filters without paging, answered as `text/csv; charset=UTF-8`
/// with `Content-Disposition: attachment`. A refusal (403, or 422 over
/// 10 000 rows) is the JSON error envelope and becomes an [ApiException].
/// A 200 that is not CSV is an invalid response, never saved.
Future<CsvFile> downloadCsv(
  ApiClient client,
  String path, {
  required String fallbackName,
  Json? query,
}) async {
  final response = await client.download(
    path,
    query: query,
    headers: const {'Accept': 'text/csv'},
  );
  final type = response.headers.value(Headers.contentTypeHeader) ?? '';
  final bytes = response.data;
  if (!type.toLowerCase().contains('text/csv') || bytes == null) {
    throw ApiException(
      kind: ApiFailureKind.invalidResponse,
      message: 'Expected a CSV file.',
      statusCode: response.statusCode,
    );
  }
  return CsvFile(
    bytes: Uint8List.fromList(bytes),
    fileName:
        _fileName(response.headers.value('content-disposition')) ??
        fallbackName,
  );
}

/// `filename="…"` of a `Content-Disposition` header; path parts dropped.
String? _fileName(String? header) {
  if (header == null) return null;
  final m = RegExp(
    r'filename\s*=\s*("([^"]*)"|[^;]+)',
    caseSensitive: false,
  ).firstMatch(header);
  final name = (m?.group(2) ?? m?.group(1))?.trim();
  if (name == null || name.isEmpty) return null;
  final base = name.split(RegExp(r'[\\/]')).last.trim();
  return base.isEmpty ? null : base;
}

/// Saves [file] where the person chooses (the system "save as" dialog on
/// Android, a download on the web); `false` when they cancel. The same
/// approved `file_picker` path as chat attachments: no storage permission.
typedef CsvSaver = Future<bool> Function(CsvFile file);

Future<bool> saveCsvWithPicker(CsvFile file) async {
  final uri = await FilePicker.saveFile(
    fileName: file.fileName,
    bytes: file.bytes,
    mimeType: 'text/csv',
  );
  return uri != null;
}

/// Replaced in tests.
final csvSaverProvider = Provider<CsvSaver>((_) => saveCsvWithPicker);
