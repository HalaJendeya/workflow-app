import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';

enum NotificationFilter { all, unread, read }

/// `05 Client / 09 Notifications` and `04 Employee / 10 Notifications`.
/// Both roles share one contract under their own route prefix.
abstract interface class NotificationsRepository {
  Future<NotificationInbox> list({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  });
  Future<int> unreadCount();
  Future<AppNotification> markRead(String id);

  /// Returns the new unread count (`data.unread_count`).
  Future<int> markAllRead();
}

class ApiNotificationsRepository implements NotificationsRepository {
  new(this._client, Portal portal)
    : _base = '/api/v1/${portal.name}/notifications';

  final ApiClient _client;
  final String _base;

  @override
  Future<NotificationInbox> list({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.get(
        _base,
        query: {'page': page, 'per_page': perPage, 'status': filter.name},
      ),
    );
    final items = data['notifications'];
    final meta = data['meta'];
    if (items is! List || meta is! Map<String, dynamic>) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Expected data.notifications and data.meta.',
      );
    }
    return NotificationInbox(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
      // Every `meta` count is asserted by the collection's test; a missing
      // one is an invalid response, never a guessed page or 0.
      currentPage:
          _int(meta['current_page']) ?? missingField('meta.current_page'),
      lastPage: _int(meta['last_page']) ?? missingField('meta.last_page'),
      total: _int(meta['total']) ?? missingField('meta.total'),
      unreadCount:
          _int(meta['unread_count']) ?? missingField('meta.unread_count'),
    );
  }

  @override
  Future<int> unreadCount() async {
    final data = ApiEnvelope.unwrapObject(
      await _client.get('$_base/unread-count'),
    );
    return _int(data['unread_count']) ?? missingField('unread_count');
  }

  @override
  Future<AppNotification> markRead(String id) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post('$_base/${Uri.encodeComponent(id)}/read'),
    );
    return AppNotification.fromJson(data);
  }

  @override
  Future<int> markAllRead() async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post('$_base/read-all'),
    );
    return _int(data['unread_count']) ?? missingField('unread_count');
  }
}

int? _int(Object? v) => v is int ? v : (v is String ? int.tryParse(v) : null);
