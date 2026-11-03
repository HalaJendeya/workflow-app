import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WorkFlow'**
  String get appTitle;

  /// No description provided for @portalClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get portalClient;

  /// No description provided for @portalEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get portalEmployee;

  /// No description provided for @designPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Design pending'**
  String get designPendingTitle;

  /// No description provided for @designPendingBody.
  ///
  /// In en, this message translates to:
  /// **'This screen will be built from the official Figma design once access to the file is granted.'**
  String get designPendingBody;

  /// No description provided for @demoModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo data — nothing is saved to the server'**
  String get demoModeBanner;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @emptyState.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyState;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the highlighted fields.'**
  String get errorValidation;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} seconds.'**
  String errorRateLimited(int seconds);

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again.'**
  String get errorServer;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @accountTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountTypeTitle;

  /// No description provided for @accountTypeClientTitle.
  ///
  /// In en, this message translates to:
  /// **'client'**
  String get accountTypeClientTitle;

  /// No description provided for @accountTypeClientBody.
  ///
  /// In en, this message translates to:
  /// **'I am looking for companies to execute my projects'**
  String get accountTypeClientBody;

  /// No description provided for @accountTypeEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get accountTypeEmployeeTitle;

  /// No description provided for @accountTypeEmployeeBody.
  ///
  /// In en, this message translates to:
  /// **'I manage project and deal with clients'**
  String get accountTypeEmployeeBody;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don’t Have an Account?'**
  String get noAccountPrompt;

  /// No description provided for @createClientAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Client Account'**
  String get createClientAccount;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome '**
  String get loginWelcome;

  /// No description provided for @loginWelcomeAccent.
  ///
  /// In en, this message translates to:
  /// **'back!'**
  String get loginWelcomeAccent;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'example123@gmail.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forget password ?'**
  String get forgotPasswordLink;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @signUpPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already not have an account?'**
  String get signUpPrompt;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @registerTitleLead.
  ///
  /// In en, this message translates to:
  /// **'Create an '**
  String get registerTitleLead;

  /// No description provided for @registerTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'account'**
  String get registerTitleAccent;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get registerSubtitle;

  /// No description provided for @userNameLabel.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userNameLabel;

  /// No description provided for @userNameHint.
  ///
  /// In en, this message translates to:
  /// **'mahmoud ali'**
  String get userNameHint;

  /// No description provided for @agreeTermsLead.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get agreeTermsLead;

  /// No description provided for @agreeTermsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get agreeTermsTerms;

  /// No description provided for @agreeTermsAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get agreeTermsAnd;

  /// No description provided for @agreeTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get agreeTermsConditions;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// No description provided for @loginLink.
  ///
  /// In en, this message translates to:
  /// **'login'**
  String get loginLink;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email and we’ll send you a code to reset your password.'**
  String get forgotBody;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Log In'**
  String get backToLogin;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verifyTitle;

  /// No description provided for @verifyBody.
  ///
  /// In en, this message translates to:
  /// **'We’ve sent a {length}-digit code to ({email})'**
  String verifyBody(int length, String email);

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @noCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Didn’t receive the code?'**
  String get noCodePrompt;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent.'**
  String get codeResent;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Password'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Your new password must be different from previous used passwords.'**
  String get newPasswordBody;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @successAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get successAccountTitle;

  /// No description provided for @successAccountBody.
  ///
  /// In en, this message translates to:
  /// **'You can now log in with your new password.'**
  String get successAccountBody;

  /// No description provided for @successPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get successPasswordTitle;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get validationRequired;

  /// No description provided for @validationEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmail;

  /// No description provided for @validationPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters'**
  String validationPasswordMin(int min);

  /// No description provided for @validationPasswordMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don’t match'**
  String get validationPasswordMatch;

  /// No description provided for @validationOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the full code'**
  String get validationOtp;

  /// No description provided for @validationTerms.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms and Conditions'**
  String get validationTerms;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCompanies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get navCompanies;

  /// No description provided for @navInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @overviewBreadcrumb.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overviewBreadcrumb;

  /// No description provided for @welcomeBackName.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBackName(String name);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Searching....'**
  String get searchHint;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// No description provided for @tasksFilterProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects {count}'**
  String tasksFilterProjects(int count);

  /// No description provided for @tasksFilterMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get tasksFilterMeetings;

  /// No description provided for @tasksFilterGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tasksFilterGeneral;

  /// No description provided for @addMicroTask.
  ///
  /// In en, this message translates to:
  /// **'Add a personal micro-task'**
  String get addMicroTask;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String notificationsFilterAll(int count);

  /// No description provided for @notificationsFilterMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get notificationsFilterMentions;

  /// No description provided for @notificationsFilterProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get notificationsFilterProjects;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @notificationStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get notificationStatusTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get filterUnread;

  /// No description provided for @filterRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get filterRead;

  /// No description provided for @featureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This section isn’t available yet — the WorkFlow API doesn’t provide it.'**
  String get featureUnavailable;

  /// No description provided for @roleClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get roleClient;

  /// No description provided for @roleEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get roleEmployee;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{a minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{an hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{a day ago} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You’re all caught up'**
  String get notificationsEmpty;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results match your search'**
  String get noResults;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
