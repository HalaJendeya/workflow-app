import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_details_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'meetings_api_test.dart' as m;

/// Meeting Details after the Redmi 8 acceptance run: short facts share
/// rows (two columns on a phone, more on a tablet, one label-and-value line
/// each when only one column fits), timing is grouped, the description and
/// participants stay readable, and Join/Leave and invitations stay. Client
/// and Employee, English and Arabic, light and dark. Mocked HTTP.

Map<String, (int, Object?)> _routes(String portal) => {
  'GET /api/v1/$portal/account': (200, ok({'id': 10, 'name': 'Me'})),
  'GET /api/v1/$portal/meetings/41': (
    200,
    ok({
      ...m.meetingJson(
        type: 'scheduled',
        scheduledAt: '2026-10-22T08:30:00.000000Z',
        myInvitation: portal == 'employee'
            ? {'id': 2, 'status': 'pending'}
            : null,
      ),
      'description':
          'Plan the next sprint: review the backlog, agree on the goal and '
          'split the stories between the mobile and web teams.',
    }),
  ),
  'GET /api/v1/$portal/meetings/41/participants': (
    200,
    m.page([
      m.participantJson(1, 'Hana Host', 'host'),
      m.participantJson(2, 'Omar Abdel-Rahman Al-Khatib', 'participant'),
    ]),
  ),
  'GET /api/v1/$portal/meetings/41/invitations': (
    200,
    m.page([m.invitationJson(5, status: 'accepted')]),
  ),
  'GET /api/v1/$portal/meeting-invitations': (200, m.page(const [])),
};

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  String portal = 'employee',
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  AppColors.use(dark ? Brightness.dark : Brightness.light);
  addTearDown(() => AppColors.use(Brightness.light));
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 10,
      companyId: 3,
      portal: portal == 'employee' ? Portal.employee : Portal.client,
    ).toStorage(),
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
      ),
      sessionStorageProvider.overrideWithValue(storage),
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: 'https://api.test',
          credentials: ref.watch(sessionCredentialsProvider),
          adapter: RouteHttpAdapter(_routes(portal)),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ApiMeetingDetailsScreen(id: 41),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls through the whole page; any overflow fails the test.
Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 10; i++) {
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  test('columns follow the width and the text size, not a fixed count', () {
    // Card content width = viewport - 2 x 20 gutter - 2 x 16 padding.
    expect(DetailGrid.columnsFor(320 - 72, 132 * 1.3), 1);
    expect(DetailGrid.columnsFor(360 - 72, 132), 2);
    expect(DetailGrid.columnsFor(390 - 72, 132), 2);
    expect(DetailGrid.columnsFor(768 - 72, 132), 4);
    expect(DetailGrid.columnsFor(1200, 132), 4);
  });

  testWidgets('360x800: timing shares rows, two facts per row', (tester) async {
    await _pump(tester, size: const Size(360, 800));
    expect(find.byKey(const Key('meeting-facts')), findsOneWidget);
    // Scheduled and Duration side by side; Started and Ended under them.
    expect(_top(tester, 'Scheduled At'), _top(tester, 'Duration'));
    expect(_top(tester, 'Started At'), _top(tester, 'Ended At'));
    expect(
      tester.getTopLeft(find.text('Duration')).dx,
      greaterThan(tester.getTopLeft(find.text('Scheduled At')).dx),
    );
    expect(_top(tester, 'Type'), _top(tester, 'Privacy'));
    // Timing is formatted compactly, without seconds.
    expect(find.textContaining('2026/10/22'), findsWidgets);
    expect(find.textContaining(':00 AM'), findsNothing);
    // The description stays whole and full width.
    expect(find.textContaining('split the stories'), findsOneWidget);
    // Enabled features only, as badges; nothing that looks tappable. (The
    // Meeting records card below has its own "Chat" chip since F03.)
    final facts = find.byKey(const Key('meeting-facts'));
    expect(
      find.descendant(of: facts, matching: find.text('Chat')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: facts, matching: find.text('File sharing')),
      findsNothing,
    );
    await _scrollThrough(tester);
  });

  testWidgets('320x640 x1.3: one label-and-value line per fact', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 640), scale: 1.3);
    // One column: the label and its value share a line.
    final label = tester.getRect(find.text('Created By'));
    final value = tester.getRect(find.text('Hana Host').first);
    expect((label.top - value.top).abs(), lessThan(4));
    expect(value.left, greaterThan(label.left));
    await _scrollThrough(tester);
  });

  testWidgets('768x1024: more facts per row on a tablet', (tester) async {
    await _pump(tester, size: const Size(768, 1024));
    for (final t in ['Duration', 'Started At', 'Ended At']) {
      expect(_top(tester, t), _top(tester, 'Scheduled At'), reason: t);
    }
    await _scrollThrough(tester);
  });

  testWidgets('participants: one line each, refresh in the header', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844));
    await tester.ensureVisible(find.byKey(const Key('participants')));
    await tester.pumpAndSettle();
    expect(find.text('Hana Host'), findsWidgets);
    expect(find.textContaining('· User'), findsNothing);
    expect(find.byKey(const Key('participants-refresh')), findsOneWidget);
    expect(find.byTooltip('Refresh list'), findsOneWidget);
    // Join stays (live meeting); employee keeps the invitations card.
    expect(find.byKey(const Key('meeting-join')), findsOneWidget);
    expect(find.byKey(const Key('meeting-invitations')), findsOneWidget);
    expect(find.byKey(const Key('your-invitation')), findsOneWidget);
  });

  testWidgets('client: same layout, no employee-only invitations card', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844), portal: 'client');
    expect(find.byKey(const Key('meeting-facts')), findsOneWidget);
    expect(_top(tester, 'Scheduled At'), _top(tester, 'Duration'));
    expect(find.byKey(const Key('meeting-join')), findsOneWidget);
    expect(find.byKey(const Key('meeting-invitations')), findsNothing);
    await _scrollThrough(tester);
  });

  for (final (name, size, scale) in [
    ('320x640 x1.3', const Size(320, 640), 1.3),
    ('360x800', const Size(360, 800), 1.0),
    ('390x844', const Size(390, 844), 1.0),
    ('430x932', const Size(430, 932), 1.0),
  ]) {
    testWidgets('Arabic dark $name: RTL, no overflow', (tester) async {
      await _pump(
        tester,
        size: size,
        scale: scale,
        locale: const Locale('ar'),
        dark: true,
      );
      final grid = find.byKey(const Key('meeting-timing'));
      expect(Directionality.of(tester.element(grid)), TextDirection.rtl);
      await screenshot(tester, 'meeting_details_ar_dark_${name.split(' ')[0]}');
      await _scrollThrough(tester);
    });
  }

  for (final (name, size, scale) in [
    ('320x640_x1.3', const Size(320, 640), 1.3),
    ('360x800', const Size(360, 800), 1.0),
    ('390x844', const Size(390, 844), 1.0),
    ('768x1024', const Size(768, 1024), 1.0),
  ]) {
    testWidgets('screenshot en light $name', (tester) async {
      await _pump(tester, size: size, scale: scale);
      await screenshot(tester, 'meeting_details_en_$name');
      final card = tester.getSize(find.byKey(const Key('meeting-facts')));
      debugPrint('meeting-facts $name: ${card.height.round()} px high');
    });
  }

  testWidgets('demo details use the same facts card', (tester) async {
    useViewport(tester, const Size(360, 800));
    await loadAppFonts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => const MeetingDetailsScreen(id: 'm1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meeting-facts')), findsOneWidget);
    expect(_top(tester, 'Scheduled At'), _top(tester, 'Duration'));
    await _scrollThrough(tester);
    expect(find.byKey(const Key('invite-participant')), findsOneWidget);
  });
}
