import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers by request path, so widget tests can run the whole app in API
/// mode without depending on request order. Unknown paths answer 404 in the
/// documented error envelope. Fixtures follow the WorkFlow Postman
/// collection and shapes seen on the live server; they are test doubles.
class RouteHttpAdapter implements HttpClientAdapter {
  new(this.routes);

  /// `METHOD /path` → (status, body).
  final Map<String, (int, Object?)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) =
        routes['${options.method} ${options.uri.path}'] ??
        (404, {'success': false, 'message': 'Not found', 'errors': <Object>[]});
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
