import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// `GET /api/v1/client/dashboard` → `data {projectsCount, projectsCompleted,
/// projectsInProgress}`. The collection documents no fields for this route;
/// these three keys were read from the live server (work.isradev.shop) and
/// are the only ones it returns.
class ClientDashboardSummary {
  const new({
    required this.projects,
    required this.completed,
    required this.inProgress,
  });

  factory fromJson(Json j) => ClientDashboardSummary(
    projects: asInt(j['projectsCount']) ?? missingField('projectsCount'),
    completed:
        asInt(j['projectsCompleted']) ?? missingField('projectsCompleted'),
    inProgress:
        asInt(j['projectsInProgress']) ?? missingField('projectsInProgress'),
  );

  final int projects;
  final int completed;
  final int inProgress;
}

class ClientDashboardRepository {
  new(this._client);

  final ApiClient _client;

  Future<ClientDashboardSummary> summary() async =>
      ClientDashboardSummary.fromJson(
        ApiEnvelope.unwrapObject(await _client.get('/api/v1/client/dashboard')),
      );
}

final clientDashboardRepositoryProvider = Provider<ClientDashboardRepository>(
  (ref) => ClientDashboardRepository(ref.watch(apiClientProvider)),
);

final FutureProvider<ClientDashboardSummary> clientDashboardSummaryProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(clientDashboardRepositoryProvider).summary(),
    );
