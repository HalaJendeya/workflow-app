import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/viewport.dart';

const List<double> _scales = [1.0, 1.3];

Future<void> _pumpMock(
  WidgetTester tester,
  Portal portal,
  Size size,
  double scale,
) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 10,
      portal: portal,
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

double _height(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

/// Scrolls the first scrollable until [target] is built, shown, and clear
/// of the bottom 130 px (where the shell's navigation floats).
Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final h = _height(tester);
  final r = tester.getRect(target);
  if (r.bottom > h - 130) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, h - 130 - r.bottom),
    );
    await tester.pumpAndSettle();
  }
}

/// Scrolls the first scrollable back to its start.
Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openCategory(WidgetTester tester, String label) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(Key('category-$label')));
}

/// Focuses [field], raises a keyboard covering 42 % of the screen and
/// checks the field (and [alsoVisible], if given) stay above it.
Future<void> _withKeyboard(
  WidgetTester tester,
  Finder field, {
  Finder? alsoVisible,
}) async {
  await _reveal(tester, field);
  await tester.tap(field);
  showKeyboard(tester, _height(tester) * 0.42);
  await tester.pumpAndSettle();
  final limit = _height(tester) * 0.58 + 1;
  expect(tester.getRect(field).bottom, lessThanOrEqualTo(limit));
  if (alsoVisible != null) {
    expect(tester.getRect(alsoVisible).bottom, lessThanOrEqualTo(limit));
  }
}

void _hideKeyboard(WidgetTester tester) {
  tester.view.resetViewInsets();
  FocusManager.instance.primaryFocus?.unfocus();
}

/// Fails if [text] is drawn cut off (ellipsized or faded) anywhere.
void _expectWhole(WidgetTester tester, String text) {
  for (final e in find.text(text).evaluate()) {
    final p = e.renderObject;
    if (p is RenderParagraph) {
      expect(p.didExceedMaxLines, isFalse, reason: '"$text" is cut off');
    }
  }
}

void main() {
  for (final MapEntry(key: name, value: size) in phoneViewports.entries) {
    for (final scale in _scales) {
      final tag = '${name}_x$scale';
      group('$name text x$scale', () {
        testWidgets('new conversation form', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await tester.tap(find.text('Chat').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('create-fab')));
          await tester.pumpAndSettle();
          await screenshot(tester, 'new_conversation_$tag');

          // Empty group: the name is required and nothing is created.
          await _tap(tester, find.byKey(const Key('create-conversation')));
          await _toTop(tester);
          await _reveal(tester, find.byKey(const Key('group-name')));
          expect(find.text('This field is required'), findsOneWidget);
          await _withKeyboard(tester, find.byKey(const Key('group-name')));
          await screenshot(tester, 'new_conversation_keyboard_$tag');
          _hideKeyboard(tester);
          await tester.pumpAndSettle();

          // Two people picked for a group, then switch to a direct chat:
          // only one person may stay selected.
          final people = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('participant-'),
          );
          await _tap(tester, people.at(0));
          await _tap(tester, people.at(1));
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 3000),
          );
          await tester.pumpAndSettle();
          await _tap(
            tester,
            find.byWidgetPredicate((w) => w is DropdownButtonFormField).first,
          );
          await tester.tap(find.text('Direct').last);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('group-name')), findsNothing);
          await _tap(tester, find.byKey(const Key('create-conversation')));
          // A direct chat opens with the remaining person.
          expect(find.byKey(const Key('chat-input')), findsOneWidget);
        });

        testWidgets('chat composer, attachments and info sheet', (
          tester,
        ) async {
          await _pumpMock(tester, Portal.employee, size, scale);
          await tester.tap(find.text('Chat').last);
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(const Key('conversation-cv1')));
          await _withKeyboard(
            tester,
            find.byKey(const Key('chat-input')),
            alsoVisible: find.byKey(const Key('chat-send')),
          );
          await tester.enterText(
            find.byKey(const Key('chat-input')),
            'Status update for the sprint review',
          );
          await tester.tap(find.byKey(const Key('chat-send')));
          await tester.pumpAndSettle();
          expect(
            find.text('Status update for the sprint review'),
            findsOneWidget,
          );
          await screenshot(tester, 'chat_keyboard_$tag');
          _expectWhole(tester, 'Yousef');
          _hideKeyboard(tester);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('chat-attach')));
          await tester.pump();
          expect(find.textContaining('demo has no server'), findsOneWidget);
          await tester.pumpAndSettle(const Duration(seconds: 5));

          await tester.tap(find.byTooltip('Conversation info'));
          await tester.pumpAndSettle();
          await screenshot(tester, 'chat_info_$tag');
          expect(find.text('Participants').last.hitTestable(), findsOneWidget);
        });

        testWidgets('schedule meeting form', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await _openCategory(tester, 'Meetings');
          await tester.tap(find.byKey(const Key('create-fab')));
          await tester.pumpAndSettle();
          await screenshot(tester, 'schedule_meeting_$tag');
          await _tap(tester, find.byKey(const Key('meeting-save')));
          await _toTop(tester);
          await _reveal(tester, find.byKey(const Key('meeting-title')));
          expect(find.text('This field is required'), findsWidgets);
          await _withKeyboard(tester, find.byKey(const Key('meeting-title')));
          _hideKeyboard(tester);
          await tester.pumpAndSettle();
          // The time zone shown is the device's, not a fixed one.
          expect(find.textContaining('Riyadh'), findsNothing);
          await _toTop(tester);
          await _tap(tester, find.byKey(const Key('masthead-back')));
          expect(find.byKey(const Key('meeting-save')), findsNothing);
        });

        testWidgets('join by code and the meeting room panels', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await _openCategory(tester, 'Meetings');
          await _tap(tester, find.text('join by code').first);
          await _tap(tester, find.byKey(const Key('form-save')));
          expect(find.text('This field is required'), findsWidgets);
          await tester.enterText(
            find.byKey(const Key('join-code')),
            'bhu-232-cek',
          );
          await _tap(tester, find.byKey(const Key('form-save')));
          expect(find.byKey(const Key('room-leave')), findsOneWidget);
          await screenshot(tester, 'room_$tag');
          for (final panel in ['Chat', 'Polls', 'Notes']) {
            await tester.tap(find.text(panel).first);
            await tester.pumpAndSettle();
            await screenshot(tester, 'room_${panel}_$tag');
          }
          await tester.tap(find.text('Chat').first);
          await tester.pumpAndSettle();
          await _withKeyboard(
            tester,
            find.byKey(const Key('room-chat-input')),
            alsoVisible: find.byKey(const Key('room-chat-send')),
          );
          _hideKeyboard(tester);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('room-leave')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('room-leave')), findsNothing);
        });

        testWidgets('profile: account menu, password and delete account', (
          tester,
        ) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await tester.tap(find.byKey(const Key('account-menu')).first);
          await tester.pumpAndSettle();
          await screenshot(tester, 'account_menu_$tag');
          expect(find.byKey(const Key('logout')).hitTestable(), findsOneWidget);
          await tester.tap(find.byKey(const Key('account-profile')));
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(const Key('pw-save')));
          expect(find.text('This field is required'), findsWidgets);
          await screenshot(tester, 'password_errors_$tag');
          await _withKeyboard(tester, find.byKey(const Key('pw-confirm')));
          _hideKeyboard(tester);
          await tester.pumpAndSettle();

          await _tap(tester, find.byKey(const Key('confirm-deletion')));
          await _tap(tester, find.byKey(const Key('delete-account')));
          await screenshot(tester, 'delete_account_dialog_$tag');
          expect(find.text('Delete your account?'), findsOneWidget);
          await tester.tap(find.text('Cancel').last);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('pw-save')), findsOneWidget);
        });

        testWidgets('companies grid and join request', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await tester.tap(find.text('Companies').last);
          await tester.pumpAndSettle();
          await screenshot(tester, 'companies_$tag');
          for (final t in [
            'Companies',
            'Invoices',
            'Join Request',
            'Tech Company',
            'Pending',
          ]) {
            _expectWhole(tester, t);
          }
          final join = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('join-'),
          );
          await _tap(tester, join.first);
          expect(find.textContaining('request'), findsWidgets);
        });

        testWidgets('notification options sheet', (tester) async {
          await _pumpMock(tester, Portal.employee, size, scale);
          await tester.tap(find.byTooltip('Show').first);
          await tester.pumpAndSettle();
          await screenshot(tester, 'notification_options_$tag');
          // The sheet's action is above the floating navigation surface.
          expect(find.text('Mark all as read').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Unread').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Mark all as read'));
          await tester.pumpAndSettle();
        });
      });
    }
  }
}
