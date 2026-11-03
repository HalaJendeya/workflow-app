import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/categories/presentation/client_categories.dart';
import 'package:workflow_app/features/categories/presentation/employee_categories.dart';
import 'package:workflow_app/features/companies/presentation/companies_screen.dart';
import 'package:workflow_app/features/conversations/presentation/conversations_screens.dart';
import 'package:workflow_app/features/dashboard/presentation/client_dashboard_screen.dart';
import 'package:workflow_app/features/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:workflow_app/features/finance/presentation/invoices_screen.dart';
import 'package:workflow_app/features/finance/presentation/payments_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/profile/presentation/profile_screen.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/features/work/presentation/sprint_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/timesheets_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Renders the module screens in Arabic (RTL) at phone width and scrolls
/// through them; any overflow or build error fails the test.
void main() {
  for (final (name, screen) in [
    ('client dashboard', const ClientDashboardScreen()),
    ('employee dashboard', const EmployeeDashboardScreen()),
    ('profile', const ProfileScreen()),
    ('client categories', const ClientCategoriesScreen()),
    ('employee categories', const EmployeeCategoriesScreen()),
    ('companies', const CompaniesScreen()),
    ('invoices', const InvoicesScreen()),
    ('payments', const PaymentsScreen()),
    ('projects', const ProjectsScreen()),
    ('conversations', const ConversationsScreen()),
    ('meetings', const MeetingsScreen()),
    ('tasks', const TasksScreen()),
    ('sprint', const SprintScreen()),
    ('timesheets', const TimesheetsScreen()),
  ]) {
    testWidgets('$name lays out in Arabic', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 780) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
            ),
            sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byWidget(screen))),
        TextDirection.rtl,
      );
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      // Overflow and build errors fail the test through FlutterError.
    });
  }
}
