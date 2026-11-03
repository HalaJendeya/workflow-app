import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/app/router.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

class WorkFlowApp extends ConsumerWidget {
  const new({this.locale, super.key});

  /// Forces a locale (tests, previews); null follows the device.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMock = ref.watch(appConfigProvider).isMock;
    return MaterialApp.router(
      debugShowCheckedModeBanner: !isMock,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => isMock
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
  }
}
