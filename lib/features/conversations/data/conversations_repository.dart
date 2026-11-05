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
/// the ones the live server returns (work.isradev.shop, employee account);
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
}

final conversationsRepositoryProvider = Provider<ConversationsRepository>((
  ref,
) {
  final portal =
      ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
  return ConversationsRepository(ref.watch(apiClientProvider), portal);
});

final FutureProvider<List<ApiConversation>> apiConversationsProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(conversationsRepositoryProvider).list(),
    );

final FutureProviderFamily<ApiConversation, int> apiConversationProvider =
    FutureProvider.autoDispose.family(
      (ref, id) => ref.watch(conversationsRepositoryProvider).open(id),
    );
