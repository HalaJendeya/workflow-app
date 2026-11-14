import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';

import '../helpers/fake_http_adapter.dart';

/// Conversation attachments: the documented limits of
/// `POST …/conversations/{id}/messages` (`files[]`, ≤ 5, ≤ 10 240 KB,
/// JPEG/PNG/GIF/WebP/PDF/text) and the download route
/// `GET /api/v1/conversations/{c}/attachments/{a}`. Mocked HTTP only; no
/// file was uploaded or downloaded live.

class _Creds implements ApiCredentials {
  @override
  String? token = 'tkn';
  @override
  int? companyId = 3;
  int unauthorized = 0;
  @override
  void onUnauthorized() => unauthorized++;
}

final png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, //
]);
final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
final gif = Uint8List.fromList(ascii.encode('GIF89a......'));
final webp = Uint8List.fromList([
  ...ascii.encode('RIFF'),
  0,
  0,
  0,
  0,
  ...ascii.encode('WEBPVP8 '),
]);
final pdf = Uint8List.fromList(ascii.encode('%PDF-1.7\n...'));
final text = Uint8List.fromList(utf8.encode('Meeting notes\nمرحبا\n'));
final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0x01, 0x02]);

OutgoingFile file(String name, Uint8List bytes) =>
    OutgoingFile(name: name, bytes: bytes);

void main() {
  group('content checks', () {
    test('types come from the content, not the name', () {
      expect(sniffMime(png), 'image/png');
      expect(sniffMime(jpeg), 'image/jpeg');
      expect(sniffMime(gif), 'image/gif');
      expect(sniffMime(webp), 'image/webp');
      expect(sniffMime(pdf), 'application/pdf');
      expect(sniffMime(text), 'text/plain');
      expect(sniffMime(zip), isNull, reason: 'binary, not allowed');
      // A ZIP renamed to .png is still refused.
      expect(file('photo.png', zip).mime, isNull);
    });

    test('the route limits are checked before any upload', () {
      expect(checkAttachments([file('a.png', png)]), isNull);
      expect(
        checkAttachments([for (var i = 0; i < 6; i++) file('$i.png', png)]),
        AttachmentProblem.tooMany,
      );
      expect(
        checkAttachments([for (var i = 0; i < 5; i++) file('$i.png', png)]),
        isNull,
      );
      expect(
        checkAttachments([file('e.txt', Uint8List(0))]),
        AttachmentProblem.empty,
      );
      final big = Uint8List(AttachmentRules.maxBytes + 1)..setAll(0, pdf);
      expect(
        checkAttachments([file('big.pdf', big)]),
        AttachmentProblem.tooLarge,
      );
      final limit = Uint8List(AttachmentRules.maxBytes)..setAll(0, pdf);
      expect(checkAttachments([file('limit.pdf', limit)]), isNull);
      expect(
        checkAttachments([file('a.zip', zip)]),
        AttachmentProblem.typeNotAllowed,
      );
    });

    test('message type follows the files', () {
      expect(messageTypeFor(const []), 'text');
      expect(messageTypeFor([file('a.png', png), file('b.gif', gif)]), 'image');
      expect(messageTypeFor([file('a.png', png), file('b.pdf', pdf)]), 'file');
    });

    test('file names from Content-Disposition, without paths', () {
      expect(
        fileNameFromDisposition('attachment; filename="report.pdf"'),
        'report.pdf',
      );
      expect(fileNameFromDisposition('attachment; filename=a.txt'), 'a.txt');
      expect(
        fileNameFromDisposition(
          'attachment; filename="x.pdf"; '
          "filename*=UTF-8''%D8%AA%D9%82%D8%B1%D9%8A%D8%B1.pdf",
        ),
        'تقرير.pdf',
      );
      expect(
        fileNameFromDisposition('attachment; filename="../../etc/passwd"'),
        'passwd',
      );
      expect(
        fileNameFromDisposition("attachment; filename*=UTF-8''%ZZ"),
        isNull,
      );
      expect(fileNameFromDisposition(null), isNull);
    });

    test('a preview trusts the header only when the content agrees', () {
      expect(
        DownloadedFile(bytes: png, contentType: 'image/png').mime,
        'image/png',
      );
      // An HTML page served as an image is not shown as one.
      expect(
        DownloadedFile(
          bytes: Uint8List.fromList(utf8.encode('<html>')),
          contentType: 'image/png',
        ).mime,
        'text/plain',
      );
      expect(DownloadedFile(bytes: zip, contentType: 'image/png').mime, isNull);
    });
  });

  group('repository (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late _Creds creds;
    late ConversationsRepository repo;

    setUp(() {
      http = FakeHttpAdapter();
      creds = _Creds();
      repo = ConversationsRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: creds,
          adapter: http,
        ),
        Portal.client,
      );
    });

    test('message rows carry their attachment ids', () {
      final m = ApiMessage.fromJson({
        'id': 5,
        'sender_id': 9,
        'message': '',
        'created_at': '2026-11-05T10:00:00Z',
        'attachments': [
          {'id': 77},
          {'name': 'no id'},
        ],
      });
      expect(m.attachments.map((a) => a.id), [77, null]);
    });

    test('files go under files[] with the content type and progress', () async {
      http.reply(
        200,
        ok({
          'message': {'id': 13, 'conversation_id': 1},
        }),
      );
      final progress = <double>[];
      final sent = await repo.send(
        1,
        '',
        files: [file('photo.png', png), file('notes.txt', text)],
        onProgress: progress.add,
      );
      expect(sent, isNull, reason: 'only the documented ids came back');
      final req = http.last;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/client/conversations/1/messages');
      expect(req.headers['X-Company'], '3');
      final form = req.data as FormData;
      expect(form.files.map((f) => f.key), ['files[]', 'files[]']);
      expect(form.files.map((f) => f.value.filename), [
        'photo.png',
        'notes.txt',
      ]);
      expect(form.files.first.value.contentType.toString(), 'image/png');
      expect(Map.fromEntries(form.fields), {'type': 'file'});
      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
    });

    test('a refused upload is a typed failure, not a sent message', () async {
      http.reply(
        422,
        failure(
          'Validation Error',
          errors: {
            'files.0': ['The files.0 field must not be greater than 10240.'],
          },
        ),
      );
      await expectLater(
        repo.send(1, 'x', files: [file('a.png', png)]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.validation,
          ),
        ),
      );
    });

    test('download: unprefixed route, X-Company, bytes and name', () async {
      http.reply(
        200,
        png,
        headers: {
          'content-type': 'image/png',
          'content-disposition': 'attachment; filename="photo.png"',
        },
      );
      final got = await repo.downloadAttachment(1, 77, companyId: 3);
      final req = http.last;
      expect(req.path, '/api/v1/conversations/1/attachments/77');
      expect(req.headers['Authorization'], 'Bearer tkn');
      expect(req.headers['X-Company'], '3');
      expect(got.bytes, png);
      expect(got.fileName, 'photo.png');
      expect(got.mime, 'image/png');
    });

    test('download refusals keep their meaning', () async {
      http.reply(403, failure('You are not a member of this conversation.'));
      await expectLater(
        repo.downloadAttachment(1, 77),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiFailureKind.forbidden)
              .having((e) => e.message, 'message', contains('not a member')),
        ),
      );
      // An expired session ends it, as on every other route.
      http.reply(401, failure('Unauthenticated.'));
      await expectLater(
        repo.downloadAttachment(1, 77),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.unauthorized,
          ),
        ),
      );
      expect(creds.unauthorized, 1);
      http.failWith(DioExceptionType.connectionError);
      await expectLater(
        repo.downloadAttachment(1, 77),
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
}
