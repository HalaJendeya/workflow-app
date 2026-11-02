// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WorkFlow';

  @override
  String get portalClient => 'Client';

  @override
  String get portalEmployee => 'Employee';

  @override
  String get designPendingTitle => 'Design pending';

  @override
  String get designPendingBody =>
      'This screen will be built from the official Figma design once access to the file is granted.';

  @override
  String get demoModeBanner => 'Demo data — nothing is saved to the server';

  @override
  String get retry => 'Retry';

  @override
  String get emptyState => 'Nothing here yet';

  @override
  String get errorNetwork => 'Can\'t reach the server. Check your connection.';

  @override
  String get errorSessionExpired =>
      'Your session has ended. Please sign in again.';

  @override
  String get errorForbidden => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'This item no longer exists.';

  @override
  String get errorValidation => 'Please check the highlighted fields.';

  @override
  String errorRateLimited(int seconds) {
    return 'Too many attempts. Try again in $seconds seconds.';
  }

  @override
  String get errorServer =>
      'Something went wrong on our side. Please try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';
}
