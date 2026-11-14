import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// LiveKit connection details from `POST …/meetings/{id}/media/join`
/// (`data.media {token, url, room}`). The token is a credential: it is
/// handed to the media room and nowhere else — never stored in state,
/// printed or logged ([toString] hides it).
class MediaCredentials {
  const new({required this.token, required this.url, required this.room});

  final String token;
  final String url;
  final String room;

  @override
  String toString() => 'MediaCredentials(url: $url, room: $room, token: ***)';
}

/// What `media/join` led to.
sealed class MediaJoinOutcome {
  const new();
}

/// 200: on the roster, with the caller's participant row and credentials.
class MediaGranted extends MediaJoinOutcome {
  const new({required this.participantId, required this.credentials});

  final int participantId;
  final MediaCredentials credentials;

  @override
  String toString() => 'MediaGranted($participantId, $credentials)';
}

/// 202 `{join_request, media: null}`: an approval meeting; the host must
/// admit the caller first.
class MediaJoinRequested extends MediaJoinOutcome {
  const new();
}

/// `04 Media & LiveKit` (client and employee). Every call carries the
/// device id: the server keeps one LiveKit session per device.
class MeetingMediaApi {
  new(this._client, this._base);

  final ApiClient _client;

  /// `/api/v1/{role}`.
  final String _base;

  /// `POST …/media/join` `{device_id}`. Joins the meeting and returns the
  /// LiveKit token, URL and room. The URL must be a secure WebSocket or
  /// HTTPS address: anything else is refused before a connection is tried.
  Future<MediaJoinOutcome> join(int meetingId, String deviceId) async {
    final response = await _client.post(
      '$_base/meetings/$meetingId/media/join',
      body: {'device_id': deviceId},
    );
    if (response.statusCode == 202) {
      ApiEnvelope.unwrapData(response);
      return const MediaJoinRequested();
    }
    final data = ApiEnvelope.unwrapObject(response);
    final participant = data['participant'];
    if (participant is! Json) missingField('participant');
    final media = data['media'];
    if (media is! Json) missingField('media');
    String text(String key) {
      final v = media[key];
      return v is String && v.isNotEmpty ? v : missingField('media.$key');
    }

    final url = text('url');
    final scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'wss' && scheme != 'https') missingField('media.url (wss)');
    return MediaGranted(
      participantId: asInt(participant['id']) ?? missingField('participant.id'),
      credentials: MediaCredentials(
        token: text('token'),
        url: url,
        room: text('room'),
      ),
    );
  }

  /// `POST …/media/state`: records the caller's own microphone / camera
  /// flags (needs a connected participant; 409 otherwise).
  Future<void> state(int meetingId, {bool? microphone, bool? camera}) async {
    final data = ApiEnvelope.unwrapObject(
      await _client.post(
        '$_base/meetings/$meetingId/media/state',
        body: {'microphone_enabled': ?microphone, 'camera_enabled': ?camera},
      ),
    );
    final participant = data['participant'];
    if (participant is! Json || asInt(participant['id']) == null) {
      missingField('participant.id');
    }
  }

  /// `POST …/media/leave` `{device_id}`: closes this device's session only.
  Future<void> leave(int meetingId, String deviceId) async {
    ApiEnvelope.unwrapObject(
      await _client.post(
        '$_base/meetings/$meetingId/media/leave',
        body: {'device_id': deviceId},
      ),
    );
  }
}

/// The id this install sends as `device_id` (`^[A-Za-z0-9_-]{8,64}$`).
/// Kept in secure storage under its own key, apart from the session, so it
/// survives sign-out: the server can then close a session this device
/// left open.
abstract interface class DeviceIdStore {
  Future<String?> read();
  Future<void> write(String id);
}

class SecureDeviceIdStore implements DeviceIdStore {
  new([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'wf.device.media_id';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String id) => _storage.write(key: _key, value: id);
}

class MemoryDeviceIdStore implements DeviceIdStore {
  String? _id;

  @override
  Future<String?> read() async => _id;

  @override
  Future<void> write(String id) async => _id = id;
}

final _validDeviceId = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

/// The stored id, or a new random one (32 characters from a secure
/// random source) written back first.
Future<String> deviceIdFrom(DeviceIdStore store, [Random? random]) async {
  final stored = await store.read();
  if (stored != null && _validDeviceId.hasMatch(stored)) return stored;
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
  final r = random ?? Random.secure();
  final id = String.fromCharCodes([
    for (var i = 0; i < 32; i++) chars.codeUnitAt(r.nextInt(chars.length)),
  ]);
  await store.write(id);
  return id;
}

final deviceIdStoreProvider = Provider<DeviceIdStore>(
  (_) => SecureDeviceIdStore(),
);

final mediaDeviceIdProvider = FutureProvider<String>(
  (ref) => deviceIdFrom(ref.watch(deviceIdStoreProvider)),
);
