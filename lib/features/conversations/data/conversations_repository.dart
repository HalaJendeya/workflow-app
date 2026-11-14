import 'dart:typed_data';

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
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';

export 'package:workflow_app/features/conversations/data/chat_attachments.dart';

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
      attachments: [
        if (attachments is List)
          for (final a in attachments)
            ApiAttachment(id: a is Json ? asInt(a['id']) : null),
      ],
    );
  }

  final int id;
  final int senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final List<ApiAttachment> attachments;
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

  /// `POST …/{id}/messages`, multipart: `message` (≤ 5000 chars), `type`
  /// (`text`/`image`/`file`) and up to 5 `files[]` (BE-28: no other key).
  /// [files] must pass [checkAttachments] first; [onProgress] reports the
  /// upload as a fraction.
  ///
  /// The collection asserts `data.message.id` and
  /// `data.message.conversation_id` only. When `data.message` also carries
  /// the fields of a message row it is returned so the chat can show it at
  /// once; otherwise `null`, and the next poll brings it.
  Future<ApiMessage?> send(
    int id,
    String text, {
    List<OutgoingFile> files = const [],
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      if (text.isNotEmpty) 'message': text,
      'type': messageTypeFor(files),
    });
    for (final f in files) {
      form.files.add(
        MapEntry(
          'files[]',
          MultipartFile.fromBytes(
            f.bytes,
            filename: f.name,
            contentType: f.mime == null ? null : DioMediaType.parse(f.mime!),
          ),
        ),
      );
    }
    final data = ApiEnvelope.unwrapData(
      await _client.post(
        '$_base/$id/messages',
        body: form,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress((sent / total).clamp(0, 1));
              },
      ),
    );
    final row = data is Json ? data['message'] : null;
    if (row is! Json) return null;
    try {
      return ApiMessage.fromJson(row);
    } on ApiException {
      return null;
    }
  }

  /// `GET /api/v1/conversations/{c}/attachments/{a}` — not role-prefixed;
  /// conversation membership is the authorization. Streams the file; the
  /// collection lists `X-Company` for it, which the client sends only on
  /// role routes, so it is added here. Bytes stay in memory.
  Future<DownloadedFile> downloadAttachment(
    int conversationId,
    int attachmentId, {
    int? companyId,
    void Function(double progress)? onProgress,
  }) async {
    final response = await _client.download(
      '/api/v1/conversations/$conversationId/attachments/$attachmentId',
      headers: {'X-Company': ?companyId?.toString()},
      onReceiveProgress: onProgress == null
          ? null
          : (got, total) {
              if (total > 0) onProgress((got / total).clamp(0, 1));
            },
    );
    return DownloadedFile(
      bytes: Uint8List.fromList(response.data ?? const []),
      contentType: response.headers.value('content-type'),
      fileName: fileNameFromDisposition(
        response.headers.value('content-disposition'),
      ),
    );
  }

  /// `PUT …/{id}` body `{title}` (≤ 255). 200 with `data.id`. Partial
  /// update since BE-16; the app sends the title only.
  Future<void> rename(int id, String title) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.put('$_base/$id', body: {'title': title}),
    );
    asInt(data['id']) ?? missingField('id');
  }

  /// `DELETE …/{id}` — "Delete Conversation For Me": hides the conversation
  /// for the caller only. 200 with `message`.
  Future<void> deleteForMe(int id) async {
    ApiEnvelope.unwrapData(await _client.delete('$_base/$id'));
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
/// overlaps a send never duplicates a message, and ordered by id (the
/// server's order), so clock skew never reorders them.
class MessageThread {
  const new({
    required this.messages,
    required this.hasEarlier,
    required this.cursor,
  });

  final List<ApiMessage> messages;
  final bool hasEarlier;

  /// The newest id a page from the server has confirmed: polls ask for
  /// `after_id` = this. A message added from a send response does not move
  /// it, so a message that arrived between the last poll and the send is
  /// still fetched.
  final int? cursor;

  int? get oldestId => messages.isEmpty ? null : messages.first.id;

  MessageThread merge(
    Iterable<ApiMessage> more, {
    bool? hasEarlier,
    int? cursor,
  }) {
    final byId = {for (final m in messages) m.id: m};
    for (final m in more) {
      byId[m.id] = m;
    }
    final next = cursor == null || (this.cursor ?? 0) >= cursor
        ? this.cursor
        : cursor;
    return MessageThread(
      messages: byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
      hasEarlier: hasEarlier ?? this.hasEarlier,
      cursor: next,
    );
  }
}

int? _newest(List<ApiMessage> page) => page.isEmpty ? null : page.last.id;

class ConversationThread extends AsyncNotifier<MessageThread> {
  new(this.conversationId);

  final int conversationId;

  /// Pages a single poll may follow when `has_more` says more are waiting.
  static const maxPollPages = 3;

  ConversationsRepository get _repo =>
      ref.read(conversationsRepositoryProvider);

  @override
  Future<MessageThread> build() async {
    _scope(ref);
    ref.watch(conversationsRepositoryProvider);
    _poll = null;
    _earlier = null;
    final page = await _repo.messages(conversationId);
    return MessageThread(
      messages: page.messages,
      hasEarlier: page.hasMore,
      cursor: _newest(page.messages),
    );
  }

  Future<void>? _earlier;
  Future<int>? _poll;

  bool get loadingEarlier => _earlier != null;

  /// One older page (`before_id` = the oldest loaded id). Calls while a page
  /// is loading share it.
  Future<void> loadEarlier() {
    final current = state.value;
    if (current == null || !current.hasEarlier) return Future.value();
    return _earlier ??= _loadEarlier(current)
        .whenComplete(() => _earlier = null);
  }

  Future<void> _loadEarlier(MessageThread current) async {
    final page = await _repo.messages(
      conversationId,
      beforeId: current.oldestId,
    );
    if (!ref.mounted) return;
    final now = state.value;
    if (now == null) return;
    state = AsyncData(now.merge(page.messages, hasEarlier: page.hasMore));
  }

  /// Newer messages (`after_id` = [MessageThread.cursor]). Returns how many
  /// arrived from other people. A failed poll throws and leaves the thread
  /// as it was.
  ///
  /// Calls while a poll runs share it (the timer never stacks requests);
  /// [fresh] waits for it and then asks again, for a caller that needs a
  /// state newer than its own action (a send).
  Future<int> poll({bool fresh = false}) async {
    final running = _poll;
    if (running != null) {
      if (!fresh) return await running;
      try {
        await running;
      } on Object {
        // The earlier poll's failure is its caller's; ask again.
      }
      if (!ref.mounted) return 0;
      final again = _poll;
      if (again != null) return await again;
    }
    final next = _pollOnce();
    _poll = next;
    try {
      return await next;
    } finally {
      if (identical(_poll, next)) _poll = null;
    }
  }

  Future<int> _pollOnce() async {
    final me = ref.read(sessionControllerProvider).value?.userId;
    var others = 0;
    for (var i = 0; i < maxPollPages; i++) {
      final current = state.value;
      if (current == null) return others;
      final page = await _repo.messages(
        conversationId,
        afterId: current.cursor,
      );
      // The chat may have closed while the page was on its way.
      if (!ref.mounted) return others;
      final now = state.value;
      if (now == null) return others;
      final known = {for (final m in now.messages) m.id};
      others += page.messages
          .where((m) => !known.contains(m.id) && m.senderId != me)
          .length;
      state = AsyncData(
        now.merge(
          page.messages,
          cursor: _newest(page.messages),
          // The first load of an empty conversation has no cursor: its
          // answer is the latest page, whose `has_more` is about history.
          hasEarlier: current.cursor == null ? page.hasMore : null,
        ),
      );
      if (!page.hasMore || current.cursor == null || page.messages.isEmpty) {
        break;
      }
    }
    return others;
  }

  /// A message the server confirmed in a send response.
  void addSent(ApiMessage message) {
    if (!ref.mounted) return;
    final now = state.value;
    if (now == null) return;
    state = AsyncData(now.merge([message]));
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
