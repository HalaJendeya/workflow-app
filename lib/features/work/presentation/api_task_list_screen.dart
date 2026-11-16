import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Opens the tasks of one sprint or project (`GET /employee/tasks` with
/// the documented `sprint_id` / `project_id` filter) above the shell.
Future<void> openApiTaskList(
  BuildContext context, {
  required String title,
  required TaskQuery query,
  String? subtitle,
  String? emptyText,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => ApiTaskListScreen(
      title: title,
      subtitle: subtitle,
      query: query,
      emptyText: emptyText,
    ),
  ),
);

/// A paged list of task summary cards (title, short description, status),
/// each opening Task Details. Rows are what the server lets this account
/// see (`tasks.view`); nothing is filtered or added on the device.
///
/// Sprint tasks come from the task list rather than
/// `GET /employee/sprints/{id}`, whose task rows still carry `cost` for
/// employees (backend blocker S1): the app does not request that route.
class ApiTaskListScreen extends ConsumerStatefulWidget {
  const new({
    required this.title,
    required this.query,
    this.subtitle,
    this.emptyText,
    super.key,
  });

  final String title;
  final String? subtitle;
  final TaskQuery query;
  final String? emptyText;

  @override
  ConsumerState<ApiTaskListScreen> createState() => _ApiTaskListScreenState();
}

class _ApiTaskListScreenState extends ConsumerState<ApiTaskListScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final b = widget.query;
    final query = TaskQuery(
      scope: b.scope,
      search: b.search,
      status: b.status,
      priority: b.priority,
      projectId: b.projectId,
      sprintId: b.sprintId,
      sort: b.sort,
      perPage: b.perPage,
      page: _page,
    );
    final value = ref.watch(apiTasksProvider(query));
    return Scaffold(
      key: const Key('api-task-list'),
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(apiTasksProvider(query));
            try {
              await ref.read(apiTasksProvider(query).future);
            } on Object {
              // The list shows its own error and retry.
            }
          },
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('api-task-list-back'),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const BackButtonIcon(),
                    color: AppColors.textPrimary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.mobileLgSemiBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.subtitle case final s?)
                          Text(
                            s,
                            style: AppTextStyles.mobileXsRegular.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                child: AsyncSection(
                  value: value,
                  onRetry: () => ref.invalidate(apiTasksProvider(query)),
                  builder: (list) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (list.page.items.isEmpty)
                        EmptyNotice(text: widget.emptyText ?? l10n.noRecords),
                      for (final t in list.page.items) ...[
                        TaskCard(
                          key: Key('api-task-${t.id}'),
                          title: t.title,
                          description: t.description,
                          status: StatusBadge(
                            label: apiTaskStatusLabel(l10n, t.status),
                            tone: apiTaskStatusTone(t.status),
                          ),
                          onOpen: () => openApiTaskDetails(context, t),
                        ),
                        const SizedBox(height: 12),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
