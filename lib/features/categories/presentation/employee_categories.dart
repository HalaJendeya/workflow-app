import 'package:flutter/material.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/widgets/design_pending_screen.dart';
import 'package:workflow_app/features/categories/presentation/categories_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/timesheets_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Employee "More" tab: Figma Categories (729:46349).
class EmployeeCategoriesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              onOpen: (c) => push(
                c,
                const DesignPendingScreen(routeName: 'employee/dashboard'),
              ),
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
        CreateAction(l10n.addTask, openTaskForm),
        CreateAction(l10n.scheduleMeeting, openScheduleMeeting),
        CreateAction(l10n.joinByCodeTitle, openJoinByCode),
      ],
    );
  }
}
