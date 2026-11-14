import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/meetings/data/meeting_media.dart';

/// Audio/video for a meeting, behind two small interfaces so the session
/// logic is independent of the media SDK:
///
/// - [MediaEngine] asks the platform for microphone/camera permission and
///   creates rooms;
/// - [MediaRoom] is one LiveKit connection.
///
/// **No engine is wired yet** ([mediaEngineProvider] is `null`): the LiveKit
/// SDK and a permission plugin are dependencies awaiting approval. Until
/// then the meeting screen keeps saying audio/video are not available, and
/// nothing here sends a request.
enum MediaPermission { granted, denied, permanentlyDenied }

abstract interface class MediaEngine {
  /// The microphone always; the camera only when [camera].
  Future<({MediaPermission microphone, MediaPermission? camera})>
  requestPermissions({required bool camera});

  MediaRoom createRoom();
}

sealed class MediaRoomEvent {
  const new();
}

/// The connection dropped and the SDK is reconnecting.
class MediaReconnecting extends MediaRoomEvent {
  const new();
}

class MediaReconnected extends MediaRoomEvent {
  const new();
}

/// The room ended without the person leaving (server, network, kicked).
class MediaDisconnected extends MediaRoomEvent {
  const new();
}

abstract interface class MediaRoom {
  Stream<MediaRoomEvent> get events;

  Future<void> connect(
    String url,
    String token, {
    required bool microphone,
    required bool camera,
  });

  Future<void> setMicrophone({required bool enabled});
  Future<void> setCamera({required bool enabled});

  /// Leaves the room and stops every local track (camera, microphone).
  Future<void> disconnect();
}

final mediaEngineProvider = Provider<MediaEngine?>((_) => null);

final meetingMediaApiProvider = Provider<MeetingMediaApi>((ref) {
  final portal =
      ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
  return MeetingMediaApi(
    ref.watch(apiClientProvider),
    '/api/v1/${portal.name}',
  );
});

enum MediaPhase {
  idle,
  requestingPermission,
  permissionDenied,
  joining,

  /// 202: waiting for the host to admit this person.
  waitingForHost,
  connecting,
  connected,
  reconnecting,
  leaving,

  /// Left, or the room ended.
  ended,
  failed,
}

class MediaSessionState {
  const new({
    this.phase = MediaPhase.idle,
    this.microphone = false,
    this.camera = false,
    this.error,
    this.permanentlyDenied = false,
  });

  final MediaPhase phase;
  final bool microphone;
  final bool camera;

  /// The last failure (the server's reason when it refused).
  final Object? error;

  /// Permission must be granted in the system settings.
  final bool permanentlyDenied;

  bool get inRoom =>
      phase == MediaPhase.connected || phase == MediaPhase.reconnecting;

  /// A join can start: not already joining, waiting or inside.
  bool get canJoin => switch (phase) {
    MediaPhase.idle ||
    MediaPhase.permissionDenied ||
    MediaPhase.waitingForHost ||
    MediaPhase.ended ||
    MediaPhase.failed => true,
    _ => false,
  };

  MediaSessionState copy({
    MediaPhase? phase,
    bool? microphone,
    bool? camera,
    Object? error,
    bool clearError = false,
    bool? permanentlyDenied,
  }) => MediaSessionState(
    phase: phase ?? this.phase,
    microphone: microphone ?? this.microphone,
    camera: camera ?? this.camera,
    error: clearError ? null : (error ?? this.error),
    permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
  );
}

/// One meeting's audio/video session for the signed-in account and
/// company. Rebuilt (and its room released) when either changes.
class MeetingMediaController extends Notifier<MediaSessionState> {
  new(this.meetingId);

  final int meetingId;

  MediaRoom? _room;
  StreamSubscription<MediaRoomEvent>? _events;
  String? _deviceId;

  @override
  MediaSessionState build() {
    ref
      ..watch(
        sessionControllerProvider.select(
          (s) => (s.value?.userId, s.value?.companyId),
        ),
      )
      ..onDispose(_release);
    return const MediaSessionState();
  }

  /// Leaving the screen, the account or the company frees the camera and
  /// microphone and tells the server this device left.
  void _release() {
    final room = _room;
    final device = _deviceId;
    unawaited(_events?.cancel());
    _events = null;
    _room = null;
    if (room == null) return;
    unawaited(room.disconnect());
    if (device != null) {
      // Captured before disposal: `ref` is not usable from here on.
      final api = _api;
      unawaited(api?.leave(meetingId, device).catchError((Object _) {}));
    }
  }

  MeetingMediaApi? _api;

  /// Permission, then `media/join`, then the LiveKit room. Ignored while a
  /// join is under way or the person is already inside.
  Future<void> join({bool camera = false}) async {
    if (!state.canJoin) return;
    final engine = ref.read(mediaEngineProvider);
    if (engine == null) return;
    state = state.copy(
      phase: MediaPhase.requestingPermission,
      clearError: true,
    );
    final granted = await engine.requestPermissions(camera: camera);
    if (!ref.mounted) return;
    if (granted.microphone != MediaPermission.granted) {
      state = MediaSessionState(
        phase: MediaPhase.permissionDenied,
        permanentlyDenied:
            granted.microphone == MediaPermission.permanentlyDenied,
      );
      return;
    }
    // A refused camera is not a refused meeting: join with audio only.
    final withCamera = camera && granted.camera == MediaPermission.granted;

    state = state.copy(phase: MediaPhase.joining);
    final MediaJoinOutcome outcome;
    try {
      _api = ref.read(meetingMediaApiProvider);
      _deviceId = await ref.read(mediaDeviceIdProvider.future);
      if (!ref.mounted) return;
      outcome = await _api!.join(meetingId, _deviceId!);
    } on ApiException catch (e) {
      if (ref.mounted) {
        state = MediaSessionState(phase: MediaPhase.failed, error: e);
      }
      return;
    }
    if (!ref.mounted) return;
    switch (outcome) {
      case MediaJoinRequested():
        state = const MediaSessionState(phase: MediaPhase.waitingForHost);
      case MediaGranted(:final credentials):
        await _connect(engine, credentials, withCamera);
    }
  }

  Future<void> _connect(
    MediaEngine engine,
    MediaCredentials credentials,
    bool camera,
  ) async {
    state = state.copy(phase: MediaPhase.connecting);
    final room = engine.createRoom();
    _room = room;
    _events = room.events.listen(_onEvent);
    try {
      // The token goes to the room only; it is not kept anywhere.
      await room.connect(
        credentials.url,
        credentials.token,
        microphone: true,
        camera: camera,
      );
    } on Object catch (e) {
      // The server already counts this device in: close it there too.
      _release();
      if (ref.mounted) {
        state = MediaSessionState(phase: MediaPhase.failed, error: e);
      }
      return;
    }
    if (!ref.mounted) return;
    state = MediaSessionState(
      phase: MediaPhase.connected,
      microphone: true,
      camera: camera,
    );
  }

  void _onEvent(MediaRoomEvent e) {
    if (!ref.mounted) return;
    switch (e) {
      case MediaReconnecting():
        if (state.inRoom) state = state.copy(phase: MediaPhase.reconnecting);
      case MediaReconnected():
        if (state.inRoom) state = state.copy(phase: MediaPhase.connected);
      case MediaDisconnected():
        if (!state.inRoom) return;
        _release();
        state = const MediaSessionState(phase: MediaPhase.ended);
    }
  }

  bool _toggling = false;

  /// The room first (it is what others hear), then the server's record.
  /// A room failure leaves the setting as it was; a failed record keeps
  /// the room's setting and reports the error.
  Future<void> setMicrophone({required bool enabled}) =>
      _toggle(microphone: enabled);

  Future<void> setCamera({required bool enabled}) => _toggle(camera: enabled);

  Future<void> _toggle({bool? microphone, bool? camera}) async {
    final room = _room;
    if (room == null || state.phase != MediaPhase.connected || _toggling) {
      return;
    }
    _toggling = true;
    try {
      if (microphone != null) await room.setMicrophone(enabled: microphone);
      if (camera != null) await room.setCamera(enabled: camera);
    } on Object catch (e) {
      _toggling = false;
      if (ref.mounted) state = state.copy(error: e);
      return;
    }
    if (!ref.mounted) return;
    state = state.copy(
      microphone: microphone,
      camera: camera,
      clearError: true,
    );
    try {
      await _api?.state(meetingId, microphone: microphone, camera: camera);
    } on ApiException catch (e) {
      if (ref.mounted) state = state.copy(error: e);
    } finally {
      _toggling = false;
    }
  }

  /// Leaves: the room (camera and microphone stop) even when the server
  /// cannot be told, then `media/leave` for this device.
  Future<void> leave() async {
    if (_room == null && !state.inRoom) return;
    if (state.phase == MediaPhase.leaving) return;
    state = state.copy(phase: MediaPhase.leaving);
    final room = _room;
    final device = _deviceId;
    unawaited(_events?.cancel());
    _events = null;
    _room = null;
    await room?.disconnect();
    Object? error;
    if (device != null) {
      try {
        await _api?.leave(meetingId, device);
      } on ApiException catch (e) {
        error = e;
      }
    }
    if (ref.mounted) {
      state = MediaSessionState(phase: MediaPhase.ended, error: error);
    }
  }
}

final NotifierProviderFamily<MeetingMediaController, MediaSessionState, int>
meetingMediaProvider = NotifierProvider.autoDispose
    .family<MeetingMediaController, MediaSessionState, int>(
      MeetingMediaController.new,
    );
