import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';

/// Demo-mode fixtures (APP_MODE=mock only). State lives in memory and is
/// never presented as saved on the server.
class MockNotificationsRepository implements NotificationsRepository {
  new() {
    final now = DateTime.now();
    _items = List.generate(
      6,
      (i) => AppNotification(
        id: 'demo-$i',
        isRead: i > 2,
        type: 'demo',
        category: i.isEven ? 'tasks' : 'meetings',
        title: 'Demo notification ${i + 1}',
        message: 'Sample content shown in demo mode.',
        createdAt: now.subtract(Duration(hours: i * 5)),
      ),
    );
  }

  late List<AppNotification> _items;

  int get _unread => _items.where((n) => !n.isRead).length;

  @override
  Future<NotificationInbox> list({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    final filtered = switch (filter) {
      NotificationFilter.all => _items,
      NotificationFilter.unread => _items.where((n) => !n.isRead).toList(),
      NotificationFilter.read => _items.where((n) => n.isRead).toList(),
    };
    return NotificationInbox(
      items: filtered,
      currentPage: 1,
      lastPage: 1,
      total: filtered.length,
      unreadCount: _unread,
    );
  }

  @override
  Future<int> unreadCount() async => _unread;

  @override
  Future<AppNotification> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    _items[i] = _items[i].markedRead(DateTime.now());
    return _items[i];
  }

  @override
  Future<int> markAllRead() async {
    _items = [for (final n in _items) n.markedRead(DateTime.now())];
    return 0;
  }
}
