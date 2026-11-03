import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Demo-mode flows for the client Dashboard (643:32669) and Profile
/// Details (643:33288).
void main() {
  Future<void> pumpClient(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 1,
        companyId: 1,
        portal: Portal.client,
      ).toStorage(),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
          ),
          sessionStorageProvider.overrideWithValue(storage),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder page() => find
      .descendant(
        of: find.byType(CustomScrollView).last,
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 250, scrollable: page());
    // Centre the target, clear of the floating navigation surface.
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.4);
    await tester.pumpAndSettle();
  }

  Future<void> openDashboard(WidgetTester tester) async {
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-Dashboard')));
    await tester.pumpAndSettle();
  }

  testWidgets('Dashboard: periods, series toggle, project delete', (
    tester,
  ) async {
    await pumpClient(tester);
    await openDashboard(tester);
    expect(find.text('Overview & Metrics'), findsOneWidget);
    expect(find.text('Monthly Revenue'), findsOneWidget);

    await tester.tap(find.byKey(const Key('period-month')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('series-settled')));
    expect(find.text(r'Oct Peak: $24,800'), findsOneWidget);
    await tester.tap(find.byKey(const Key('series-settled')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const Key('dash-delete-p1')));
    await tester.tap(find.byKey(const Key('dash-delete-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dash-project-p1')), findsNothing);
  });

  testWidgets('Dashboard View All jumps to the Invoices tab', (tester) async {
    await pumpClient(tester);
    await openDashboard(tester);
    await scrollTo(tester, find.byKey(const Key('view-all-invoices')));
    await tester.tap(find.byKey(const Key('view-all-invoices')));
    await tester.pumpAndSettle();
    expect(find.text('Invoices Management'), findsOneWidget);
  });

  testWidgets('Profile: rename, password validation and delete gate', (
    tester,
  ) async {
    await pumpClient(tester);
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Profile Details'), findsOneWidget);
    expect(find.text('Demo User'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-last')), 'Person');
    await scrollTo(tester, find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Profile updated'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Demo Person'),
      -250,
      scrollable: page(),
    );

    await scrollTo(tester, find.byKey(const Key('pw-save')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pw-new')),
        matching: find.byType(TextFormField),
      ),
      'short',
    );
    await tester.tap(find.byKey(const Key('pw-save')));
    await tester.pumpAndSettle();
    // Current is empty, "short" breaks the rule and the confirmation differs.
    expect(find.text('This field is required'), findsOneWidget);
    expect(find.textContaining('at least 8 characters'), findsNWidgets(2));
    expect(find.text("Passwords don't match"), findsOneWidget);

    await scrollTo(tester, find.byKey(const Key('delete-account')));
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-delete')), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-deletion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-delete')), findsOneWidget);
  });
}
