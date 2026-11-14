import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/notifications/data/mock_notifications_repository.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).isMock) return MockNotificationsRepository();
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) {
    throw StateError('Notifications require a signed-in session.');
  }
  return ApiNotificationsRepository(
    ref.watch(apiClientProvider),
    session.portal,
  );
});

final notificationFilterProvider =
    NotifierProvider<NotificationFilterController, NotificationFilter>(
      NotificationFilterController.new,
    );

class NotificationFilterController extends Notifier<NotificationFilter> {
  @override
  NotificationFilter build() => NotificationFilter.all;

  // A setter would hide the intent at call sites.
  // A named method reads better than a setter at call sites.
  // ignore: use_setters_to_change_properties
  void select(NotificationFilter filter) => state = filter;
}

/// Inbox for the current filter with optimistic-free read updates: local
/// state changes only after the server confirms.
class NotificationsController extends AsyncNotifier<NotificationInbox> {
  /// A badge older than this is reloaded when the app comes back.
  static const staleAfter = Duration(seconds: 60);

  DateTime? _loadedAt;

  @override
  Future<NotificationInbox> build() {
    _marking.clear();
    _loadingMore = null;
    _markingAll = null;
    _loadedAt = DateTime.now();
    return ref
        .watch(notificationsRepositoryProvider)
        .list(filter: ref.watch(notificationFilterProvider));
  }

  /// In-flight requests: a repeated tap joins the one already sent instead
  /// of sending another.
  final _marking = <String, Future<void>>{};
  Future<void>? _loadingMore;
  Future<void>? _markingAll;

  /// Back in the foreground: reload the inbox (and so the badge) unless it
  /// was read within [staleAfter] or a load is already running. Every bell
  /// on screen may ask; only the first stale request reloads.
  void refreshIfStale([DateTime? now]) {
    final at = _loadedAt;
    final t = now ?? DateTime.now();
    if (state.isLoading || (at != null && t.difference(at) < staleAfter)) {
      return;
    }
    _loadedAt = t;
    ref.invalidateSelf();
  }

  Future<void> loadMore() {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) {
      return Future.value();
    }
    return _loadingMore ??= _loadMore(current)
        .whenComplete(() => _loadingMore = null);
  }

  Future<void> _loadMore(NotificationInbox current) async {
    final next = await ref
        .read(notificationsRepositoryProvider)
        .list(
          page: current.currentPage + 1,
          filter: ref.read(notificationFilterProvider),
        );
    if (!ref.mounted) return;
    // A notification that arrived meanwhile shifts the pages: an item can
    // come back on the next page. Keep one copy.
    final seen = {for (final n in current.items) n.id};
    state = AsyncData(
      NotificationInbox(
        items: [...current.items, ...next.items.where((n) => seen.add(n.id))],
        currentPage: next.currentPage,
        lastPage: next.lastPage,
        total: next.total,
        unreadCount: next.unreadCount,
      ),
    );
  }

  Future<void> markRead(String id) =>
      _marking[id] ??= _markRead(id).whenComplete(() {
        // A block that discards the result: `remove` returns this very
        // future, which `whenComplete` would otherwise wait for — forever.
        unawaited(_marking.remove(id));
      });

  Future<void> _markRead(String id) async {
    final updated = await ref
        .read(notificationsRepositoryProvider)
        .markRead(id);
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final wasUnread = current.items.any((n) => n.id == id && !n.isRead);
    _settle(
      NotificationInbox(
        items: current.items.map((n) => n.id == id ? updated : n).toList(),
        currentPage: current.currentPage,
        lastPage: current.lastPage,
        total: current.total,
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, current.total)
            : current.unreadCount,
      ),
    );
  }

  /// Keeps the list true to the server-side read filter after a mark: read
  /// items stayed listed under "Unread" (with its count) until a reload.
  void _settle(NotificationInbox next) {
    switch (ref.read(notificationFilterProvider)) {
      case NotificationFilter.all:
        state = AsyncData(next);
      case NotificationFilter.unread:
        final kept = next.items.where((n) => !n.isRead).toList();
        state = AsyncData(
          NotificationInbox(
            items: kept,
            currentPage: next.currentPage,
            lastPage: next.lastPage,
            total: (next.total - (next.items.length - kept.length)).clamp(
              0,
              next.total,
            ),
            unreadCount: next.unreadCount,
          ),
        );
      case NotificationFilter.read:
        // Newly read items belong here but are not loaded: ask again.
        state = AsyncData(next);
        ref.invalidateSelf();
    }
  }

  Future<void> markAllRead() =>
      _markingAll ??= _markAllRead().whenComplete(() => _markingAll = null);

  Future<void> _markAllRead() async {
    final unread = await ref
        .read(notificationsRepositoryProvider)
        .markAllRead();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    _settle(
      NotificationInbox(
        items: [for (final n in current.items) n.markedRead(null)],
        currentPage: current.currentPage,
        lastPage: current.lastPage,
        total: current.total,
        unreadCount: unread,
      ),
    );
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationInbox>(
      NotificationsController.new,
    );
