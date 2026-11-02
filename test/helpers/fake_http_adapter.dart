import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Records outgoing requests and replies with queued canned responses.
/// Fixtures are shaped from the WorkFlow Postman collection contracts; they
/// are test doubles, not captured live traffic.
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<Object> _queue = [];

  void reply(int status, Object? body, {Map<String, String>? headers}) =>
      _queue.add(_Reply(status, body, headers ?? const {}));

  void failWith(DioExceptionType type) => _queue.add(type);

  RequestOptions get last => requests.last;

  Map<String, dynamic> get lastJsonBody =>
      requests.last.data as Map<String, dynamic>;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('No reply queued for ${options.method} ${options.uri}');
    }
    final next = _queue.removeAt(0);
    if (next is DioExceptionType) {
      throw DioException(requestOptions: options, type: next);
    }
    final reply = next as _Reply;
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final e in reply.headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Reply {
  const new(this.status, this.body, this.headers);
  final int status;
  final Object? body;
  final Map<String, String> headers;
}

Map<String, dynamic> ok(Object? data, {String message = 'OK'}) => {
  'success': true,
  'message': message,
  'data': data,
};

Map<String, dynamic> failure(String message, {Object? errors}) => {
  'success': false,
  'message': message,
  'errors': errors,
};
