import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/app/router.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

class WorkFlowApp extends ConsumerStatefulWidget {
  const new({this.locale, super.key});

  /// Forces a locale (tests, previews); null follows the device.
  final Locale? locale;

  @override
  ConsumerState<WorkFlowApp> createState() => _WorkFlowAppState();
}

class _WorkFlowAppState extends ConsumerState<WorkFlowApp>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The palette is in place before the first frame: no flash of the
    // other theme.
    AppColors.use(_brightness(ref.read(preferencesProvider)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Brightness _brightness(AppPreferences prefs) => prefs.brightness(
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  /// The device switched light/dark (only matters while following it).
  @override
  void didChangePlatformBrightness() =>
      _applyPalette(ref.read(preferencesProvider));

  /// Switches the palette and rebuilds every widget once, keeping all
  /// state (forms, routes, scroll positions): widgets read [AppColors]
  /// directly, so a theme change alone would not reach them.
  void _applyPalette(AppPreferences prefs) {
    if (!AppColors.use(_brightness(prefs)) || !mounted) return;
    void mark(Element e) => e
      ..markNeedsBuild()
      ..visitChildren(mark);

    (context as Element).visitChildren(mark);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMock = ref.watch(appConfigProvider).isMock;
    final prefs = ref.watch(preferencesProvider);
    ref.listen(preferencesProvider, (_, next) => _applyPalette(next));
    final dark = AppColors.isDark;
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
      darkTheme: AppTheme.dark(),
      // The palette decides (it already follows the preference and the
      // device), so Material widgets and the app's own always agree.
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      // A chosen language wins; "System" follows the device, falling back
      // to English for languages the app does not have.
      locale: widget.locale ?? prefs.locale,
      localeListResolutionCallback: resolveLocale,
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
      builder: (context, child) {
        // Month names and AM/PM follow the app language (the date symbols
        // are loaded by the Material localizations delegate).
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
        );
      },
    );
  }
}
