import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/app/router.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

class WorkFlowApp extends ConsumerStatefulWidget {
  const new({this.locale, super.key});

  /// Forces a locale (tests, previews); null follows the device.
  final Locale? locale;

  @override
  ConsumerState<WorkFlowApp> createState() => _WorkFlowAppState();
}

class _WorkFlowAppState extends ConsumerState<WorkFlowApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final isMock = ref.watch(appConfigProvider).isMock;
    // A session the server ended (401) says so on the sign-in screens.
    ref.listen(sessionExpiryProvider, (_, _) {
      final messenger = _messenger.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('session-expired'),
            content: Text(
              AppLocalizations.of(messenger.context).errorSessionExpired,
            ),
          ),
        );
    });
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: !isMock,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      locale: widget.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      // Dark status-bar icons by default. The dark meeting room declares
      // light ones for itself; without this default its light style stayed
      // after leaving, leaving white icons on the light screens.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: isMock
            ? Banner(
                message: 'DEMO',
                location: BannerLocation.topEnd,
                child: Semantics(
                  label: AppLocalizations.of(context).demoModeBanner,
                  child: child,
                ),
              )
            : child!,
      ),
    );
  }
}
