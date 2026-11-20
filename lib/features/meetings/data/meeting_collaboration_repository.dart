import 'dart:convert' show ascii;
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
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

/// Meeting collaboration (`05 Client / 07 Meetings`, folders 05 Chat,
/// 06 Polls, 08 Notes, 09 Decisions, 10 Action Items, 11 Attachments).
///
/// C4: the client's only documented writes are `Send Chat Message` and
/// `Vote In Poll` (permission `meetings.view`). Creating, editing or
/// deleting notes, decisions, action items and polls needs
/// `meetings.update`, which the client role is not granted (the
/// collection's "Permission Boundary (expected 403)" folder), and
/// approve/reject has no client route at all, so none of those exist here.
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

/// What `POST meeting-polls/{id}/vote` answers: the test requires
/// `data.id` and `data.total_votes` (nothing per option).
typedef PollVoteResult = ({int pollId, int totalVotes});

/// Meeting chat files (`StoreMeetingMessageRequest.file`): one file per
/// message, sent under the key `file` only (BE-28), at most 10 240 KB, of
/// the route's `mimetypes`, and only when the meeting has
/// `allow_file_share` on. Checked on the content, like conversation files.
abstract final class MeetingFileRules {
  static const int maxBytes = 10240 * 1024;

  static const Set<String> allowed = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'text/plain',
    'video/mp4',
    'audio/mpeg',
    'application/zip',
  };

  /// Extensions the picker offers; the content still decides.
  static const extensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'pdf',
    'txt',
    'mp4',
    'mp3',
    'zip',
  ];
}

/// The MIME type of [bytes] for a meeting file: ZIP, MP4 and MP3 by
/// signature (checked first: their headers are not text), else
/// [sniffMime].
String? sniffMeetingMime(Uint8List bytes) {
  bool at(int i, List<int> sig) {
    if (bytes.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (bytes[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, const [0x50, 0x4B, 0x03, 0x04]) ||
      at(0, const [0x50, 0x4B, 0x05, 0x06])) {
    return 'application/zip';
  }
  if (at(4, ascii.encode('ftyp'))) return 'video/mp4';
  if (at(0, ascii.encode('ID3')) ||
      (bytes.length > 1 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
    return 'audio/mpeg';
  }
  return sniffMime(bytes);
}

/// The rule [file] breaks for a meeting message, or `null` when the server
/// should take it. Nothing is uploaded until this passes.
AttachmentProblem? checkMeetingFile(OutgoingFile file) {
  if (file.bytes.isEmpty) return AttachmentProblem.empty;
  if (file.bytes.length > MeetingFileRules.maxBytes) {
    return AttachmentProblem.tooLarge;
  }
  if (!MeetingFileRules.allowed.contains(sniffMeetingMime(file.bytes))) {
    return AttachmentProblem.typeNotAllowed;
  }
  return null;
}

/// `message` is at most 5000 characters (`max:5000`).
const meetingMessageMaxLength = 5000;

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

  /// `POST …/meetings/{id}/messages` (`Send Chat Message`, expected 201;
  /// the test requires `data.id`). Text alone goes as the documented JSON
  /// body `{message}`; with a file the body is multipart with the single
  /// key `file` (BE-28) plus `message` when there is text. `message` and
  /// `file` are `required_without` each other. [file] must pass
  /// [checkMeetingFile] first. Returns the new message id.
  Future<int> sendMessage(
    int meetingId, {
    String text = '',
    OutgoingFile? file,
    void Function(double progress)? onProgress,
  }) async {
    final message = text.trim();
    if (message.isEmpty && file == null) {
      throw ArgumentError('A meeting message needs text or a file.');
    }
    if (message.length > meetingMessageMaxLength) {
      throw ArgumentError('A meeting message is at most 5000 characters.');
    }
    final Object body;
    if (file == null) {
      body = {'message': message};
    } else {
      final mime = sniffMeetingMime(file.bytes);
      body = FormData.fromMap({
        if (message.isNotEmpty) 'message': message,
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.name,
          contentType: mime == null ? null : DioMediaType.parse(mime),
        ),
      });
    }
    final data = ApiEnvelope.unwrapObject(
      await _client.post(
        '$_base/meetings/$meetingId/messages',
        body: body,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress((sent / total).clamp(0, 1));
              },
      ),
    );
    return asInt(data['id']) ?? missingField('id');
  }

  /// `POST …/meeting-polls/{id}/vote` with `option_ids` (required, at least
  /// one integer id from the poll's `options`).
  Future<PollVoteResult> vote(int pollId, List<int> optionIds) async {
    if (optionIds.isEmpty) {
      throw ArgumentError('A vote needs at least one option id.');
    }
    final data = ApiEnvelope.unwrapObject(
      await _client.post(
        '$_base/meeting-polls/$pollId/vote',
        body: {'option_ids': optionIds},
      ),
    );
    return (
      pollId: asInt(data['id']) ?? missingField('id'),
      totalVotes: asInt(data['total_votes']) ?? missingField('total_votes'),
    );
  }

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
/// field). Sending is [MeetingMessageSender].
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

/// Sends one meeting message at a time
/// ([MeetingCollaborationRepository.sendMessage]). A send while another is
/// on the way is ignored, so a double tap never posts twice. After a 201
/// the chat reads what is new (`after_id`); a failure of that read does not
/// undo the send. The state is the last outcome: the new id or the error.
class MeetingMessageSender extends AsyncNotifier<int?> {
  new(this.meetingId);

  final int meetingId;

  @override
  int? build() {
    _scope(ref);
    return null;
  }

  /// `true` when the message was sent; `false` when it failed or another
  /// send was already on the way.
  Future<bool> send({
    String text = '',
    OutgoingFile? file,
    void Function(double progress)? onProgress,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading<int?>();
    final result = await AsyncValue.guard(
      () => ref
          .read(meetingCollaborationRepositoryProvider)
          .sendMessage(
            meetingId,
            text: text,
            file: file,
            onProgress: onProgress,
          ),
    );
    if (!ref.mounted) return result.hasValue;
    state = result;
    if (!result.hasValue) return false;
    try {
      await ref.read(meetingChatProvider(meetingId).notifier).refresh();
    } on Object {
      // Sent; the next refresh shows it.
    }
    return true;
  }
}

final AsyncNotifierProviderFamily<MeetingMessageSender, int?, int>
meetingMessageSenderProvider = AsyncNotifierProvider.autoDispose
    .family<MeetingMessageSender, int?, int>(MeetingMessageSender.new);

/// Votes in one poll ([MeetingCollaborationRepository.vote]). One vote at a
/// time; after a 200 the poll and the meeting's poll list are read again.
/// Whether a vote may be changed is the server's rule (`allow_change_vote`
/// is not on the read model): a refusal comes back as the error.
class PollVoter extends AsyncNotifier<PollVoteResult?> {
  new(this.pollId);

  final int pollId;

  @override
  PollVoteResult? build() {
    _scope(ref);
    return null;
  }

  Future<bool> vote({
    required int meetingId,
    required List<int> optionIds,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading<PollVoteResult?>();
    final result = await AsyncValue.guard(
      () => ref
          .read(meetingCollaborationRepositoryProvider)
          .vote(pollId, optionIds),
    );
    if (!ref.mounted) return result.hasValue;
    state = result;
    if (!result.hasValue) return false;
    ref
      ..invalidate(meetingPollProvider(pollId))
      ..invalidate(meetingPollsProvider(meetingId));
    return true;
  }
}

final AsyncNotifierProviderFamily<PollVoter, PollVoteResult?, int>
pollVoterProvider = AsyncNotifierProvider.autoDispose
    .family<PollVoter, PollVoteResult?, int>(PollVoter.new);
