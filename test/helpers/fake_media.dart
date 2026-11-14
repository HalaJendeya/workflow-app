import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';

/// A media engine and room without WebRTC: permissions, connection and
/// tracks are plain fields the test sets and reads.
class FakeMediaEngine implements MediaEngine {
  MediaPermission microphone = MediaPermission.granted;
  MediaPermission camera = MediaPermission.granted;
  bool failConnect = false;
  final rooms = <FakeMediaRoom>[];

  @override
  Future<({MediaPermission microphone, MediaPermission? camera})>
  requestPermissions({required bool camera}) async =>
      (microphone: microphone, camera: camera ? this.camera : null);

  int settingsOpened = 0;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  MediaRoom createRoom() {
    final r = FakeMediaRoom(failConnect: failConnect);
    rooms.add(r);
    return r;
  }
}

class FakeMediaRoom implements MediaRoom {
  new({required this.failConnect});

  final bool failConnect;
  final _events = StreamController<MediaRoomEvent>.broadcast();
  (String, String)? connectedWith;
  bool microphone = false;
  bool camera = false;
  bool disconnected = false;
  bool failToggle = false;

  void emit(MediaRoomEvent e) => _events.add(e);

  @override
  Stream<MediaRoomEvent> get events => _events.stream;

  @override
  Future<void> connect(
    String url,
    String token, {
    required bool microphone,
    required bool camera,
  }) async {
    if (failConnect) throw StateError('could not connect');
    connectedWith = (url, token);
    this.microphone = microphone;
    this.camera = camera;
  }

  @override
  Future<void> setMicrophone({required bool enabled}) async {
    if (failToggle) throw StateError('device busy');
    microphone = enabled;
  }

  @override
  Future<void> setCamera({required bool enabled}) async {
    if (failToggle) throw StateError('device busy');
    camera = enabled;
  }

  bool failDisconnect = false;

  @override
  Future<void> disconnect() async {
    disconnected = true;
    if (failDisconnect) throw StateError('close failed');
  }

  /// Me plus [remote], as a LiveKit room would list them.
  List<MediaParticipant> remote = const [];

  @override
  List<MediaParticipant> get participants => [
    MediaParticipant(
      id: 'me',
      name: 'Me',
      isLocal: true,
      microphone: microphone,
      camera: camera,
    ),
    ...remote,
  ];

  @override
  Widget? videoOf(String participantId) => participantId == 'me' && camera
      ? const SizedBox(key: Key('my-video'))
      : null;
}
