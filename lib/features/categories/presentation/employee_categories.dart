import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/features/categories/presentation/categories_screen.dart';
import 'package:workflow_app/features/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/reports/presentation/employee_report_screen.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/timesheets_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Employee "More" tab: Figma Categories (729:46349).
class EmployeeCategoriesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // "Add task" only where it can be saved: the demo, or a project leader
    // (the API accepts new tasks only on projects the user leads).
    final demo = ref.watch(demoModeProvider);
    final canAddTask = demo || ref.watch(ledProjectIdsProvider).isNotEmpty;
    void push(BuildContext c, Widget page) =>
        Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
    return CategoriesScreen(
      sections: [
        CategorySection(
          title: l10n.catOverview,
          subtitle: l10n.catOverviewBody,
          icon: 'cat_sec_overview',
          pillIcon: 'cat_pill_overview',
          items: [
            CategoryItem(
              label: l10n.catDashboard,
              icon: 'cat_item_dashboard',
              onOpen: (c) => push(c, const EmployeeDashboardScreen()),
            ),
            // The employee's own report (`GET /employee/report`); the
            // Overview card is "dashboards & reports" in Figma (729:46743).
            if (!demo)
              CategoryItem(
                label: l10n.myReport,
                icon: 'cat_item_report',
                onOpen: (c) => push(c, const EmployeeReportScreen()),
              ),
          ],
        ),
        CategorySection(
          title: l10n.catWork,
          subtitle: l10n.catWorkBody,
          icon: 'cat_sec_work',
          pillIcon: 'cat_sec_work',
          items: [
            CategoryItem(
              label: l10n.navProjects,
              icon: 'cat_item_projects',
              onOpen: (c) => goTab(c, Routes.employeeProjects),
            ),
            CategoryItem(
              label: l10n.navTasks,
              icon: 'nav_tasks',
              onOpen: (c) => push(c, const TasksScreen()),
            ),
            CategoryItem(
              label: l10n.navSprints,
              icon: 'nav_sprints',
              onOpen: (c) => goTab(c, Routes.employeeSprints),
            ),
            CategoryItem(
              label: l10n.timesheetsShort,
              icon: 'metric_ts_2',
              onOpen: (c) => push(c, const TimesheetsScreen()),
            ),
          ],
        ),
        CategorySection(
          title: l10n.catCommunication,
          subtitle: l10n.catCommunicationBody,
          icon: 'cat_sec_communication',
          pillIcon: 'cat_sec_communication',
          items: [
            CategoryItem(
              label: l10n.catConversations,
              icon: 'cat_item_conversations',
              onOpen: (c) => goTab(c, Routes.employeeChat),
            ),
            CategoryItem(
              label: l10n.catMeetings,
              icon: 'cat_item_meetings',
              onOpen: (c) => push(c, const MeetingsScreen()),
            ),
          ],
        ),
      ],
      createActions: [
        if (canAddTask) CreateAction(l10n.addTask, openTaskForm),
        // U2: in API mode an employee has no meeting create route, so
        // Schedule stays demo-only. Join by code uses the employee's
        // by-code lookup.
        if (demo) CreateAction(l10n.scheduleMeeting, openScheduleMeeting),
        CreateAction(l10n.joinByCodeTitle, openJoinByCode),
      ],
    );
  }
}
