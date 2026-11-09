import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/notifications/data/mock_notifications_repository.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';
import 'conversations_api_test.dart' as conv;

/// Routes by path; POSTs to [gatedPath] wait for [gate].
class _Server implements HttpClientAdapter {
  new(this.routes);

  final Map<String, (int, Object?)> routes;
  final List<RequestOptions> requests = [];
  Completer<void>? gate;
  String? gatedPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    if (o.method == 'POST' && o.uri.path == gatedPath) await gate?.future;
    final (status, body) =
        routes['${o.method} ${o.uri.path}'] ?? (404, failure('Not found'));
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Demo inbox whose "mark all as read" is refused by the server.
class _RefusingInbox extends MockNotificationsRepository {
  @override
  Future<int> markAllRead() async => throw const ApiException(
    kind: ApiFailureKind.forbidden,
    message: 'This action is unauthorized.',
  );
}

Future<void> _pump(
  WidgetTester tester,
  Portal portal, {
  AppMode mode = AppMode.mock,
  _Server? server,
  List<Override> overrides = const [],
}) async {
  useViewport(tester, const Size(360, 740));
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 7,
      companyId: 3,
      portal: portal,
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
        if (server != null)
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'https://api.test',
              credentials: ref.watch(sessionCredentialsProvider),
              adapter: server,
            ),
          ),
        ...overrides,
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [target] into view and clear of the bottom 130 px, where the
/// shell's navigation floats, so a tap reaches it.
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
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final r = tester.getRect(target);
  if (r.bottom > h - 130) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, h - 130 - r.bottom),
    );
    await tester.pumpAndSettle();
  }
}

Map<String, (int, Object?)> _employeeChatRoutes() => {
  'GET /api/v1/employee/account': (200, ok({'id': 7, 'name': 'Me'})),
  'GET /api/v1/employee/conversations': (200, ok([conv.conversationRow()])),
  'GET /api/v1/employee/conversations/1': (
    200,
    ok({'conversation': conv.conversationRow(messages: const [])}),
  ),
  'POST /api/v1/employee/conversations/1/read': (200, ok(null)),
  'POST /api/v1/employee/conversations/1/messages': (200, ok(null)),
};

void main() {
  testWidgets('sending shows a spinner and a second tap sends nothing', (
    tester,
  ) async {
    final server = _Server(_employeeChatRoutes())
      ..gatedPath = '/api/v1/employee/conversations/1/messages'
      ..gate = Completer<void>();
    await _pump(tester, Portal.employee, mode: AppMode.api, server: server);
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-input')), 'hello');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(find.byKey(const Key('chat-sending')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    server.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      server.requests.where(
        (r) => r.method == 'POST' && r.uri.path.endsWith('/messages'),
      ),
      hasLength(1),
    );
    expect(find.byKey(const Key('chat-sending')), findsNothing);
  });

  testWidgets('API mode: New conversation does not open a demo form', (
    tester,
  ) async {
    await _pump(
      tester,
      Portal.employee,
      mode: AppMode.api,
      server: _Server(_employeeChatRoutes()),
    );
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-conversation')), findsNothing);
    expect(find.textContaining('only works in demo mode'), findsOneWidget);
  });

  testWidgets('API mode: Schedule meeting from the More menu is refused', (
    tester,
  ) async {
    await _pump(
      tester,
      Portal.client,
      mode: AppMode.api,
      server: _Server({
        'GET /api/v1/client/account': (200, ok({'id': 7, 'name': 'Me'})),
      }),
    );
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule meeting').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meeting-save')), findsNothing);
    expect(find.textContaining('no create route'), findsOneWidget);
  });

  testWidgets('employees see why they cannot delete their account', (
    tester,
  ) async {
    await _pump(tester, Portal.employee);
    await tester.tap(find.byKey(const Key('account-menu')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('employee-delete-unavailable')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('delete-account')), findsNothing);
    expect(find.byKey(const Key('confirm-deletion')), findsNothing);
  });

  testWidgets('client account deletion asks with account wording', (
    tester,
  ) async {
    await _pump(tester, Portal.client);
    await tester.tap(find.byKey(const Key('account-menu')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-profile')));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirm-deletion'));
    await _reveal(tester, confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const Key('delete-account')));
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('permanently deleted'), findsOneWidget);
    expect(find.textContaining('from this device'), findsNothing);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-account')), findsOneWidget);
  });

  testWidgets('a refused "mark all as read" shows the real reason', (
    tester,
  ) async {
    await _pump(
      tester,
      Portal.employee,
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(_RefusingInbox()),
      ],
    );
    await tester.tap(find.byTooltip('Show').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text("You don't have access to this."), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });

  testWidgets('a meeting time that has passed is refused', (tester) async {
    final today = DateTime.now();
    if (today.day == 1) return; // No earlier day in this month's grid.
    await _pump(tester, Portal.client);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    final meetings = find.byKey(const Key('category-Meetings'));
    await _reveal(tester, meetings);
    await tester.tap(meetings);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    final yesterday = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('${today.day - 1}'),
    );
    await _reveal(tester, yesterday);
    await tester.tap(yesterday);
    await tester.pumpAndSettle();
    final title = find.byKey(const Key('meeting-title'));
    await _reveal(tester, title);
    await tester.enterText(title, 'Retro');
    final save = find.byKey(const Key('meeting-save'));
    await _reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meeting-when-error')), findsOneWidget);
    expect(find.byKey(const Key('meeting-save')), findsOneWidget);
  });
}
