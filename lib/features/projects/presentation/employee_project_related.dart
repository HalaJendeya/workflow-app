import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/api_task_form.dart';
import 'package:workflow_app/features/work/presentation/api_task_list_screen.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// How many of a project's tasks the details sheet shows before
/// "View all tasks".
const int projectTaskPreview = 3;

/// Opens the Sprint & Backlog board on [projectId] above the shell.
Future<void> openProjectBoard(BuildContext context, int projectId) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ApiSprintView(initialProjectId: projectId),
      ),
    );

/// The employee's view of what belongs to a project, under its details:
/// its sprints (`GET /employee/sprints/options?project_id=`), its latest
/// tasks (`GET /employee/tasks?project_id=`), the board, and — on a project
/// the user leads — Add task. Each part loads, fails and retries on its
/// own, so one failure never hides the rest.
class EmployeeProjectRelated extends ConsumerWidget {
  const new({required this.project, super.key});

  final ProjectRecord project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = project;
    final leads = ref.watch(ledProjectIdsProvider).contains(p.id);
    final sprints = ref.watch(sprintOptionsProvider(p.id));
    final taskQuery = TaskQuery(
      scope: TaskScope.team,
      projectId: p.id,
      perPage: projectTaskPreview,
    );
    final tasks = ref.watch(apiTasksProvider(taskQuery));
    final heading = AppTextStyles.mobileBaseSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      key: const Key('project-related'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leads) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(
              key: const Key('project-you-lead'),
              label: l10n.youLeadProject,
              tone: BadgeTone.info,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('project-open-board'),
              onPressed: () => openProjectBoard(context, p.id),
              icon: const Icon(Icons.view_kanban_outlined),
              label: Text(l10n.openBoard),
            ),
            if (leads)
              FilledButton.icon(
                key: const Key('project-add-task'),
                onPressed: () => openApiTaskForm(context, projectId: p.id),
                icon: const Icon(Icons.add),
                label: Text(l10n.addTask),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.projectSprints, style: heading),
        const SizedBox(height: 8),
        AsyncSection(
          value: sprints,
          onRetry: () => ref.invalidate(sprintOptionsProvider(p.id)),
          builder: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty) Text(l10n.noSprintsYet, style: secondary),
              for (final s in rows)
                ListTile(
                  key: Key('project-sprint-${s.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.name),
                  subtitle: s.status.isEmpty
                      ? null
                      : Text(sprintStatusLabel(l10n, s.status)),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () => openApiTaskList(
                    context,
                    title: s.name,
                    subtitle: p.title,
                    query: TaskQuery(
                      scope: TaskScope.team,
                      projectId: p.id,
                      sprintId: s.id,
                    ),
                    emptyText: l10n.sprintTasksEmpty,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.projectTasks, style: heading),
        const SizedBox(height: 8),
        AsyncSection(
          value: tasks,
          onRetry: () => ref.invalidate(apiTasksProvider(taskQuery)),
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.page.items.isEmpty)
                Text(l10n.noRecords, style: secondary),
              for (final t in list.page.items) ...[
                TaskCard(
                  key: Key('project-task-${t.id}'),
                  title: t.title,
                  description: t.description,
                  status: StatusBadge(
                    label: apiTaskStatusLabel(l10n, t.status),
                    tone: apiTaskStatusTone(t.status),
                  ),
                  onOpen: () => openApiTaskDetails(context, t),
                ),
                const SizedBox(height: 8),
              ],
              if (list.page.total > list.page.items.length)
                TextButton(
                  key: const Key('project-all-tasks'),
                  onPressed: () => openApiTaskList(
                    context,
                    title: p.title,
                    subtitle: l10n.projectTasks,
                    query: TaskQuery(scope: TaskScope.team, projectId: p.id),
                  ),
                  child: Text(l10n.viewAllTasks),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
