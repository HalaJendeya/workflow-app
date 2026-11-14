import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// `status` of a meeting: `waiting | live | ended | cancelled` (the list
/// route's documented filter values). Anything else is [other].
enum ApiMeetingStatus { waiting, live, ended, cancelled, other }

/// `type`: `instant | scheduled`.
enum ApiMeetingType { instant, scheduled, other }

ApiMeetingStatus _status(Object? v) => switch (v) {
  'waiting' => ApiMeetingStatus.waiting,
  'live' => ApiMeetingStatus.live,
  'ended' => ApiMeetingStatus.ended,
  'cancelled' => ApiMeetingStatus.cancelled,
  _ => ApiMeetingStatus.other,
};

ApiMeetingType _type(Object? v) => switch (v) {
  'instant' => ApiMeetingType.instant,
  'scheduled' => ApiMeetingType.scheduled,
  _ => ApiMeetingType.other,
};

DateTime? _time(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? _name(Object? v) => v is Json ? v['name'] as String? : null;

/// The caller's own invitation embedded in a meeting row: `{id, status}`
/// (`pending | accepted | declined | expired`, seen live 2026-11-07).
typedef MyInvitation = ({int id, String status});

/// One meeting of `GET /api/v1/{client|employee}/meetings[/{id}]`.
///
/// Both roles reach the same controller (`Admin\MeetingController`). The
/// fields are those of the collection's "200 — live meeting" example and
/// the live employee response. `duration` is whole seconds and stays `0`
/// until the meeting ends; `elapsed_seconds` counts from the start while
/// live and is `null` before it (Phase 2 notes, 2026-10-22).
class ApiMeeting {
  const new({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    required this.code,
    required this.createdAt,
    this.description,
    this.creatorName,
    this.projectTitle,
    this.isPrivate = false,
    this.allowChat = false,
    this.allowScreenShare = false,
    this.allowWhiteboard = false,
    this.allowFileShare = false,
    this.maxParticipants,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.elapsedSeconds,
    this.peakParticipants,
    this.myInvitation,
  });

  factory fromJson(Json j) {
    final inv = j['my_invitation'];
    final invId = inv is Json ? asInt(inv['id']) : null;
    return ApiMeeting(
      id: asInt(j['id']) ?? missingField('id'),
      title: j['title'] is String
          ? j['title'] as String
          : missingField('title'),
      status: _status(j['status'] ?? missingField('status')),
      type: _type(j['type']),
      code: (j['meeting_code'] as String?) ?? '',
      createdAt: _time(j['created_at']) ?? missingField('created_at'),
      description: j['description'] as String?,
      creatorName: _name(j['creator']),
      projectTitle: switch (j['project']) {
        final Json p => p['title'] as String?,
        _ => null,
      },
      isPrivate: j['is_private'] == true,
      allowChat: j['allow_chat'] == true,
      allowScreenShare: j['allow_screen_share'] == true,
      allowWhiteboard: j['allow_whiteboard'] == true,
      allowFileShare: j['allow_file_share'] == true,
      maxParticipants: asInt(j['max_participants']),
      scheduledAt: _time(j['scheduled_at']),
      startedAt: _time(j['started_at']),
      endedAt: _time(j['ended_at']),
      durationSeconds: asInt(j['duration']),
      elapsedSeconds: asInt(j['elapsed_seconds']),
      peakParticipants: asInt(j['peak_participants']),
      myInvitation: inv is Json && invId != null
          ? (id: invId, status: (inv['status'] as String?) ?? '')
          : null,
    );
  }

  final int id;
  final String title;
  final ApiMeetingStatus status;
  final ApiMeetingType type;
  final String code;
  final DateTime createdAt;
  final String? description;
  final String? creatorName;
  final String? projectTitle;
  final bool isPrivate;
  final bool allowChat;
  final bool allowScreenShare;
  final bool allowWhiteboard;
  final bool allowFileShare;
  final int? maxParticipants;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final int? elapsedSeconds;

  /// `null` = not recorded (meetings older than the field).
  final int? peakParticipants;
  final MyInvitation? myInvitation;

  /// The date the meeting belongs to on the calendar: when it is planned,
  /// else when it started, else when it was created. Never a guessed time.
  DateTime get anchor => scheduledAt ?? startedAt ?? createdAt;

  /// Seconds the meeting has run: the final `duration` once ended, the
  /// server's `elapsed_seconds` while live, null before the start.
  int? get runSeconds => switch (status) {
    ApiMeetingStatus.ended => durationSeconds,
    ApiMeetingStatus.live => elapsedSeconds,
    _ => null,
  };

  /// A scheduled meeting that has not started and whose planned time has
  /// passed. Derived only from `type`, `status` and `scheduled_at`.
  bool isOverdue(DateTime now) =>
      type == ApiMeetingType.scheduled &&
      status == ApiMeetingStatus.waiting &&
      scheduledAt != null &&
      scheduledAt!.isBefore(now);
}

/// A row of `GET …/meetings/{id}/participants`. `duration` is cumulative
/// seconds over finished sessions; `user {id, name, avatar, type}`.
class ApiParticipant {
  const new({
    required this.id,
    required this.name,
    required this.role,
    required this.connection,
    this.userType,
  });

  factory fromJson(Json j) => ApiParticipant(
    id: asInt(j['id']) ?? missingField('id'),
    name: _name(j['user']) ?? '—',
    userType: switch (j['user']) {
      final Json u => u['type'] as String?,
      _ => null,
    },
    role: (j['role'] as String?) ?? '',
    connection: (j['connection_status'] as String?) ?? '',
  );

  final int id;
  final String name;
  final String? userType;

  /// `host | participant | …` as returned.
  final String role;

  /// `waiting | connected | disconnected`.
  final String connection;

  bool get isHost => role == 'host';
  bool get isConnected => connection == 'connected';
}

/// A row of `GET /employee/meetings/{id}/invitations` or of the caller's
/// own `GET …/meeting-invitations`.
class ApiInvitation {
  const new({
    required this.id,
    required this.status,
    this.userName,
    this.inviterName,
    this.meetingId,
    this.meetingTitle,
    this.meetingStatus,
    this.meetingScheduledAt,
  });

  factory fromJson(Json j) {
    final m = j['meeting'];
    return ApiInvitation(
      id: asInt(j['id']) ?? missingField('id'),
      status: (j['status'] as String?) ?? '',
      userName: _name(j['user']),
      inviterName: _name(j['inviter']),
      meetingId: asInt(j['meeting_id']) ?? (m is Json ? asInt(m['id']) : null),
      meetingTitle: m is Json ? m['title'] as String? : null,
      meetingStatus: m is Json ? _status(m['status']) : null,
      meetingScheduledAt: m is Json ? _time(m['scheduled_at']) : null,
    );
  }

  final int id;

  /// `pending | accepted | declined | expired`.
  final String status;
  final String? userName;
  final String? inviterName;
  final int? meetingId;
  final String? meetingTitle;
  final ApiMeetingStatus? meetingStatus;
  final DateTime? meetingScheduledAt;

  bool get isPending => status == 'pending';
}

typedef MeetingQuery = ({String search, ApiMeetingStatus? status, int page});

/// Counts per status, read from each filtered list's paginator `total`
/// (the meetings route returns no `stats` block).
typedef MeetingCounts = ({int total, int waiting, int live, int ended});

/// Meetings for the signed-in role. Reads are open to both roles
/// (`meetings.view`). The only write here is the invitee's own answer to
/// an invitation (`PUT …/meeting-invitations/{id}`, `status ∈ accepted,
/// declined`). Creating meetings has no client or employee route; joining
/// a room needs LiveKit, which the app does not ship yet.
class MeetingsRepository {
  new(this._client, this.portal) : _base = '/api/v1/${portal.name}';

  final ApiClient _client;
  final Portal portal;
  final String _base;

  static String statusParam(ApiMeetingStatus s) => s.name;

  Future<ApiPage<ApiMeeting>> list(MeetingQuery q, {int perPage = 10}) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '$_base/meetings',
        query: {
          'page': q.page,
          'per_page': perPage,
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          if (q.status case final s? when s != ApiMeetingStatus.other)
            'status': statusParam(s),
        },
      ),
    );
    return ApiPage.parse(_data(body), ApiMeeting.fromJson);
  }

  Future<MeetingCounts> counts() async {
    Future<int> total(ApiMeetingStatus? s) async {
      final body = ApiEnvelope.unwrapBody(
        await _client.get(
          '$_base/meetings',
          query: {'per_page': 1, if (s != null) 'status': statusParam(s)},
        ),
      );
      return asInt(_data(body)['total']) ?? missingField('data.total');
    }

    final r = await Future.wait([
      total(null),
      total(ApiMeetingStatus.waiting),
      total(ApiMeetingStatus.live),
      total(ApiMeetingStatus.ended),
    ]);
    return (total: r[0], waiting: r[1], live: r[2], ended: r[3]);
  }

  Future<ApiMeeting> get(int id) async => ApiMeeting.fromJson(
    ApiEnvelope.unwrapObject(await _client.get('$_base/meetings/$id')),
  );

  Future<ApiPage<ApiParticipant>> participants(int meetingId) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '$_base/meetings/$meetingId/participants',
        query: {'per_page': 100},
      ),
    );
    return ApiPage.parse(_data(body), ApiParticipant.fromJson);
  }

  /// Employee only: the client role has no route for a meeting's
  /// invitation list.
  Future<ApiPage<ApiInvitation>> invitations(int meetingId) async {
    assert(portal == Portal.employee, 'No client route for this list.');
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '$_base/meetings/$meetingId/invitations',
        query: {'per_page': 100},
      ),
    );
    return ApiPage.parse(_data(body), ApiInvitation.fromJson);
  }

  Future<ApiPage<ApiInvitation>> myInvitations({int page = 1}) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '$_base/meeting-invitations',
        query: {'page': page, 'per_page': 20},
      ),
    );
    return ApiPage.parse(_data(body), ApiInvitation.fromJson);
  }

  /// Accepts or declines the caller's own invitation.
  Future<void> respond(int invitationId, {required bool accept}) async {
    ApiEnvelope.unwrapData(
      await _client.put(
        '$_base/meeting-invitations/$invitationId',
        body: {'status': accept ? 'accepted' : 'declined'},
      ),
    );
  }

  static Json _data(Json body) {
    final d = body['data'];
    if (d is! Json) missingField('data');
    return d;
  }

  /// `POST /{role}/meetings/{id}/join` (no body). 200: the caller's
  /// participant row (`data.id`, `data.connection_status`). 202: in an
  /// `approval` meeting a caller not on the roster gets `{join_request}`
  /// and waits for the host (2026-11-04). 403/404/422 are errors.
  Future<JoinOutcome> join(int meetingId) async {
    final response = await _client.post('$_base/meetings/$meetingId/join');
    // 202 carries `{join_request}`, whose fields are not documented: only
    // the status is used.
    if (response.statusCode == 202) {
      ApiEnvelope.unwrapData(response);
      return const JoinRequested();
    }
    final data = ApiEnvelope.unwrapObject(response);
    final status = data['connection_status'];
    return Joined(
      participantId: asInt(data['id']) ?? missingField('id'),
      connectionStatus: status is String
          ? status
          : missingField('connection_status'),
    );
  }

  /// `POST /{role}/meeting-participants/{id}/leave` (no body).
  Future<void> leave(int participantId) async {
    ApiEnvelope.unwrapObject(
      await _client.post('$_base/meeting-participants/$participantId/leave'),
    );
  }
}

/// What joining a meeting led to.
sealed class JoinOutcome {
  const new();
}

/// On the roster: the caller's participant row.
class Joined extends JoinOutcome {
  const new({required this.participantId, required this.connectionStatus});

  final int participantId;

  /// `waiting | connected | disconnected`.
  final String connectionStatus;
}

/// 202: a join request the host must admit.
class JoinRequested extends JoinOutcome {
  const new();
}

/// This account's join state for one meeting. Kept while the session and
/// company stay the same, so leaving and reopening the meeting never offers
/// Join again over a pending request or an active participation.
class MeetingJoinState {
  const new({this.outcome, this.busy = false, this.left = false, this.error});

  final JoinOutcome? outcome;

  /// A join or leave is on its way; a second tap does nothing.
  final bool busy;

  /// Left after joining in this session.
  final bool left;

  /// The last join or leave failure (a refusal carries the server's
  /// reason).
  final Object? error;
}

class MeetingJoin extends Notifier<MeetingJoinState> {
  new(this.meetingId);

  final int meetingId;

  @override
  MeetingJoinState build() {
    _scope(ref);
    return const MeetingJoinState();
  }

  /// `POST …/join`. After a 202 this is "Try joining again": the client
  /// role has no route to read its join request, so asking again is the
  /// only way to learn the host admitted it (200) or refused it (an error
  /// with the server's reason).
  Future<void> join() async {
    if (state.busy || state.outcome is Joined) return;
    final before = state;
    state = MeetingJoinState(outcome: before.outcome, busy: true);
    try {
      final outcome = await ref
          .read(meetingsRepositoryProvider)
          .join(meetingId);
      if (!ref.mounted) return;
      state = MeetingJoinState(outcome: outcome);
      ref.invalidate(apiParticipantsProvider(meetingId));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = MeetingJoinState(
        outcome: before.outcome,
        left: before.left,
        error: e,
      );
    }
  }

  /// `POST meeting-participants/{id}/leave`, only after a join in this
  /// session (the participant id comes from that answer).
  Future<void> leave() async {
    final joined = state.outcome;
    if (state.busy || joined is! Joined) return;
    state = MeetingJoinState(outcome: joined, busy: true);
    try {
      await ref.read(meetingsRepositoryProvider).leave(joined.participantId);
      if (!ref.mounted) return;
      state = const MeetingJoinState(left: true);
      ref.invalidate(apiParticipantsProvider(meetingId));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = MeetingJoinState(outcome: joined, error: e);
    }
  }
}

final NotifierProviderFamily<MeetingJoin, MeetingJoinState, int>
meetingJoinProvider =
    NotifierProvider.family<MeetingJoin, MeetingJoinState, int>(
      MeetingJoin.new,
    );

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  final portal =
      ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
  return MeetingsRepository(ref.watch(apiClientProvider), portal);
});

final FutureProviderFamily<ApiPage<ApiMeeting>, MeetingQuery>
apiMeetingsProvider = FutureProvider.autoDispose
    .family<ApiPage<ApiMeeting>, MeetingQuery>((ref, q) {
      _scope(ref);
      return ref.watch(meetingsRepositoryProvider).list(q);
    });

/// The first 100 meetings, for the calendar and the day list. The list
/// route has no date filter, so the calendar can only mark what it loads.
final FutureProvider<ApiPage<ApiMeeting>> apiMeetingCalendarProvider =
    FutureProvider.autoDispose((ref) {
      _scope(ref);
      return ref.watch(meetingsRepositoryProvider).list((
        search: '',
        status: null,
        page: 1,
      ), perPage: 100);
    });

/// Status counts. When the calendar page already holds every meeting they
/// are counted from it; otherwise one `per_page=1` request per status
/// reads the paginator totals.
final FutureProvider<MeetingCounts> apiMeetingCountsProvider =
    FutureProvider.autoDispose((ref) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      final all = await ref.watch(apiMeetingCalendarProvider.future);
      if (all.total > all.items.length) return await repo.counts();
      int n(ApiMeetingStatus s) => all.items.where((m) => m.status == s).length;
      return (
        total: all.total,
        waiting: n(ApiMeetingStatus.waiting),
        live: n(ApiMeetingStatus.live),
        ended: n(ApiMeetingStatus.ended),
      );
    });

final FutureProviderFamily<ApiMeeting, int> apiMeetingProvider = FutureProvider
    .autoDispose
    .family<ApiMeeting, int>((ref, id) {
      _scope(ref);
      return ref.watch(meetingsRepositoryProvider).get(id);
    });

final FutureProviderFamily<ApiPage<ApiParticipant>, int>
apiParticipantsProvider = FutureProvider.autoDispose
    .family<ApiPage<ApiParticipant>, int>((ref, id) {
      _scope(ref);
      return ref.watch(meetingsRepositoryProvider).participants(id);
    });

final FutureProviderFamily<ApiPage<ApiInvitation>, int>
apiMeetingInvitationsProvider = FutureProvider.autoDispose
    .family<ApiPage<ApiInvitation>, int>((ref, id) {
      _scope(ref);
      return ref.watch(meetingsRepositoryProvider).invitations(id);
    });

final FutureProvider<ApiPage<ApiInvitation>> apiMyInvitationsProvider =
    FutureProvider.autoDispose((ref) {
      _scope(ref);
      return ref.watch(meetingsRepositoryProvider).myInvitations();
    });

/// Meetings belong to one account in one company.
void _scope(Ref ref) => ref.watch(
  sessionControllerProvider.select(
    (s) => (s.value?.userId, s.value?.companyId),
  ),
);
