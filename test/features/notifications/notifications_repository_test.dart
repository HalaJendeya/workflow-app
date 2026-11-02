import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';

import '../../helpers/fake_http_adapter.dart';

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 25;
  @override
  void onUnauthorized() {}
}

/// Item shaped exactly by the collection's asserted contract.
Map<String, dynamic> _item(String id, {bool read = false}) => {
  'id': id,
  'type': 'task.assigned',
  'category': 'tasks',
  'title': 'Task assigned',
  'message': 'You were assigned a task',
  'data': <String, dynamic>{},
  'subject': null,
  'actor': null,
  'company_id': 25,
  'is_read': read,
  'read_at': read ? '2026-10-01T10:00:00Z' : null,
  'created_at': '2026-10-01T09:00:00Z',
};

void main() {
  late FakeHttpAdapter http;
  ApiNotificationsRepository repoFor(Portal p) => ApiNotificationsRepository(
    ApiClient(
      baseUrl: 'https://api.test',
      credentials: _Creds(),
      adapter: http,
    ),
    p,
  );

  setUp(() => http = FakeHttpAdapter());

  test('list parses items and meta for the client prefix', () async {
    http.reply(
      200,
      ok({
        'notifications': [_item('a'), _item('b', read: true)],
        'meta': {
          'current_page': 1,
          'last_page': 3,
          'per_page': 20,
          'total': 41,
          'unread_count': 5,
        },
      }),
    );
    final inbox = await repoFor(Portal.client)
        .list(filter: NotificationFilter.unread);

    expect(http.last.path, '/api/v1/client/notifications');
    expect(http.last.queryParameters, {
      'page': 1,
      'per_page': 20,
      'status': 'unread',
    });
    expect(inbox.items, hasLength(2));
    expect(inbox.items.first.title, 'Task assigned');
    expect(inbox.items.last.isRead, isTrue);
    expect(inbox.items.last.readAt, DateTime.utc(2026, 10, 1, 10));
    expect(inbox.unreadCount, 5);
    expect(inbox.hasMore, isTrue);
  });

  test('employee prefix and mark-as-read', () async {
    http.reply(200, ok(_item('n-1', read: true)));
    final n = await repoFor(Portal.employee).markRead('n-1');
    expect(http.last.method, 'POST');
    expect(http.last.path, '/api/v1/employee/notifications/n-1/read');
    expect(n.isRead, isTrue);
  });

  test('mark all read returns the new unread count', () async {
    http.reply(200, ok({'updated': 4, 'unread_count': 0}));
    expect(await repoFor(Portal.client).markAllRead(), 0);
    expect(http.last.path, '/api/v1/client/notifications/read-all');
  });

  test('unread count', () async {
    http.reply(200, ok({'unread_count': 3}));
    expect(await repoFor(Portal.client).unreadCount(), 3);
    expect(http.last.path, '/api/v1/client/notifications/unread-count');
  });

  test('foreign id answers 404 as notFound', () async {
    http.reply(404, failure('Not found'));
    await expectLater(
      repoFor(Portal.client).markRead('x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.notFound,
        ),
      ),
    );
  });

  test('missing meta is rejected as invalid response', () async {
    http.reply(200, ok({'notifications': <Object>[]}));
    await expectLater(
      repoFor(Portal.client).list(),
      throwsA(isA<ApiException>()),
    );
  });
}
