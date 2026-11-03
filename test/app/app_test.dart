import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/app/router.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';

class _MockAuth extends Mock implements AuthRepository;

class _MockNotifications extends Mock implements NotificationsRepository;

class _FakeProfile implements ProfileRepository {
  @override
  Future<UserProfile> fetch() async =>
      const UserProfile(id: 7, email: 'taher@workflow.com', name: 'Taher Ali');
}

const _session = Session(
  token: 't',
  tokenType: 'Bearer',
  userId: 7,
  companyId: 25,
  portal: Portal.client,
);

final _inbox = NotificationInbox(
  items: [
    AppNotification(
      id: 'n1',
      isRead: false,
      title: 'New Task Assigned',
      message: 'You have been assigned to a new task',
      category: 'tasks',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'n2',
      isRead: true,
      title: 'Meeting Reminder',
      message: 'The meeting will start in 10 minutes.',
      category: 'meetings',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ],
  currentPage: 1,
  lastPage: 1,
  total: 2,
  unreadCount: 1,
);

final Finder _page = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  late _MockAuth auth;
  late _MockNotifications notifications;

  setUpAll(() {
    registerFallbackValue(Portal.client);
    registerFallbackValue(NotificationFilter.all);
  });

  setUp(() {
    auth = _MockAuth();
    notifications = _MockNotifications();
    when(
      () => notifications.list(
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => _inbox);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    AppMode mode = AppMode.api,
    Locale locale = const Locale('en'),
    SessionStorage? storage,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
          ),
          sessionStorageProvider.overrideWithValue(
            storage ?? InMemorySessionStorage(),
          ),
          if (mode == AppMode.api) ...[
            authRepositoryProvider.overrideWithValue(auth),
            notificationsRepositoryProvider.overrideWithValue(notifications),
            profileRepositoryProvider.overrideWithValue(_FakeProfile()),
          ],
        ],
        child: WorkFlowApp(locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('redirectFor', () {
    const employee = Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 1,
      portal: Portal.employee,
    );

    test('signed-out users may only open public auth routes', () {
      expect(
        redirectFor(session: const AsyncData(null), location: Routes.client),
        Routes.welcome,
      );
      expect(
        redirectFor(session: const AsyncData(null), location: Routes.login),
        isNull,
      );
    });

    test('each role is kept inside its own area', () {
      expect(
        redirectFor(
          session: const AsyncData(employee),
          location: Routes.client,
        ),
        Routes.employee,
      );
      expect(
        redirectFor(
          session: const AsyncData(employee),
          location: Routes.employeeTasks,
        ),
        isNull,
      );
    });

    test('splash while the session is restoring', () {
      expect(
        redirectFor(session: const AsyncLoading(), location: Routes.employee),
        Routes.splash,
      );
    });
  });

  group('auth flow', () {
    testWidgets('starts on Account Type with Employee preselected', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Account Type'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('portal-employee'))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('portal-client'))),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('employee login hides self-registration', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsWidgets);
      expect(find.text('Sign Up'), findsNothing);
    });

    testWidgets('client login offers Sign Up and validates input', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('portal-client')));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Sign Up'), findsOneWidget);

      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('This field is required'), findsNWidgets(2));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login-email')),
          matching: find.byType(TextFormField),
        ),
        'not-an-email',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      verifyNever(
        () => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          portal: any(named: 'portal'),
        ),
      );
    });

    testWidgets('server 403 message is shown and no session is created', (
      tester,
    ) async {
      when(
        () => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          portal: any(named: 'portal'),
        ),
      ).thenThrow(
        const ApiException(
          kind: ApiFailureKind.forbidden,
          message: 'Please verify your email address.',
        ),
      );
      await pumpApp(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login-email')),
          matching: find.byType(TextFormField),
        ),
        'a@b.co',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login-password')),
          matching: find.byType(TextFormField),
        ),
        'secret',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please verify your email address.'), findsOneWidget);
      expect(find.text('Account Type'), findsNothing);
      expect(find.text('Welcome back, Taher'), findsNothing);
    });

    testWidgets('successful client login opens the Overview', (tester) async {
      when(
        () => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          portal: any(named: 'portal'),
        ),
      ).thenAnswer((_) async => _session);
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('portal-client')));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login-email')),
          matching: find.byType(TextFormField),
        ),
        'taher@workflow.com',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login-password')),
          matching: find.byType(TextFormField),
        ),
        'secret',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Taher'), findsOneWidget);
      verify(
        () => auth.login(
          email: 'taher@workflow.com',
          password: 'secret',
          portal: Portal.client,
        ),
      ).called(1);
    });
  });

  group('client overview', () {
    Future<void> signedIn(WidgetTester tester) async {
      final storage = InMemorySessionStorage();
      await storage.writeAll(_session.toStorage());
      await pumpApp(tester, storage: storage);
    }

    testWidgets('shows API notifications with total and relative time', (
      tester,
    ) async {
      await signedIn(tester);
      expect(find.text('All 2'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Meeting Reminder'),
        200,
        scrollable: _page,
      );
      expect(find.text('New Task Assigned'), findsOneWidget);
      expect(find.text('a day ago'), findsOneWidget);
    });

    testWidgets('client tasks card states the API gap instead of data', (
      tester,
    ) async {
      await signedIn(tester);
      expect(find.textContaining('API doesn’t provide it'), findsOneWidget);
    });

    testWidgets('search filters notifications locally', (tester) async {
      await signedIn(tester);
      await tester.enterText(
        find.byKey(const Key('overview-search')),
        'meeting',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Meeting Reminder'),
        200,
        scrollable: _page,
      );
      expect(find.text('New Task Assigned'), findsNothing);
    });

    testWidgets('tapping an unread notification marks it read', (tester) async {
      when(() => notifications.markRead('n1')).thenAnswer(
        (_) async => const AppNotification(id: 'n1', isRead: true, title: 'x'),
      );
      await signedIn(tester);
      await tester.scrollUntilVisible(
        find.text('New Task Assigned'),
        200,
        scrollable: _page,
      );
      // Lift the card clear of the floating navigation surface.
      await tester.drag(_page, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Task Assigned'));
      await tester.pumpAndSettle();
      verify(() => notifications.markRead('n1')).called(1);
    });

    testWidgets('bottom navigation switches tabs and logs out', (tester) async {
      when(() => auth.logout()).thenAnswer((_) async {});
      await signedIn(tester);
      expect(find.text('Companies'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Categories'), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-menu')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      expect(find.text('Account Type'), findsOneWidget);
    });
  });

  testWidgets('Arabic renders right-to-left', (tester) async {
    await pumpApp(tester, locale: const Locale('ar'));
    expect(find.text('نوع الحساب'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('نوع الحساب')));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('mock mode is visibly marked as demo', (tester) async {
    await pumpApp(tester, mode: AppMode.mock);
    expect(
      find.byWidgetPredicate((w) => w is Banner && w.message == 'DEMO'),
      findsOneWidget,
    );
  });
}
