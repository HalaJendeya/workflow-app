import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';

/// A company of `GET /api/v1/client/companies` ("List My Companies").
///
/// The collection documents only that the response has `data`. The fields
/// read here are the company model as the live server returns it elsewhere
/// (`data.company` of `GET /{role}/account`, 2026-11-14): `id` and `name`
/// are required, `domain` and `email` optional. The membership status of the
/// `client_company` row is **not** documented for this route, so it is not
/// read (docs/api-contract-gaps.md, C4).
class ClientCompany {
  const new({required this.id, required this.name, this.domain, this.email});

  factory fromJson(Json j) => ClientCompany(
    id: asInt(j['id']) ?? missingField('id'),
    name: j['name'] is String ? j['name'] as String : missingField('name'),
    domain: _text(j['domain']),
    email: _text(j['email']),
  );

  final int id;
  final String name;
  final String? domain;
  final String? email;

  /// What the card shows under the name: the domain, else the email.
  String? get subtitle => domain ?? email;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

/// Read-only. `POST /client/companies/{id}/join` exists, but the API has no
/// route that lists companies a client could join, so the app has no
/// company id to send it.
class ClientCompaniesRepository {
  new(this._client);

  final ApiClient _client;

  Future<List<ClientCompany>> list() async {
    final data = ApiEnvelope.unwrapData(
      await _client.get('/api/v1/client/companies'),
    );
    if (data is! List) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Expected a list of companies in data.',
      );
    }
    return [
      for (final row in data.whereType<Json>()) ClientCompany.fromJson(row),
    ];
  }
}

final clientCompaniesRepositoryProvider = Provider<ClientCompaniesRepository>(
  (ref) => ClientCompaniesRepository(ref.watch(apiClientProvider)),
);

/// Keyed to the signed-in user, so another account never sees this list.
final FutureProvider<List<ClientCompany>> clientCompaniesProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(sessionControllerProvider.select((s) => s.value?.userId));
      return ref.watch(clientCompaniesRepositoryProvider).list();
    });
