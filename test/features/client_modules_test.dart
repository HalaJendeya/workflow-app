import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Demo-mode flows for the client module screens built from Figma.
void main() {
  Future<void> pumpClient(
    WidgetTester tester, {
    AppMode mode = AppMode.mock,
  }) async {
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
            AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
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

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> openMeetings(WidgetTester tester) async {
    await tab(tester, 'More');
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-Meetings')),
      200,
      scrollable: page(),
    );
    // Lift the row clear of the floating navigation surface.
    await tester.drag(page(), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-Meetings')));
    await tester.pumpAndSettle();
  }

  testWidgets('More opens Categories and filters sections', (tester) async {
    await pumpClient(tester);
    await tab(tester, 'More');
    expect(find.text('Categories'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('cat-pill-Finance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cat-pill-Finance')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-Payments')),
      200,
      scrollable: page(),
    );
    expect(find.byKey(const Key('category-Payments')), findsOneWidget);
    expect(find.byKey(const Key('category-Dashboard')), findsNothing);
  });

  testWidgets('Categories → Payments → search narrows records', (tester) async {
    await pumpClient(tester);
    await tab(tester, 'More');
    await tester.ensureVisible(find.byKey(const Key('cat-pill-Finance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cat-pill-Finance')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-Payments')),
      200,
      scrollable: page(),
    );
    await tester.tap(find.byKey(const Key('category-Payments')));
    await tester.pumpAndSettle();
    expect(find.text('Payment Records'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('payments-search')),
      200,
      scrollable: page(),
    );
    await tester.enterText(
      find.byKey(const Key('payments-search')),
      'PAY-78945',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment-pay-1')), findsOneWidget);
    expect(find.byKey(const Key('payment-pay-3')), findsNothing);
  });

  testWidgets('Companies join request switches the card to Pending', (
    tester,
  ) async {
    await pumpClient(tester);
    await tab(tester, 'Companies');
    expect(find.text('Available Companies'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-c2')));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsNWidgets(2));
  });

  testWidgets('Invoices: status pill filters and create form validates', (
    tester,
  ) async {
    await pumpClient(tester);
    await tab(tester, 'Invoices');
    expect(find.text('Invoices Management'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Overdue 1'),
      200,
      scrollable: page(),
    );
    await tester.tap(find.text('Overdue 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-inv-1')),
      200,
      scrollable: page(),
    );
    expect(find.byKey(const Key('invoice-inv-2')), findsNothing);

    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Create Invoice'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('form-save')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsWidgets);
  });

  testWidgets('Invoices: delete asks for confirmation and removes locally', (
    tester,
  ) async {
    await pumpClient(tester);
    await tab(tester, 'Invoices');
    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-inv-2')),
      300,
      scrollable: page(),
    );
    await tester.drag(page(), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('invoice-inv-2')),
        matching: find.byTooltip('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-inv-2')), findsNothing);
  });

  testWidgets('Chat: open a conversation and send a message', (tester) async {
    await pumpClient(tester);
    await tab(tester, 'Chat');
    await tester.tap(find.byKey(const Key('conversation-cv1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
    expect(find.text('Yousef'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Ship it today',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Ship it today'), findsOneWidget);
  });

  testWidgets('API mode shows the backend notice instead of demo data', (
    tester,
  ) async {
    await pumpClient(tester, mode: AppMode.api);
    await tab(tester, 'Companies');
    expect(
      find.textContaining('ready for the new WorkFlow API'),
      findsOneWidget,
    );
    expect(find.text('Gaza'), findsNothing);
  });

  testWidgets('Meetings: details, join by code, room chat, vote and leave', (
    tester,
  ) async {
    await pumpClient(tester);
    await openMeetings(tester);
    expect(find.text('Meetings Management'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('today-m1')),
      200,
      scrollable: page(),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('today-m1')),
        matching: find.text('View Details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ZUC-287-6LJ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Invitation required'),
      200,
      scrollable: page(),
    );
    expect(find.text('Invitation required'), findsOneWidget);
    await tester.fling(page(), const Offset(0, 3000), 4000);
    await tester.pumpAndSettle();

    await tester.tap(find.text('join by code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-code')), 'bhu-232-cek');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.text('BHU-232-CEK'), findsOneWidget);

    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('room-chat-input')), 'Hi all');
    await tester.tap(find.byKey(const Key('room-chat-send')));
    await tester.pump();
    expect(find.text('Hi all'), findsOneWidget);

    await tester.tap(find.text('Polls'));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('poll-Server response acceleration')),
    );
    await tester.pump();
    expect(find.text('Voted as: You'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-leave')));
    await tester.pumpAndSettle();
    expect(find.text('BHU-232-CEK'), findsNothing);
  });

  testWidgets('Meetings: Overdue tab shows the empty state for today', (
    tester,
  ) async {
    await pumpClient(tester);
    await openMeetings(tester);
    await tester.scrollUntilVisible(
      find.text('Overdue').first,
      200,
      scrollable: page(),
    );
    await tester.tap(find.text('Overdue').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No meetings on this day'),
      200,
      scrollable: page(),
    );
    expect(find.text('No meetings on this day'), findsOneWidget);
  });
}
