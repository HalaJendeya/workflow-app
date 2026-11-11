import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/viewport.dart';

/// Regressions for defects found driving the client app on a real Android
/// emulator (Pixel 9 Pro, API 36) in M01 batch 2 validation.
void main() {
  const statusBar = 48.0;

  Future<void> pumpClient(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 1400) * 3
      ..devicePixelRatio = 3
      // A real status bar: the defects only show with a top inset.
      ..padding = const FakeViewPadding(top: statusBar * 3);
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
            const AppConfig(mode: AppMode.mock, apiBaseUrl: 'https://api.test'),
          ),
          sessionStorageProvider.overrideWithValue(storage),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Finder page() => find
      .descendant(
        of: find.byType(CustomScrollView).last,
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> openRoom(WidgetTester tester) async {
    await tab(tester, 'More');
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-Meetings')),
      200,
      scrollable: page(),
    );
    await tester.drag(page(), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-Meetings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('join by code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-code')), 'BHU-232-CEK');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('chat: my bubbles carry my initials and send is labelled', (
    tester,
  ) async {
    await pumpClient(tester);
    await tab(tester, 'Chat');
    await tester.tap(find.byKey(const Key('conversation-cv1')));
    await tester.pumpAndSettle();

    // "You" started with Y, so my avatar read "Y", the same as Yousef's.
    final mine = tester.widget<Text>(
      find.byKey(const Key('chat-mine-avatar')).first,
    );
    expect(mine.data, 'DU');
    expect(find.byTooltip('Send message'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Text>(find.byKey(const Key('chat-mine-avatar')))
          .map((t) => t.data),
      everyElement('DU'),
    );
  });

  testWidgets('module pages keep content out from under the status bar', (
    tester,
  ) async {
    await pumpClient(tester);
    await tab(tester, 'Chat');
    final backdrop = find.byKey(const Key('status-bar-backdrop'));
    expect(backdrop, findsOneWidget);
    expect(tester.getRect(backdrop).top, 0);
    expect(tester.getSize(backdrop).height, statusBar);

    await tester.drag(page(), const Offset(0, -600));
    await tester.pumpAndSettle();
    // Still painted above the scrolled list.
    expect(tester.getSize(backdrop).height, statusBar);
    expect(
      find.byKey(const Key('status-bar-backdrop')).hitTestable(),
      findsNothing,
      reason: 'decorative only',
    );
  });

  testWidgets('overview: status-bar scrim appears only once scrolled', (
    tester,
  ) async {
    await pumpClient(tester);
    double opacity() => tester
        .widget<AnimatedOpacity>(find.byKey(const Key('status-bar-scrim')))
        .opacity;
    expect(opacity(), 0, reason: 'the sky masthead is untouched at rest');
    expect(
      tester.getSize(find.byKey(const Key('status-bar-scrim'))).height,
      statusBar,
    );

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(opacity(), 1);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });

  testWidgets('room: my tile, mic glyph and status-bar style', (tester) async {
    await pumpClient(tester);
    SystemUiOverlayStyle topStyle() => tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (w) => w is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .last
        .value;
    // App-wide default, so a screen without its own style is never left
    // with the room's light icons.
    expect(topStyle(), SystemUiOverlayStyle.dark);

    await openRoom(tester);
    expect(topStyle(), SystemUiOverlayStyle.light);

    // Was a fixed 'SA' and "You · You".
    expect(
      tester.widget<Text>(find.byKey(const Key('room-self-initials'))).data,
      'DU',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('room-self-name'))).data,
      'Demo User',
    );

    // Unmuted, the control showed the crossed (muted) mic.
    expect(find.byKey(const Key('room-mic-on')), findsNothing);
    await tester.tap(find.byTooltip('Unmute'));
    await tester.pump();
    expect(find.byKey(const Key('room-mic-on')), findsOneWidget);
    expect(find.byTooltip('Mute'), findsOneWidget);
    await tester.tap(find.byTooltip('Mute'));
    await tester.pump();
    expect(find.byKey(const Key('room-mic-on')), findsNothing);

    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byKey(const Key('room-chat-send')),
        matching: find.byTooltip('Send message'),
      ),
      findsOneWidget,
    );
    final input = tester.widget<TextField>(
      find.byKey(const Key('room-chat-input')),
    );
    expect(input.textInputAction, TextInputAction.send);

    await tester.tap(find.byKey(const Key('room-leave')));
    await tester.pumpAndSettle();
    expect(topStyle(), SystemUiOverlayStyle.dark);
  });

  testWidgets('room: media notice keeps page margins at 130 % text', (
    tester,
  ) async {
    // Real fonts: the square test font is far wider than Inter.
    await loadAppFonts();
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpClient(tester);
    await openRoom(tester);
    final notice = find.byKey(const Key('room-media-pending'));
    final rect = tester.getRect(notice);
    // It wrapped flush against both screen edges on a 427 dp phone.
    expect(rect.left, greaterThanOrEqualTo(20));
    expect(rect.right, lessThanOrEqualTo(390 - 20));
    expect(tester.widget<Text>(notice).textAlign, TextAlign.center);
  });
}
