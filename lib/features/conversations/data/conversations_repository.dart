import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// One chat message (`last_message` / `messages[]` rows).
class ApiMessage {
  const new({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    required this.attachments,
  });

  factory fromJson(Json j) {
    final sender = j['sender'];
    final attachments = j['attachments'];
    return ApiMessage(
      id: asInt(j['id']) ?? missingField('message.id'),
      senderId: asInt(j['sender_id']) ?? missingField('message.sender_id'),
      senderName: sender is Json ? (sender['name'] as String?) ?? '' : '',
      text: (j['message'] as String?) ?? '',
      createdAt:
          asDate(j['created_at'])?.toLocal() ??
          missingField('message.created_at'),
      attachments: attachments is List ? attachments.length : 0,
    );
  }

  final int id;
  final int senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final int attachments;
}

/// A conversation as listed by `GET /{portal}/conversations` or opened by
/// `GET /{portal}/conversations/{id}` (`data.conversation`). Field names are
/// the ones the live server returns (re-checked on api.workflownets.com,
/// employee account, 2026-11-14);
/// the collection documents the routes but not these response fields.
class ApiConversation {
  const new({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.unread,
    required this.members,
    required this.messages,
  });

  factory fromJson(Json j) {
    final users = j['users'];
    final messages = j['messages'];
    final last = j['last_message'];
    final rows = <ApiMessage>[
      if (messages is List)
        ...messages.whereType<Json>().map(ApiMessage.fromJson)
      else if (last is Json)
        ApiMessage.fromJson(last),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ApiConversation(
      id: asInt(j['id']) ?? missingField('conversation.id'),
      name:
          (j['display_name'] as String?) ??
          (j['title'] as String?) ??
          missingField('conversation.display_name'),
      isGroup: j['is_group'] == true,
      unread: asInt(j['unread_count']) ?? 0,
      members: [
        if (users is List)
          for (final u in users.whereType<Json>())
            if (u['name'] is String) u['name'] as String,
      ],
      messages: rows,
    );
  }

  final int id;
  final String name;
  final bool isGroup;
  final int unread;
  final List<String> members;

  /// Oldest first. The list response carries the latest message only; the
  /// detail response carries the most recent page (50 seen live).
  final List<ApiMessage> messages;

  ApiConversation withMessages(List<ApiMessage> messages) => ApiConversation(
    id: id,
    name: name,
    isGroup: isGroup,
    unread: unread,
    members: members,
    messages: messages,
  );
}

/// `05 Client / 06 Conversations` and `04 Employee / 07 Conversations`: one
/// controller (`Conversations\ConversationController`) behind both prefixes.
class ConversationsRepository {
  new(this._client, Portal portal)
    : _base = '/api/v1/${portal.name}/conversations';

  final ApiClient _client;
  final String _base;

  Future<List<ApiConversation>> list() async {
    final data = ApiEnvelope.unwrapData(await _client.get(_base));
    if (data is! List) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Expected a conversation array in data.',
      );
    }
    return data.whereType<Json>().map(ApiConversation.fromJson).toList();
  }

  Future<ApiConversation> open(int id) async {
    final data = ApiEnvelope.unwrapObject(await _client.get('$_base/$id'));
    final c = data['conversation'];
    if (c is! Json) missingField('conversation');
    return ApiConversation.fromJson(c);
  }

  /// `POST …/{id}/messages`, multipart: `message` (≤ 5000 chars), `type`.
  /// Files would go under `files[]` (BE-28); the app sends text only.
  Future<void> send(int id, String text) async {
    ApiEnvelope.unwrapData(
      await _client.post(
        '$_base/$id/messages',
        body: FormData.fromMap({'message': text, 'type': 'text'}),
      ),
    );
  }

  /// `POST …/{id}/read` (no body).
  Future<void> markRead(int id) async {
    ApiEnvelope.unwrapData(await _client.post('$_base/$id/read'));
  }

  /// `GET …/{id}/messages`: cursor-paged history, `{data[], meta {has_more,
  /// oldest_id, newest_id}}`, ordered by id ascending. [beforeId] pages back,
  /// [afterId] polls for newer messages. Side-effect free (does not mark
  /// read). Rows are the message objects of the conversation detail.
  Future<MessagePage> messages(
    int id, {
    int? beforeId,
    int? afterId,
    int limit = messagePageSize,
  }) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '$_base/$id/messages',
        query: {'limit': limit, 'before_id': ?beforeId, 'after_id': ?afterId},
      ),
    );
    final data = body['data'];
    if (data is! List) missingField('data');
    final meta = body['meta'];
    if (meta is! Json) missingField('meta');
    final hasMore = meta['has_more'];
    if (hasMore is! bool) missingField('meta.has_more');
    return MessagePage(
      messages: [for (final m in data.whereType<Json>()) ApiMessage.fromJson(m)]
        ..sort((a, b) => a.id.compareTo(b.id)),
      hasMore: hasMore,
    );
  }

  /// `GET …/available-users`: who the caller may start a chat with and how.
  /// The collection documents no response fields; the shape read here is
  /// the live one (client QA account, 2026-11-14): `data {role,
  /// default_type, can_create_group, users[{id, name, image}]}`.
  Future<ConversationOptions> availableUsers() async {
    final data = ApiEnvelope.unwrapObject(
      await _client.get('$_base/available-users'),
    );
    final type = data['default_type'];
    if (type is! String || type.isEmpty) missingField('default_type');
    final group = data['can_create_group'];
    if (group is! bool) missingField('can_create_group');
    final users = data['users'];
    if (users is! List) missingField('users');
    return ConversationOptions(
      defaultType: type,
      canCreateGroup: group,
      users: [
        for (final u in users.whereType<Json>())
          (
            id: asInt(u['id']) ?? missingField('users[].id'),
            name: u['name'] is String
                ? u['name'] as String
                : missingField('users[].name'),
          ),
      ],
    );
  }

  /// `POST …` — body `{users[], type, title?}` (`type` ∈ team_chat,
  /// client_chat, manager_chat). 201 with `data.id`; returns that id.
  Future<int> create({
    required List<int> users,
    required String type,
    String? title,
  }) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post(
        _base,
        body: {
          'users': users,
          'type': type,
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        },
      ),
    );
    return asInt(data['id']) ?? missingField('id');
  }
}

const messagePageSize = 30;

/// A page of `GET …/messages`, oldest first.
class MessagePage {
  const new({required this.messages, required this.hasMore});

  final List<ApiMessage> messages;
  final bool hasMore;
}

/// What `available-users` allows: the conversation type to create, whether
/// groups are allowed, and the people to choose from.
class ConversationOptions {
  const new({
    required this.defaultType,
    required this.canCreateGroup,
    required this.users,
  });

  final String defaultType;
  final bool canCreateGroup;
  final List<({int id, String name})> users;
}

/// The messages of one open conversation: the latest page first, older
/// pages on demand ([ConversationThread.loadEarlier]) and newer messages by
/// polling ([ConversationThread.poll]). Merged by id, so a poll that
/// overlaps a send never duplicates a message.
class MessageThread {
  const new({required this.messages, required this.hasEarlier});

  final List<ApiMessage> messages;
  final bool hasEarlier;

  int? get oldestId => messages.isEmpty ? null : messages.first.id;
  int? get newestId => messages.isEmpty ? null : messages.last.id;

  MessageThread merge(Iterable<ApiMessage> more, {bool? hasEarlier}) {
    final byId = {for (final m in messages) m.id: m};
    for (final m in more) {
      byId[m.id] = m;
    }
    return MessageThread(
      messages: byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
      hasEarlier: hasEarlier ?? this.hasEarlier,
    );
  }
}

class ConversationThread extends AsyncNotifier<MessageThread> {
  new(this.conversationId);

  final int conversationId;

  ConversationsRepository get _repo =>
      ref.read(conversationsRepositoryProvider);

  @override
  Future<MessageThread> build() async {
    _scope(ref);
    ref.watch(conversationsRepositoryProvider);
    final page = await _repo.messages(conversationId);
    return MessageThread(messages: page.messages, hasEarlier: page.hasMore);
  }

  bool _busy = false;

  /// One older page (`before_id` = the oldest loaded id).
  Future<void> loadEarlier() async {
    final current = state.value;
    if (current == null || !current.hasEarlier || _busy) return;
    _busy = true;
    try {
      final page = await _repo.messages(
        conversationId,
        beforeId: current.oldestId,
      );
      state = AsyncData(
        state.value!.merge(page.messages, hasEarlier: page.hasMore),
      );
    } finally {
      _busy = false;
    }
  }

  /// Newer messages (`after_id` = the newest loaded id). Returns how many
  /// arrived. A failed poll leaves the thread as it was.
  Future<int> poll() async {
    final current = state.value;
    if (current == null) return 0;
    final page = await _repo.messages(
      conversationId,
      afterId: current.newestId,
    );
    if (page.messages.isEmpty) return 0;
    state = AsyncData(state.value!.merge(page.messages));
    return page.messages.length;
  }
}

final conversationsRepositoryProvider = Provider<ConversationsRepository>((
  ref,
) {
  final portal =
      ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
  return ConversationsRepository(ref.watch(apiClientProvider), portal);
});

/// Conversations belong to one account in one company.
void _scope(Ref ref) => ref.watch(
  sessionControllerProvider.select(
    (s) => (s.value?.userId, s.value?.companyId),
  ),
);

final FutureProvider<List<ApiConversation>> apiConversationsProvider =
    FutureProvider.autoDispose((ref) {
      _scope(ref);
      return ref.watch(conversationsRepositoryProvider).list();
    });

final FutureProviderFamily<ApiConversation, int> apiConversationProvider =
    FutureProvider.autoDispose.family((ref, id) {
      _scope(ref);
      return ref.watch(conversationsRepositoryProvider).open(id);
    });

final AsyncNotifierProviderFamily<ConversationThread, MessageThread, int>
conversationThreadProvider = AsyncNotifierProvider.autoDispose
    .family<ConversationThread, MessageThread, int>(ConversationThread.new);

final FutureProvider<ConversationOptions> conversationOptionsProvider =
    FutureProvider.autoDispose((ref) {
      _scope(ref);
      return ref.watch(conversationsRepositoryProvider).availableUsers();
    });
