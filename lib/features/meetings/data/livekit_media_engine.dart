import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';

/// [MediaEngine] over the LiveKit Flutter SDK and `permission_handler`.
///
/// Logging: the SDK logs through `package:logging`, whose records go
/// nowhere unless a listener is attached — and this app attaches none, so
/// connection details and tokens never reach a log. (The SDK's
/// `disableLogging()` cannot be used: it throws unless hierarchical logging
/// is enabled app-wide.)
class LiveKitMediaEngine implements MediaEngine {
  const new();

  @override
  Future<({MediaPermission microphone, MediaPermission? camera})>
  requestPermissions({required bool camera}) async {
    // The browser asks when a track starts; there is nothing to ask first.
    if (kIsWeb) {
      return (
        microphone: MediaPermission.granted,
        camera: camera ? MediaPermission.granted : null,
      );
    }
    final mic = await Permission.microphone.request();
    final cam = camera ? await Permission.camera.request() : null;
    return (
      microphone: mapPermission(mic),
      camera: cam == null ? null : mapPermission(cam),
    );
  }

  /// The platform status as the session logic needs it: limited counts as
  /// granted; restricted (parental controls, policy) like a permanent
  /// refusal, since the app cannot ask again.
  @visibleForTesting
  static MediaPermission mapPermission(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return MediaPermission.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return MediaPermission.permanentlyDenied;
    }
    return MediaPermission.denied;
  }

  @override
  MediaRoom createRoom() => LiveKitMediaRoom();

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

/// One LiveKit room. Everything it holds (listener, local tracks, peer
/// connections) is released by [disconnect].
class LiveKitMediaRoom implements MediaRoom {
  new([lk.Room? room])
    : _room =
          room ??
          lk.Room(
            roomOptions: const lk.RoomOptions(
              adaptiveStream: true,
              dynacast: true,
            ),
          );

  final lk.Room _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final _events = StreamController<MediaRoomEvent>.broadcast();
  bool _leaving = false;

  @override
  Stream<MediaRoomEvent> get events => _events.stream;

  void _emit(MediaRoomEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    required bool microphone,
    required bool camera,
  }) async {
    final listener = _room.createListener();
    _listener = listener;
    listener
      ..on<lk.RoomReconnectingEvent>((_) => _emit(const MediaReconnecting()))
      ..on<lk.RoomReconnectedEvent>((_) => _emit(const MediaReconnected()))
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (!_leaving) _emit(const MediaDisconnected());
      })
      ..on<lk.ParticipantConnectedEvent>((_) => _changed())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _changed())
      ..on<lk.TrackSubscribedEvent>((_) => _changed())
      ..on<lk.TrackUnsubscribedEvent>((_) => _changed())
      ..on<lk.TrackMutedEvent>((_) => _changed())
      ..on<lk.TrackUnmutedEvent>((_) => _changed())
      ..on<lk.LocalTrackPublishedEvent>((_) => _changed())
      ..on<lk.LocalTrackUnpublishedEvent>((_) => _changed())
      ..on<lk.ActiveSpeakersChangedEvent>((_) => _changed());
    await _room.connect(url, token);
    final local = _room.localParticipant;
    await local?.setMicrophoneEnabled(microphone);
    if (camera) await local?.setCameraEnabled(true);
    _changed();
  }

  void _changed() => _emit(const MediaParticipantsChanged());

  @override
  Future<void> setMicrophone({required bool enabled}) async {
    final local = _room.localParticipant;
    if (local == null) throw StateError('Not connected');
    await local.setMicrophoneEnabled(enabled);
    _changed();
  }

  @override
  Future<void> setCamera({required bool enabled}) async {
    final local = _room.localParticipant;
    if (local == null) throw StateError('Not connected');
    await local.setCameraEnabled(enabled);
    _changed();
  }

  @override
  Future<void> disconnect() async {
    if (_leaving) return;
    _leaving = true;
    await _listener?.dispose();
    _listener = null;
    try {
      // Unpublishes and stops the local camera and microphone tracks. A
      // room that never connected has nothing to close: LiveKit would wait
      // 10 s for a server goodbye and then throw.
      if (_room.connectionState != lk.ConnectionState.disconnected) {
        await _room.disconnect();
      }
    } on Object {
      // Disposal below still frees the tracks and peer connections.
    } finally {
      await _room.dispose();
      await _events.close();
    }
  }

  @override
  List<MediaParticipant> get participants => [
    if (_room.localParticipant case final me?) _view(me, isLocal: true),
    for (final p in _room.remoteParticipants.values) _view(p, isLocal: false),
  ];

  static MediaParticipant _view(lk.Participant p, {required bool isLocal}) =>
      MediaParticipant(
        id: p.sid,
        name: p.name.isNotEmpty ? p.name : p.identity,
        isLocal: isLocal,
        microphone: p.isMicrophoneEnabled(),
        camera: p.isCameraEnabled(),
        speaking: p.isSpeaking,
      );

  lk.Participant? _find(String participantId) {
    final me = _room.localParticipant;
    if (me != null && me.sid == participantId) return me;
    return _room.remoteParticipants.values
        .where((r) => r.sid == participantId)
        .firstOrNull;
  }

  @override
  Widget? videoOf(String participantId) {
    final p = _find(participantId);
    if (p == null) return null;
    for (final pub in p.videoTrackPublications) {
      final track = pub.track;
      if (pub.source == lk.TrackSource.camera &&
          !pub.muted &&
          track is lk.VideoTrack) {
        return lk.VideoTrackRenderer(
          track,
          key: ValueKey('video-${p.sid}-${track.sid}'),
          fit: lk.VideoViewFit.cover,
        );
      }
    }
    return null;
  }
}
