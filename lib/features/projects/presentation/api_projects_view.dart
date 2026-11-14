import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String apiProjectStatusLabel(AppLocalizations l10n, ApiProjectStatus s) =>
    switch (s) {
      ApiProjectStatus.pending => l10n.statusPending,
      ApiProjectStatus.inProgress => l10n.statusInProgress,
      ApiProjectStatus.completed => l10n.statusCompleted,
      ApiProjectStatus.other => '—',
    };

BadgeTone apiProjectTone(ApiProjectStatus s) => switch (s) {
  ApiProjectStatus.pending => BadgeTone.neutral,
  ApiProjectStatus.inProgress => BadgeTone.warning,
  ApiProjectStatus.completed => BadgeTone.success,
  ApiProjectStatus.other => BadgeTone.neutral,
};

/// "Projects Management" (643:34237 / 729:21226) backed by
/// `GET /api/v1/{client|employee}/projects`. Read-only for both roles.
class ApiProjectsView extends ConsumerStatefulWidget {
  const new({required this.onCreate, this.initialStatus, super.key});

  /// Kept so the Figma "Add Project" action stays; it reports that nothing
  /// can be saved because neither role has a project create route.
  final VoidCallback? onCreate;

  /// Status filter to start with.
  final ApiProjectStatus? initialStatus;

  @override
  ConsumerState<ApiProjectsView> createState() => _ApiProjectsViewState();
}

class _ApiProjectsViewState extends ConsumerState<ApiProjectsView> {
  String _search = '';
  late ApiProjectStatus? _status = widget.initialStatus;
  int _page = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _search = v;
          _page = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = (search: _search, status: _status, page: _page);
    final result = ref.watch(apiProjectsProvider(query));
    final stats = result.value?.stats;
    String n(int Function(ProjectStats) pick) =>
        stats == null ? '—' : count(pick(stats));

    return ModulePage(
      title: l10n.projectsTitle,
      description: l10n.projectsDescription,
      onSearch: _onSearch,
      onCreate: widget.onCreate,
      createLabel: l10n.addProject,
      children: [
        MetricCard(
          title: l10n.metricTotalProjects,
          value: n((s) => s.total),
          delta: '—',
        ),
        MetricCard(
          title: l10n.statusInProgress,
          value: n((s) => s.inProgress),
          delta: '—',
        ),
        MetricCard(
          title: l10n.statusCompleted,
          value: n((s) => s.done),
          delta: '—',
        ),
        WfSearchBox(
          fieldKey: const Key('projects-search'),
          hint: l10n.searchProjectsHint,
          onChanged: _onSearch,
        ),
        ChipRow(
          children: [
            DropdownChip<ApiProjectStatus?>(
              value: _status,
              options: const [
                null,
                ApiProjectStatus.pending,
                ApiProjectStatus.inProgress,
                ApiProjectStatus.completed,
              ],
              labelOf: (s) => s == null
                  ? l10n.filterAllStatus
                  : apiProjectStatusLabel(l10n, s),
              onChanged: (s) => setState(() {
                _status = s;
                _page = 1;
              }),
            ),
          ],
        ),
        AsyncSection(
          value: result,
          onRetry: () => ref.invalidate(apiProjectsProvider(query)),
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.page.items.isEmpty) EmptyNotice(text: l10n.noRecords),
              for (final p in list.page.items) ...[
                ApiProjectCard(project: p),
                const SizedBox(height: 16),
              ],
              if (list.page.lastPage > 1)
                Pager(
                  page: list.page.currentPage - 1,
                  pageSize: list.page.perPage,
                  total: list.page.total,
                  onPage: (p) => setState(() => _page = p + 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One API project: title, status, budget (client only) and completion.
class ApiProjectCard extends StatelessWidget {
  const new({required this.project, super.key});

  final ProjectRecord project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = project;
    final fields = projectFields(l10n, p);
    final status = apiProjectStatusLabel(l10n, p.status);
    final tone = apiProjectTone(p.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordCard(
          key: Key('api-project-${p.id}'),
          reference: '#${p.id}',
          title: p.title,
          status: status,
          tone: tone,
          fields: fields,
          onView: () => showApiProjectDetails(context, p),
        ),
        if (p.completion != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: p.completion!.clamp(0, 100) / 100,
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: ModuleColors.sectionDivider,
              ),
            ),
          ),
      ],
    );
  }
}

/// The label/value rows a project shows, from documented fields only.
List<DetailField> projectFields(AppLocalizations l10n, ProjectRecord p) {
  final budget = p.budget == null
      ? null
      : money(
          p.budget!,
          currency: p.currencyCode ?? '',
          symbol: p.currencySymbol ?? '',
        );
  return [
    if (p.companyName != null) DetailField(l10n.fieldCompany, p.companyName!),
    if (p.leaderName != null) DetailField(l10n.projectLeader, p.leaderName!),
    if (p.memberCount != null) DetailField(l10n.fieldTeam, '${p.memberCount}'),
    if (budget != null) DetailField(l10n.fieldBudget, budget),
    if (p.completion != null)
      DetailField(l10n.fieldProgress, '${p.completion}%'),
  ];
}

/// Project details from `GET /{role}/projects/{id}`. The list row is shown
/// at once with a loading bar, then replaced by the server's current
/// record; a failure (403/404 for a project the account may not see, or
/// a network error) is shown with Retry instead of stale data.
Future<void> showApiProjectDetails(BuildContext context, ProjectRecord row) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _ProjectDetailsSheet(row: row),
    );

class _ProjectDetailsSheet extends ConsumerWidget {
  const new({required this.row});

  final ProjectRecord row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiProjectProvider(row.id));
    final shown = value.value ?? row;
    return RecordDetailsBody(
      key: const Key('project-details'),
      title: shown.title,
      status: apiProjectStatusLabel(l10n, shown.status),
      tone: apiProjectTone(shown.status),
      fields: value.hasError ? const [] : projectFields(l10n, shown),
      footer: switch (value) {
        AsyncError(:final error) => ApiErrorCard(
          error: error,
          onRetry: () => ref.invalidate(apiProjectProvider(row.id)),
        ),
        AsyncData() => null,
        _ => const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(key: Key('project-details-loading')),
        ),
      },
    );
  }
}
