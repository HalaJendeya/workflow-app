import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/data/meeting_media.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_media.dart';

/// Meeting audio/video: the documented `04 Media & LiveKit` contract and the
/// session logic behind the media-engine interfaces. No LiveKit SDK is in
/// the app (awaiting approval), so the room here is a fake; no media
/// request was sent live.

class _Creds implements ApiCredentials {
  @override
  String? token = 'tkn';
  @override
  int? companyId = 3;
  @override
  void onUnauthorized() {}
}

const _secret = 'eyJ.livekit-secret-token';

Map<String, dynamic> _granted({String url = 'wss://media.example.test'}) => ok({
  'participant': {'id': 55, 'connection_status': 'connected'},
  'media': {'token': _secret, 'url': url, 'room': 'room-uuid'},
});

void main() {
  group('media contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late MeetingMediaApi api;

    setUp(() {
      http = FakeHttpAdapter();
      api = MeetingMediaApi(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
        '/api/v1/client',
      );
    });

    test('media/join: device id in, participant + credentials out', () async {
      http.reply(200, _granted());
      final out = await api.join(41, 'device-abcdef12');
      expect(http.last.path, '/api/v1/client/meetings/41/media/join');
      expect(http.last.headers['X-Company'], '3');
      expect(http.lastJsonBody, {'device_id': 'device-abcdef12'});
      final g = out as MediaGranted;
      expect(g.participantId, 55);
      expect(g.credentials.url, 'wss://media.example.test');
      expect(g.credentials.room, 'room-uuid');
      // The token never shows up in text.
      expect(g.toString(), isNot(contains(_secret)));
      expect(g.credentials.toString(), isNot(contains(_secret)));
    });

    test('202 is a join request without credentials', () async {
      http.reply(
        202,
        ok({
          'join_request': {'id': 5, 'status': 'pending'},
          'media': null,
        }),
      );
      expect(await api.join(41, 'device-abcdef12'), isA<MediaJoinRequested>());
    });

    test('missing credentials or an insecure URL are invalid', () async {
      http.reply(
        200,
        ok({
          'participant': {'id': 55},
          'media': {'url': 'wss://m.test', 'room': 'r'},
        }),
      );
      await expectLater(
        api.join(41, 'device-abcdef12'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
      http.reply(200, _granted(url: 'ws://plain.example.test'));
      await expectLater(
        api.join(41, 'device-abcdef12'),
        throwsA(isA<ApiException>()),
      );
    });

    test('media/state and media/leave send the documented bodies', () async {
      http.reply(
        200,
        ok({
          'participant': {'id': 55},
        }),
      );
      await api.state(41, microphone: false);
      expect(http.last.path, '/api/v1/client/meetings/41/media/state');
      expect(http.lastJsonBody, {'microphone_enabled': false});
      http.reply(200, ok({'id': 55}));
      await api.leave(41, 'device-abcdef12');
      expect(http.last.path, '/api/v1/client/meetings/41/media/leave');
      expect(http.lastJsonBody, {'device_id': 'device-abcdef12'});
    });

    test('LiveKit not configured on the server is a server failure', () async {
      http.reply(500, failure('LiveKit is not configured.'));
      await expectLater(
        api.join(41, 'device-abcdef12'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.server,
          ),
        ),
      );
    });
  });

  group('device id', () {
    test('generated once, valid, and reused', () async {
      final store = MemoryDeviceIdStore();
      final a = await deviceIdFrom(store, Random(1));
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
      expect(await deviceIdFrom(store, Random(2)), a);
      // A corrupted stored value is replaced, not sent.
      await store.write('bad id!');
      expect(await deviceIdFrom(store), isNot('bad id!'));
    });
  });

  group('media session (fake engine)', () {
    late FakeMediaEngine engine;
    late _Api api;
    late ProviderContainer c;

    setUp(() async {
      engine = FakeMediaEngine();
      api = _Api();
      final ids = MemoryDeviceIdStore();
      await ids.write('device-abcdef12');
      c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
          ),
          sessionControllerProvider.overrideWith(_Session.new),
          mediaEngineProvider.overrideWithValue(engine),
          meetingMediaApiProvider.overrideWithValue(api),
          deviceIdStoreProvider.overrideWithValue(ids),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
    });

    ProviderSubscription<MediaSessionState> open() =>
        c.listen(meetingMediaProvider(41), (_, _) {});
    MeetingMediaController media() => c.read(meetingMediaProvider(41).notifier);
    MediaSessionState state() => c.read(meetingMediaProvider(41));

    test('no engine: nothing is asked or sent', () async {
      c = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(_Session.new),
          meetingMediaApiProvider.overrideWithValue(api),
          mediaEngineProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
      open();
      await media().join();
      expect(state().phase, MediaPhase.idle);
      expect(api.calls, isEmpty);
    });

    test('a refused microphone stops before any request', () async {
      open();
      engine.microphone = MediaPermission.permanentlyDenied;
      await media().join(camera: true);
      expect(state().phase, MediaPhase.permissionDenied);
      expect(state().permanentlyDenied, isTrue);
      expect(api.calls, isEmpty);
      expect(engine.rooms, isEmpty);
    });

    test('a refused camera joins with audio only', () async {
      open();
      engine.camera = MediaPermission.denied;
      await media().join(camera: true);
      expect(state().phase, MediaPhase.connected);
      expect(state().microphone, isTrue);
      expect(state().camera, isFalse);
      final room = engine.rooms.single;
      expect(room.connectedWith, ('wss://media.example.test', _secret));
      expect(room.camera, isFalse);
    });

    test('connected state never holds the token', () async {
      open();
      await media().join();
      final s = state();
      expect(s.phase, MediaPhase.connected);
      expect('${s.phase} ${s.error}', isNot(contains(_secret)));
    });

    test('repeated Join while joining sends one request', () async {
      open();
      api.gate = Completer<void>();
      final a = media().join();
      final b = media().join();
      await pumpEventQueue();
      api.gate!.complete();
      await Future.wait([a, b]);
      expect(api.calls.where((x) => x == 'join'), hasLength(1));
      expect(engine.rooms, hasLength(1));
      // Inside: Join does nothing.
      await media().join();
      expect(api.calls.where((x) => x == 'join'), hasLength(1));
    });

    test('202 waits for the host; trying again can admit', () async {
      open();
      api.next = const MediaJoinRequested();
      await media().join();
      expect(state().phase, MediaPhase.waitingForHost);
      expect(engine.rooms, isEmpty, reason: 'no room before admission');
      api.next = null;
      await media().join();
      expect(state().phase, MediaPhase.connected);
    });

    test('a refusal shows the server reason', () async {
      open();
      api.error = const ApiException(
        kind: ApiFailureKind.forbidden,
        message: 'Your join request was rejected.',
        statusCode: 403,
      );
      await media().join();
      expect(state().phase, MediaPhase.failed);
      expect((state().error! as ApiException).message, contains('rejected'));
      expect(engine.rooms, isEmpty);
    });

    test('a room that fails to connect is closed on the server', () async {
      open();
      engine.failConnect = true;
      await media().join();
      expect(state().phase, MediaPhase.failed);
      expect(engine.rooms.single.disconnected, isTrue);
      await pumpEventQueue();
      expect(api.calls, ['join', 'leave']);
    });

    test('mute and camera: the room first, then the record', () async {
      open();
      await media().join(camera: true);
      await media().setMicrophone(enabled: false);
      expect(engine.rooms.single.microphone, isFalse);
      expect(state().microphone, isFalse);
      expect(api.states.last, (false, null));
      await media().setCamera(enabled: false);
      expect(state().camera, isFalse);
      expect(api.states.last, (null, false));
      // A failed record keeps what the room does and says so.
      api.stateError = const ApiException(
        kind: ApiFailureKind.conflict,
        message: 'Not connected',
        statusCode: 409,
      );
      await media().setMicrophone(enabled: true);
      expect(state().microphone, isTrue);
      expect(state().error, isA<ApiException>());
      // A failing device leaves the setting unchanged.
      engine.rooms.single.failToggle = true;
      await media().setCamera(enabled: true);
      expect(state().camera, isFalse);
    });

    test('reconnecting and a dropped room', () async {
      open();
      await media().join();
      final room = engine.rooms.single..emit(const MediaReconnecting());
      await pumpEventQueue();
      expect(state().phase, MediaPhase.reconnecting);
      room.emit(const MediaReconnected());
      await pumpEventQueue();
      expect(state().phase, MediaPhase.connected);
      room.emit(const MediaDisconnected());
      await pumpEventQueue();
      expect(state().phase, MediaPhase.ended);
      expect(room.disconnected, isTrue, reason: 'tracks released');
      expect(api.calls.last, 'leave');
    });

    test('leave releases the room even when the server fails', () async {
      open();
      await media().join();
      api.leaveError = const ApiException(
        kind: ApiFailureKind.network,
        message: 'offline',
      );
      await media().leave();
      expect(engine.rooms.single.disconnected, isTrue);
      expect(state().phase, MediaPhase.ended);
      expect(state().error, isA<ApiException>());
      await media().leave();
      expect(api.calls.where((x) => x == 'leave'), hasLength(1));
    });

    test('a room that fails to close still tells the server', () async {
      open();
      await media().join();
      engine.rooms.single.failDisconnect = true;
      await media().leave();
      expect(api.calls.last, 'leave');
      expect(state().phase, MediaPhase.ended);
    });

    test('closing the screen or switching company releases media', () async {
      final sub = open();
      await media().join();
      final room = engine.rooms.single;
      sub.close();
      await pumpEventQueue();
      expect(room.disconnected, isTrue);
      expect(api.calls.last, 'leave');

      open();
      await media().join();
      final second = engine.rooms.last;
      (c.read(sessionControllerProvider.notifier) as _Session).switchCompany(4);
      await pumpEventQueue();
      expect(second.disconnected, isTrue);
      expect(state().phase, MediaPhase.idle);
    });
  });
}

class _Session extends SessionController {
  @override
  Future<Session?> build() async => const Session(
    token: 't',
    tokenType: 'Bearer',
    userId: 1,
    companyId: 3,
    portal: Portal.client,
  );

  void switchCompany(int id) => state = AsyncData(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 1,
      companyId: id,
      portal: Portal.client,
    ),
  );
}

class _Api implements MeetingMediaApi {
  final calls = <String>[];
  final states = <(bool?, bool?)>[];
  MediaJoinOutcome? next;
  ApiException? error;
  ApiException? stateError;
  ApiException? leaveError;
  Completer<void>? gate;

  @override
  Future<MediaJoinOutcome> join(int meetingId, String deviceId) async {
    calls.add('join');
    await gate?.future;
    if (error case final e?) throw e;
    return next ??
        const MediaGranted(
          participantId: 55,
          credentials: MediaCredentials(
            token: _secret,
            url: 'wss://media.example.test',
            room: 'room-uuid',
          ),
        );
  }

  @override
  Future<void> state(int meetingId, {bool? microphone, bool? camera}) async {
    calls.add('state');
    states.add((microphone, camera));
    if (stateError case final e?) throw e;
  }

  @override
  Future<void> leave(int meetingId, String deviceId) async {
    calls.add('leave');
    if (leaveError case final e?) throw e;
  }
}
