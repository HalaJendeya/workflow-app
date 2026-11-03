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

  @override
  String get accountTypeTitle => 'Account Type';

  @override
  String get accountTypeClientTitle => 'client';

  @override
  String get accountTypeClientBody =>
      'I am looking for companies to execute my projects';

  @override
  String get accountTypeEmployeeTitle => 'Employee';

  @override
  String get accountTypeEmployeeBody =>
      'I manage project and deal with clients';

  @override
  String get next => 'Next';

  @override
  String get noAccountPrompt => 'Don’t Have an Account?';

  @override
  String get createClientAccount => 'Create Client Account';

  @override
  String get loginWelcome => 'Welcome ';

  @override
  String get loginWelcomeAccent => 'back!';

  @override
  String get loginTitle => 'Login';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'example123@gmail.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPasswordLink => 'Forget password ?';

  @override
  String get loginButton => 'Login';

  @override
  String get signUpPrompt => 'Already not have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get registerTitleLead => 'Create an ';

  @override
  String get registerTitleAccent => 'account';

  @override
  String get registerSubtitle => 'Sign in';

  @override
  String get userNameLabel => 'User name';

  @override
  String get userNameHint => 'mahmoud ali';

  @override
  String get agreeTermsLead => 'I agree to the ';

  @override
  String get agreeTermsTerms => 'Terms';

  @override
  String get agreeTermsAnd => ' and ';

  @override
  String get agreeTermsConditions => 'Conditions';

  @override
  String get signInButton => 'Sign in';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get loginLink => 'login';

  @override
  String get forgotTitle => 'Forgot Password?';

  @override
  String get forgotBody =>
      'Enter your registered email and we’ll send you a code to reset your password.';

  @override
  String get sendCode => 'Send Code';

  @override
  String get backToLogin => 'Back to Log In';

  @override
  String get verifyTitle => 'Verification Code';

  @override
  String verifyBody(int length, String email) {
    return 'We’ve sent a $length-digit code to ($email)';
  }

  @override
  String get verifyButton => 'Verify';

  @override
  String get noCodePrompt => 'Didn’t receive the code?';

  @override
  String get resend => 'Resend';

  @override
  String get codeResent => 'A new code has been sent.';

  @override
  String get newPasswordTitle => 'Create New Password';

  @override
  String get newPasswordBody =>
      'Your new password must be different from previous used passwords.';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get save => 'Save';

  @override
  String get successAccountTitle => 'Account created successfully!';

  @override
  String get successAccountBody => 'You can now log in with your new password.';

  @override
  String get successPasswordTitle => 'Password updated successfully!';

  @override
  String get validationRequired => 'This field is required';

  @override
  String get validationEmail => 'Enter a valid email address';

  @override
  String validationPasswordMin(int min) {
    return 'Use at least $min characters';
  }

  @override
  String get validationPasswordMatch => 'Passwords don’t match';

  @override
  String get validationOtp => 'Enter the full code';

  @override
  String get validationTerms => 'Please accept the Terms and Conditions';

  @override
  String get navHome => 'Home';

  @override
  String get navCompanies => 'Companies';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navChat => 'Chat';

  @override
  String get navMore => 'More';

  @override
  String get overviewBreadcrumb => 'Overview';

  @override
  String welcomeBackName(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get searchHint => 'Searching....';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String tasksFilterProjects(int count) {
    return 'Projects $count';
  }

  @override
  String get tasksFilterMeetings => 'Meetings';

  @override
  String get tasksFilterGeneral => 'General';

  @override
  String get addMicroTask => 'Add a personal micro-task';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsFilterAll(int count) {
    return 'All $count';
  }

  @override
  String get notificationsFilterMentions => 'Mentions';

  @override
  String get notificationsFilterProjects => 'Projects';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get notificationStatusTitle => 'Show';

  @override
  String get filterAll => 'All';

  @override
  String get filterUnread => 'Unread';

  @override
  String get filterRead => 'Read';

  @override
  String get featureUnavailable =>
      'This section isn’t available yet — the WorkFlow API doesn’t provide it.';

  @override
  String get roleClient => 'Client';

  @override
  String get roleEmployee => 'Employee';

  @override
  String get logout => 'Log out';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navProjects => 'Projects';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: 'a minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: 'an hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'a day ago',
    );
    return '$_temp0';
  }

  @override
  String get notificationsEmpty => 'You’re all caught up';

  @override
  String get noResults => 'No results match your search';
}
