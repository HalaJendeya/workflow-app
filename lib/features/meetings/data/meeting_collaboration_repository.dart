import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';

/// Read-only meeting collaboration (`05 Client / 07 Meetings`, folders
/// 05 Chat, 06 Polls, 08 Notes, 09 Decisions, 10 Action Items,
/// 11 Attachments). Nothing here sends a message, votes, or changes a note,
/// decision or action item.
///
/// The collection asserts almost no row fields for these routes, so each
/// model reads only what is documented: the tests' required fields, the
/// documented filter values, and the field names of the matching write
/// rules (`StoreMeeting…Request`). Sender, time, vote counts and assignee
/// names are not documented and are not read (`docs/api-contract-gaps.md`
/// C16–C21).
///
/// Live (2026-11-19, employee role, same controllers): every one of these
/// routes answers 403 "You must be a participant of this meeting to use
/// its …" until the caller has joined the meeting.

/// One chat message: `id` (test), `message` (`StoreMeetingMessageRequest`;
/// null when the message is only a file) and `attachments[].id` (the send
/// test reads `data.attachments.0.id`).
class MeetingMessage {
  const new({required this.id, this.text, this.attachmentIds = const []});

  factory fromJson(Json j) {
    final files = j['attachments'];
    return MeetingMessage(
      id: asInt(j['id']) ?? missingField('id'),
      text: switch (j['message']) {
        final String s when s.trim().isNotEmpty => s,
        _ => null,
      },
      attachmentIds: [
        if (files is List)
          for (final f in files.whereType<Json>())
            asInt(f['id']) ?? missingField('attachments.id'),
      ],
    );
  }

  final int id;
  final String? text;
  final List<int> attachmentIds;
}

/// A poll row of `GET …/meetings/{id}/polls`: `id` (seeded from the list)
/// and `question` (`StoreMeetingPollRequest`).
class MeetingPoll {
  const new({required this.id, this.question});

  factory fromJson(Json j) => MeetingPoll(
    id: asInt(j['id']) ?? missingField('id'),
    question: _text(j['question']),
  );

  final int id;
  final String? question;
}

/// `GET meeting-polls/{id}`: the test requires `data.id` and
/// `data.options`; an option is `{id, title}` (vote sends option ids;
/// create sends `options[].title`). Per-option results are not documented.
class MeetingPollDetails {
  const new({required this.id, required this.options, this.question});

  factory fromJson(Json j) {
    final options = j['options'];
    if (options is! List) missingField('options');
    return MeetingPollDetails(
      id: asInt(j['id']) ?? missingField('id'),
      question: _text(j['question']),
      options: [
        for (final o in options.whereType<Json>())
          (
            id: asInt(o['id']) ?? missingField('options.id'),
            title: _text(o['title']) ?? missingField('options.title'),
          ),
      ],
    );
  }

  final int id;
  final String? question;
  final List<({int id, String title})> options;
}

/// `status` of a note (`StoreMeetingNoteRequest`: `draft|published`).
enum NoteStatus { draft, published }

/// A note: `title` (nullable), `content` (required on write), `status`,
/// `is_shared`.
class MeetingNote {
  const new({
    required this.id,
    required this.content,
    this.title,
    this.status,
    this.isShared,
  });

  factory fromJson(Json j) => MeetingNote(
    id: asInt(j['id']) ?? missingField('id'),
    title: _text(j['title']),
    content: j['content'] is String
        ? j['content'] as String
        : missingField('content'),
    status: switch (j['status']) {
      'draft' => NoteStatus.draft,
      'published' => NoteStatus.published,
      _ => null,
    },
    isShared: j['is_shared'] is bool ? j['is_shared'] as bool : null,
  );

  final int id;
  final String? title;
  final String content;
  final NoteStatus? status;
  final bool? isShared;
}

/// `status` filter of decisions: `pending | approved | rejected`.
enum DecisionStatus { pending, approved, rejected }

/// A decision: `title` (required on write), `description`, `status`. The
/// documented `assigned_to` is a user id only, so it is not shown.
class MeetingDecision {
  const new({
    required this.id,
    required this.title,
    this.description,
    this.status,
  });

  factory fromJson(Json j) => MeetingDecision(
    id: asInt(j['id']) ?? missingField('id'),
    title: _text(j['title']) ?? missingField('title'),
    description: _text(j['description']),
    status: switch (j['status']) {
      'pending' => DecisionStatus.pending,
      'approved' => DecisionStatus.approved,
      'rejected' => DecisionStatus.rejected,
      _ => null,
    },
  );

  final int id;
  final String title;
  final String? description;
  final DecisionStatus? status;
}

/// `status` filter of action items:
/// `pending | in_progress | completed | cancelled`.
enum ActionItemStatus { pending, inProgress, completed, cancelled }

/// `priority` (`StoreMeetingActionItemRequest`: `low|medium|high|urgent`).
enum ActionItemPriority { low, medium, high, urgent }

/// An action item: `title`, `description`, `status`, `priority`,
/// `due_date`. `assigned_to` is a user id only and is not shown.
class MeetingActionItem {
  const new({
    required this.id,
    required this.title,
    this.description,
    this.status,
    this.priority,
    this.dueDate,
  });

  factory fromJson(Json j) => MeetingActionItem(
    id: asInt(j['id']) ?? missingField('id'),
    title: _text(j['title']) ?? missingField('title'),
    description: _text(j['description']),
    status: switch (j['status']) {
      'pending' => ActionItemStatus.pending,
      'in_progress' => ActionItemStatus.inProgress,
      'completed' => ActionItemStatus.completed,
      'cancelled' => ActionItemStatus.cancelled,
      _ => null,
    },
    priority: switch (j['priority']) {
      'low' => ActionItemPriority.low,
      'medium' => ActionItemPriority.medium,
      'high' => ActionItemPriority.high,
      'urgent' => ActionItemPriority.urgent,
      _ => null,
    },
    dueDate: asDate(j['due_date']),
  );

  final int id;
  final String title;
  final String? description;
  final ActionItemStatus? status;
  final ActionItemPriority? priority;
  final DateTime? dueDate;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

String actionItemStatusWire(ActionItemStatus s) => switch (s) {
  ActionItemStatus.inProgress => 'in_progress',
  _ => s.name,
};

/// A page of meeting chat. The route's paginator gives `last_page`; with a
/// `before_id` cursor it says whether older messages remain.
typedef MeetingMessagePage = ({List<MeetingMessage> items, bool hasOlder});

class MeetingCollaborationRepository {
  new(this._client, this.portal) : _base = '/api/v1/${portal.name}';

  final ApiClient _client;
  final Portal portal;
  final String _base;

  static const messagePageSize = 30;

  /// `GET …/meetings/{id}/messages` (`per_page`, cursors `after_id` /
  /// `before_id`, 2026-11-01). Read-only.
  Future<MeetingMessagePage> messages(
    int meetingId, {
    int? beforeId,
    int? afterId,
  }) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.get(
        '$_base/meetings/$meetingId/messages',
        query: {
          'per_page': messagePageSize,
          'before_id': ?beforeId,
          'after_id': ?afterId,
        },
      ),
    );
    final page = ApiPage.parse(data, MeetingMessage.fromJson);
    return (items: page.items, hasOlder: page.lastPage > page.currentPage);
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Json) row, {
    Json? query,
  }) async {
    final data = ApiEnvelope.unwrapData(await _client.get(path, query: query));
    if (data is! List) missingField('data');
    return [for (final j in data.whereType<Json>()) row(j)];
  }

  /// `GET …/meetings/{id}/polls`: `data` is a list.
  Future<List<MeetingPoll>> polls(int meetingId) =>
      _list('$_base/meetings/$meetingId/polls', MeetingPoll.fromJson);

  /// `GET …/meeting-polls/{id}`: the poll with its `options`.
  Future<MeetingPollDetails> poll(int pollId) async =>
      MeetingPollDetails.fromJson(
        ApiEnvelope.unwrapObject(
          await _client.get('$_base/meeting-polls/$pollId'),
        ),
      );

  /// `GET …/meetings/{id}/notes`: `data` is a list.
  Future<List<MeetingNote>> notes(int meetingId) =>
      _list('$_base/meetings/$meetingId/notes', MeetingNote.fromJson);

  /// `GET …/meetings/{id}/decisions` with the documented `status` filter.
  Future<List<MeetingDecision>> decisions(
    int meetingId, {
    DecisionStatus? status,
  }) => _list(
    '$_base/meetings/$meetingId/decisions',
    MeetingDecision.fromJson,
    query: {'status': ?status?.name},
  );

  /// `GET …/meetings/{id}/action-items` with the documented `status`
  /// filter (`assigned_to` is not used: the app has no people list here).
  Future<List<MeetingActionItem>> actionItems(
    int meetingId, {
    ActionItemStatus? status,
  }) => _list(
    '$_base/meetings/$meetingId/action-items',
    MeetingActionItem.fromJson,
    query: {if (status != null) 'status': actionItemStatusWire(status)},
  );

  /// `GET …/meeting-attachments/{id}/download`: the file bytes (not
  /// JSON); the name comes from `Content-Disposition`. Kept in memory.
  Future<DownloadedFile> downloadAttachment(int attachmentId) async {
    final response = await _client.download(
      '$_base/meeting-attachments/$attachmentId/download',
    );
    return DownloadedFile(
      bytes: Uint8List.fromList(response.data ?? const []),
      contentType: response.headers.value('content-type'),
      fileName: fileNameFromDisposition(
        response.headers.value('content-disposition'),
      ),
    );
  }
}

final meetingCollaborationRepositoryProvider =
    Provider<MeetingCollaborationRepository>(
      (ref) => MeetingCollaborationRepository(
        ref.watch(apiClientProvider),
        ref.watch(meetingsRepositoryProvider).portal,
      ),
    );

/// Collaboration data belongs to one account in one company.
void _scope(Ref ref) => ref.watch(
  sessionControllerProvider.select(
    (s) => (s.value?.userId, s.value?.companyId),
  ),
);

final FutureProviderFamily<List<MeetingPoll>, int> meetingPollsProvider =
    FutureProvider.autoDispose.family<List<MeetingPoll>, int>((ref, id) {
      _scope(ref);
      return ref.watch(meetingCollaborationRepositoryProvider).polls(id);
    });

final FutureProviderFamily<MeetingPollDetails, int> meetingPollProvider =
    FutureProvider.autoDispose.family<MeetingPollDetails, int>((ref, id) {
      _scope(ref);
      return ref.watch(meetingCollaborationRepositoryProvider).poll(id);
    });

final FutureProviderFamily<List<MeetingNote>, int> meetingNotesProvider =
    FutureProvider.autoDispose.family<List<MeetingNote>, int>((ref, id) {
      _scope(ref);
      return ref.watch(meetingCollaborationRepositoryProvider).notes(id);
    });

typedef DecisionQuery = ({int meetingId, DecisionStatus? status});

final FutureProviderFamily<List<MeetingDecision>, DecisionQuery>
meetingDecisionsProvider = FutureProvider.autoDispose
    .family<List<MeetingDecision>, DecisionQuery>((ref, q) {
      _scope(ref);
      return ref
          .watch(meetingCollaborationRepositoryProvider)
          .decisions(q.meetingId, status: q.status);
    });

typedef ActionItemQuery = ({int meetingId, ActionItemStatus? status});

final FutureProviderFamily<List<MeetingActionItem>, ActionItemQuery>
meetingActionItemsProvider = FutureProvider.autoDispose
    .family<List<MeetingActionItem>, ActionItemQuery>((ref, q) {
      _scope(ref);
      return ref
          .watch(meetingCollaborationRepositoryProvider)
          .actionItems(q.meetingId, status: q.status);
    });

/// The meeting chat as far as it has been read: the newest page first,
/// then older pages on request ([loadEarlier], `before_id`) and newer
/// messages on [refresh] (`after_id`). Messages merge by id, so nothing is
/// shown twice; they are ordered by id (the collection documents no time
/// field). Read-only: this never sends.
class MeetingChat extends AsyncNotifier<MeetingMessagePage> {
  new(this.meetingId);

  final int meetingId;

  MeetingCollaborationRepository get _repo =>
      ref.read(meetingCollaborationRepositoryProvider);

  static List<MeetingMessage> _merge(
    Iterable<MeetingMessage> a,
    Iterable<MeetingMessage> b,
  ) {
    final byId = {for (final m in a) m.id: m, for (final m in b) m.id: m};
    return byId.values.toList()..sort((x, y) => x.id.compareTo(y.id));
  }

  @override
  Future<MeetingMessagePage> build() async {
    _scope(ref);
    ref.watch(meetingCollaborationRepositoryProvider);
    final page = await _repo.messages(meetingId);
    return (items: _merge(const [], page.items), hasOlder: page.hasOlder);
  }

  /// Older messages before the oldest one shown.
  Future<void> loadEarlier() async {
    final now = state.value;
    if (now == null || !now.hasOlder || now.items.isEmpty) return;
    final page = await _repo.messages(meetingId, beforeId: now.items.first.id);
    if (!ref.mounted) return;
    state = AsyncData((
      items: _merge(now.items, page.items),
      hasOlder: page.hasOlder,
    ));
  }

  /// Newer messages after the newest one shown (or the first page when
  /// none is shown yet).
  Future<void> refresh() async {
    final now = state.value;
    if (now == null || now.items.isEmpty) {
      ref.invalidateSelf();
      await future;
      return;
    }
    final page = await _repo.messages(meetingId, afterId: now.items.last.id);
    if (!ref.mounted) return;
    state = AsyncData((
      items: _merge(now.items, page.items),
      hasOlder: now.hasOlder,
    ));
  }
}

final AsyncNotifierProviderFamily<MeetingChat, MeetingMessagePage, int>
meetingChatProvider = AsyncNotifierProvider.autoDispose
    .family<MeetingChat, MeetingMessagePage, int>(MeetingChat.new);
