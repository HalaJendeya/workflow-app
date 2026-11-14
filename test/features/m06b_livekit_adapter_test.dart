import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/data/livekit_media_engine.dart';

/// The LiveKit adapter without a media server: permission mapping and the
/// lifecycle of a room that never connected. Connecting needs WebRTC and a
/// LiveKit server, which the test VM has neither of (Redmi 8 steps cover
/// it).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creating the engine has no side effects (it used to throw)', () {
    expect(() => const LiveKitMediaEngine(), returnsNormally);
  });

  test('permission statuses map to what the session needs', () {
    MediaPermission m(PermissionStatus s) =>
        LiveKitMediaEngine.mapPermission(s);
    expect(m(PermissionStatus.granted), MediaPermission.granted);
    expect(m(PermissionStatus.limited), MediaPermission.granted);
    expect(m(PermissionStatus.denied), MediaPermission.denied);
    expect(
      m(PermissionStatus.permanentlyDenied),
      MediaPermission.permanentlyDenied,
    );
    expect(m(PermissionStatus.restricted), MediaPermission.permanentlyDenied);
    expect(m(PermissionStatus.provisional), MediaPermission.denied);
  });

  test('a room that never connected lists no one and disposes once', () async {
    final room = LiveKitMediaRoom();
    expect(room.participants, isEmpty);
    expect(room.videoOf('anyone'), isNull);
    await expectLater(room.setMicrophone(enabled: true), throwsStateError);
    final done = expectLater(room.events, emitsDone);
    await room.disconnect();
    await room.disconnect(); // a second Leave is harmless
    await done;
  });
}
