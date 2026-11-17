import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/notifications/data/mock_notifications_repository.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';

/// Found on the emulator: with the "Unread" filter on, "Mark all as read"
/// (or reading one) left the read items listed under Unread with the old
/// count until the inbox was reloaded.
void main() {
  late ProviderContainer container;
  var current = NotificationFilter.all;

  setUp(() {
    final repo = MockNotificationsRepository(); // demo-0..2 unread
    container = ProviderContainer(
      overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  AsyncNotifierProvider<NotificationsController, NotificationInbox> p() =>
      notificationsControllerProvider(current);

  Future<void> filter(NotificationFilter f) async {
    current = f;
    container.listen(p(), (_, _) {});
    await container.read(p().future);
  }

  NotificationsController ctl() => container.read(p().notifier);

  test('unread filter drops an item once it is read', () async {
    await filter(NotificationFilter.unread);
    expect(container.read(p()).value!.total, 3);

    await ctl().markRead('demo-0');
    final inbox = container.read(p()).value!;
    expect(inbox.items.map((n) => n.id), ['demo-1', 'demo-2']);
    expect(inbox.total, 2);
    expect(inbox.unreadCount, 2);
  });

  test('unread filter is empty after mark all as read', () async {
    await filter(NotificationFilter.unread);
    await ctl().markAllRead();
    final inbox = container.read(p()).value!;
    expect(inbox.items, isEmpty);
    expect(inbox.total, 0);
    expect(inbox.unreadCount, 0);
  });

  test('read filter picks up items read after it loaded', () async {
    await filter(NotificationFilter.read);
    expect(container.read(p()).value!.total, 3);
    await ctl().markAllRead();
    final inbox = await container.read(p().future);
    expect(inbox.total, 6);
    expect(inbox.items.every((n) => n.isRead), isTrue);
  });

  test('all filter keeps read items in place', () async {
    await filter(NotificationFilter.all);
    await ctl().markRead('demo-1');
    final inbox = container.read(p()).value!;
    expect(inbox.items, hasLength(6));
    expect(inbox.items[1].isRead, isTrue);
    expect(inbox.unreadCount, 2);
  });
}
