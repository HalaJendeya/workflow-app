import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/application/session_scope.dart';
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

/// Read-state filter of the Home Notifications card (set from the Home
/// search field's options sheet). The bell panel keeps its own filter in
/// its widget state, so choosing "Unread" in one never changes the other
/// (F8). Starts at "All" again for another account, company or portal.
final homeNotificationFilterProvider =
    NotifierProvider<NotificationFilterController, NotificationFilter>(
      NotificationFilterController.new,
    );

class NotificationFilterController extends Notifier<NotificationFilter> {
  @override
  NotificationFilter build() {
    ref.watch(
      sessionControllerProvider.select(
        (s) => (s.value?.userId, s.value?.companyId, s.value?.portal),
      ),
    );
    return NotificationFilter.all;
  }

  // A named method reads better than a setter at call sites.
  // ignore: use_setters_to_change_properties
  void select(NotificationFilter filter) => state = filter;
}

/// Inbox for one read-state filter with optimistic-free read updates: local
/// state changes only after the server confirms. Each filter is its own
/// instance, so the bell panel and the Home card can show different filters
/// at once; a mark in one reloads the others from the server.
class NotificationsController extends AsyncNotifier<NotificationInbox> {
  new(this.filter);

  final NotificationFilter filter;

  /// A badge older than this is reloaded when the app comes back.
  static const staleAfter = Duration(seconds: 60);

  DateTime? _loadedAt;

  @override
  Future<NotificationInbox> build() {
    _marking.clear();
    _loadingMore = null;
    _markingAll = null;
    _loadedAt = DateTime.now();
    return ref.watch(notificationsRepositoryProvider).list(filter: filter);
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
    Future<void>? mine;
    return _loadingMore ??= mine = _loadMore(current).whenComplete(() {
      // A newer account or company may already have its own request.
      if (identical(_loadingMore, mine)) _loadingMore = null;
    });
  }

  /// Answers obtained after a sign-out or company switch are dropped: the
  /// inbox belongs to the account and company it was asked for.
  Future<void> _loadMore(NotificationInbox current) async {
    final scope = ref.captureScope();
    final next = await ref
        .read(notificationsRepositoryProvider)
        .list(page: current.currentPage + 1, filter: filter);
    if (!ref.inScope(scope)) return;
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

  Future<void> markRead(String id) {
    Future<void>? mine;
    return _marking[id] ??= mine = _markRead(id).whenComplete(() {
      // Only this request's own entry: a newer scope may hold another.
      // A block that discards the result: `remove` returns this very
      // future, which `whenComplete` would otherwise wait for — forever.
      if (identical(_marking[id], mine)) unawaited(_marking.remove(id));
    });
  }

  Future<void> _markRead(String id) async {
    final scope = ref.captureScope();
    final updated = await ref
        .read(notificationsRepositoryProvider)
        .markRead(id);
    // Marked on the server for the account it was sent for; another
    // account's or company's inbox is not touched or reloaded.
    if (!ref.inScope(scope)) return;
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
    _reloadOthers();
    switch (filter) {
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

  /// The other filters' lists and counts are stale after a mark: they load
  /// again from the server (at once if shown, else when next shown).
  void _reloadOthers() {
    for (final f in NotificationFilter.values) {
      if (f != filter) ref.invalidate(notificationsControllerProvider(f));
    }
  }

  Future<void> markAllRead() {
    Future<void>? mine;
    return _markingAll ??= mine = _markAllRead().whenComplete(() {
      if (identical(_markingAll, mine)) _markingAll = null;
    });
  }

  Future<void> _markAllRead() async {
    final scope = ref.captureScope();
    final unread = await ref
        .read(notificationsRepositoryProvider)
        .markAllRead();
    if (!ref.inScope(scope)) return;
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

final AsyncNotifierProviderFamily<
  NotificationsController,
  NotificationInbox,
  NotificationFilter
>
notificationsControllerProvider =
    AsyncNotifierProvider.family<
      NotificationsController,
      NotificationInbox,
      NotificationFilter
    >(NotificationsController.new);

/// The unfiltered inbox; the bell badge takes its unread count from here.
final AsyncNotifierProvider<NotificationsController, NotificationInbox>
allNotificationsProvider = notificationsControllerProvider(
  NotificationFilter.all,
);
