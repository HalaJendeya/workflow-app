import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers by request path, so widget tests can run the whole app in API
/// mode without depending on request order. Unknown paths answer 404 in the
/// documented error envelope. Fixtures follow the WorkFlow Postman
/// collection and shapes seen on the live server; they are test doubles.
class RouteHttpAdapter implements HttpClientAdapter {
  new(this.routes, {this.handlers = const {}});

  /// `METHOD /path` → (status, body).
  final Map<String, (int, Object?)> routes;

  /// `METHOD /path` → reply computed from the request (query, body), for
  /// routes whose answer depends on more than the path. Checked first.
  final Map<String, (int, Object?) Function(RequestOptions)> handlers;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final key = '${options.method} ${options.uri.path}';
    final (status, body) =
        handlers[key]?.call(options) ??
        routes[key] ??
        (404, {'success': false, 'message': 'Not found', 'errors': <Object>[]});
    if (body case RawReply(:final bytes, :final headers)) {
      return ResponseBody.fromBytes(
        bytes,
        status,
        headers: {
          for (final e in headers.entries) e.key: [e.value],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A file reply: the bytes as they are, with these headers.
class RawReply {
  const new(this.bytes, [this.headers = const {}]);

  final Uint8List bytes;
  final Map<String, String> headers;
}
