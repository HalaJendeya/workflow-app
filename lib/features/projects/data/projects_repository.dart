import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Project status as the server reports it. `stats` names exactly
/// `pending`, `in_progress` and `completed` (confirmed live on
/// `client/projects`); anything else is kept as [other].
enum ApiProjectStatus { pending, inProgress, completed, other }

ApiProjectStatus _status(Object? v) => switch (v) {
  'pending' => ApiProjectStatus.pending,
  'in_progress' => ApiProjectStatus.inProgress,
  'completed' => ApiProjectStatus.completed,
  _ => ApiProjectStatus.other,
};

/// A project row of `GET /api/v1/{client|employee}/projects`.
///
/// Only fields the collection names for list rows are read: `id`, `title`
/// (sort key, CSV column and options payload), `status`, `budget` (absent
/// for the employee role), `currency {code, symbol}` and
/// `completion_percentage` (0..100). On the live server an employee row
/// also carries `company {id, name}`, `leader {id, name}` and `members[]`,
/// and has no `budget` (checked 2026-11-05).
class ProjectRecord {
  const new({
    required this.id,
    required this.title,
    required this.status,
    this.budget,
    this.currencyCode,
    this.currencySymbol,
    this.completion,
    this.companyName,
    this.leaderName,
    this.memberCount,
  });

  factory fromJson(Json j) {
    final currency = j['currency'];
    final company = j['company'];
    final leader = j['leader'];
    final members = j['members'];
    return ProjectRecord(
      id: asInt(j['id']) ?? missingField('id'),
      title: j['title'] is String
          ? j['title'] as String
          : missingField('title'),
      status: _status(j['status']),
      budget: asDouble(j['budget']),
      currencyCode: currency is Json ? currency['code'] as String? : null,
      currencySymbol: currency is Json ? currency['symbol'] as String? : null,
      completion: asInt(j['completion_percentage']),
      companyName: company is Json ? company['name'] as String? : null,
      leaderName: leader is Json ? leader['name'] as String? : null,
      memberCount: members is List ? members.length : null,
    );
  }

  final int id;
  final String title;
  final ApiProjectStatus status;
  final double? budget;
  final String? currencyCode;
  final String? currencySymbol;
  final int? completion;
  final String? companyName;
  final String? leaderName;
  final int? memberCount;
}

/// `stats {total, pending, in_progress, completed}`; ignores the status
/// filter.
typedef ProjectStats = ({int total, int pending, int inProgress, int done});

class ProjectList {
  const new({required this.page, required this.stats});

  final ApiPage<ProjectRecord> page;
  final ProjectStats stats;
}

typedef ProjectQuery = ({String search, ApiProjectStatus? status, int page});

/// Read-only: neither the client nor the employee role has project create,
/// update or delete routes in the collection.
class ProjectsRepository {
  new(this._client, Portal portal) : _path = '/api/v1/${portal.name}/projects';

  final ApiClient _client;
  final String _path;

  Future<ProjectList> list(ProjectQuery q) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        _path,
        query: {
          'page': q.page,
          'per_page': 10,
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          if (q.status case final s? when s != ApiProjectStatus.other)
            'status': switch (s) {
              ApiProjectStatus.inProgress => 'in_progress',
              _ => s.name,
            },
        },
      ),
    );
    // `stats {total, pending, in_progress, completed}` is documented; a
    // missing count is an invalid response, never a silent 0.
    final s = body['stats'];
    if (s is! Json) missingField('stats');
    int n(String k) => asInt(s[k]) ?? missingField('stats.$k');
    return ProjectList(
      page: ApiPage.parse(body['data'] as Json, ProjectRecord.fromJson),
      stats: (
        total: n('total'),
        pending: n('pending'),
        inProgress: n('in_progress'),
        done: n('completed'),
      ),
    );
  }

  /// `GET /api/v1/{client|employee}/projects/{id}`. The collection's test
  /// requires `data.id`; the project is `data` itself (live, 2026-11-14).
  /// The same row fields as the list are read. A project the caller may
  /// not see answers 403 or 404.
  Future<ProjectRecord> show(int id) async => ProjectRecord.fromJson(
    ApiEnvelope.unwrapObject(await _client.get('$_path/$id')),
  );
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  final portal =
      ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
  return ProjectsRepository(ref.watch(apiClientProvider), portal);
});

final FutureProviderFamily<ProjectList, ProjectQuery> apiProjectsProvider =
    FutureProvider.autoDispose.family<ProjectList, ProjectQuery>((ref, q) {
      // Keyed to the signed-in user: another account never sees this page.
      ref.watch(sessionControllerProvider.select((s) => s.value?.userId));
      return ref.watch(projectsRepositoryProvider).list(q);
    });

/// One project, fetched fresh when its details open; keyed to the
/// signed-in user like the list.
final FutureProviderFamily<ProjectRecord, int> apiProjectProvider =
    FutureProvider.autoDispose.family<ProjectRecord, int>((ref, id) {
      // Keyed to the account and its company: a project is never shown
      // under another account or company.
      ref.watch(
        sessionControllerProvider.select(
          (s) => (s.value?.userId, s.value?.companyId),
        ),
      );
      return ref.watch(projectsRepositoryProvider).show(id);
    });
