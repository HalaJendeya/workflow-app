import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Signed-in user's profile. `GET /api/v1/{client|employee}/account`
/// documents `data.id` and `data.email`; `data.name` and `data.image_url`
/// are documented on the profile update response, so they stay optional.
class UserProfile {
  const new({required this.id, required this.email, this.name, this.imageUrl});

  factory fromJson(Json json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! int || email is! String) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Profile is missing data.id or data.email.',
      );
    }
    return UserProfile(
      id: id,
      email: email,
      name: json['name'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  final int id;
  final String email;
  final String? name;
  final String? imageUrl;

  /// First name for greetings, falling back to the email's local part.
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n.split(RegExp(r'\s+')).first;
    return email.split('@').first;
  }

  String get initials {
    final source = (name?.trim().isNotEmpty ?? false) ? name!.trim() : email;
    final parts = source.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }
}

abstract interface class ProfileRepository {
  Future<UserProfile> fetch();
}

class ApiProfileRepository implements ProfileRepository {
  new(this._client, Portal portal) : _path = '/api/v1/${portal.name}/account';

  final ApiClient _client;
  final String _path;

  @override
  Future<UserProfile> fetch() async =>
      UserProfile.fromJson(ApiEnvelope.unwrapObject(await _client.get(_path)));
}

class MockProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> fetch() async =>
      const UserProfile(id: 1, email: 'demo@workflow.app', name: 'Demo User');
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (ref.watch(appConfigProvider).isMock) return MockProfileRepository();
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) throw StateError('Profile requires a session.');
  return ApiProfileRepository(ref.watch(apiClientProvider), session.portal);
});

final profileProvider = FutureProvider<UserProfile>(
  (ref) => ref.watch(profileRepositoryProvider).fetch(),
);
