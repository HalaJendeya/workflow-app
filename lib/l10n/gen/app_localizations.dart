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

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete record?'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'{what} will be removed from this device.'**
  String deleteBody(String what);

  /// No description provided for @backendPending.
  ///
  /// In en, this message translates to:
  /// **'This section is ready for the new WorkFlow API. Its data will appear here once the backend team publishes the endpoints.'**
  String get backendPending;

  /// No description provided for @selectHint.
  ///
  /// In en, this message translates to:
  /// **'select'**
  String get selectHint;

  /// No description provided for @validationNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get validationNumber;

  /// No description provided for @savedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device (demo) — not sent to the server yet.'**
  String get savedLocally;

  /// No description provided for @deletedLocally.
  ///
  /// In en, this message translates to:
  /// **'Removed on this device (demo).'**
  String get deletedLocally;

  /// No description provided for @exportReport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get exportReport;

  /// No description provided for @exportPending.
  ///
  /// In en, this message translates to:
  /// **'Export will be available when the backend supports it.'**
  String get exportPending;

  /// No description provided for @noRecords.
  ///
  /// In en, this message translates to:
  /// **'No records match these filters'**
  String get noRecords;

  /// No description provided for @vsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs last month'**
  String get vsLastMonth;

  /// No description provided for @invoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices Management'**
  String get invoicesTitle;

  /// No description provided for @invoicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Track, manage, and process client billing across all registered companies.'**
  String get invoicesDescription;

  /// No description provided for @searchInvoicesHint.
  ///
  /// In en, this message translates to:
  /// **'Search invoices, company, or client...'**
  String get searchInvoicesHint;

  /// No description provided for @metricTotalInvoices.
  ///
  /// In en, this message translates to:
  /// **'Total Invoices'**
  String get metricTotalInvoices;

  /// No description provided for @metricPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get metricPaid;

  /// No description provided for @metricOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get metricOverdue;

  /// No description provided for @filterAllStatus.
  ///
  /// In en, this message translates to:
  /// **'All Status'**
  String get filterAllStatus;

  /// No description provided for @filterAllCompanies.
  ///
  /// In en, this message translates to:
  /// **'All Companies'**
  String get filterAllCompanies;

  /// No description provided for @filterAllMethods.
  ///
  /// In en, this message translates to:
  /// **'All Methods'**
  String get filterAllMethods;

  /// No description provided for @rangeLast30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get rangeLast30;

  /// No description provided for @rangeLast90.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get rangeLast90;

  /// No description provided for @rangeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get rangeThisYear;

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get rangeAll;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get statusOverdue;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @fieldClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get fieldClient;

  /// No description provided for @fieldProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get fieldProject;

  /// No description provided for @fieldIssueDate.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get fieldIssueDate;

  /// No description provided for @fieldCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get fieldCompany;

  /// No description provided for @fieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldCurrency;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldInvoiceDate.
  ///
  /// In en, this message translates to:
  /// **'Invoice Date'**
  String get fieldInvoiceDate;

  /// No description provided for @fieldDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get fieldDueDate;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @fieldMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get fieldMethod;

  /// No description provided for @fieldWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get fieldWallet;

  /// No description provided for @fieldInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get fieldInvoice;

  /// No description provided for @fieldEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get fieldEmployee;

  /// No description provided for @fieldPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get fieldPaymentMethod;

  /// No description provided for @fieldPaymentDate.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get fieldPaymentDate;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @createInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get createInvoice;

  /// No description provided for @editInvoice.
  ///
  /// In en, this message translates to:
  /// **'Edit Invoice'**
  String get editInvoice;

  /// No description provided for @addPayment.
  ///
  /// In en, this message translates to:
  /// **'Add Payment'**
  String get addPayment;

  /// No description provided for @editPayment.
  ///
  /// In en, this message translates to:
  /// **'Edit Payment'**
  String get editPayment;

  /// No description provided for @paymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Records'**
  String get paymentsTitle;

  /// No description provided for @paymentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Track, manage, and audit all incoming and outgoing transactions.'**
  String get paymentsDescription;

  /// No description provided for @searchPaymentsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by invoice, company, or method...'**
  String get searchPaymentsHint;

  /// No description provided for @metricTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'TOTAL REVENUE'**
  String get metricTotalRevenue;

  /// No description provided for @metricPendingPayments.
  ///
  /// In en, this message translates to:
  /// **'PENDING PAYMENTS'**
  String get metricPendingPayments;

  /// No description provided for @metricTransactionVolume.
  ///
  /// In en, this message translates to:
  /// **'TRANSACTION VOLUME'**
  String get metricTransactionVolume;

  /// No description provided for @invoicesAwaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} invoices awaiting clearance'**
  String invoicesAwaiting(int count);

  /// No description provided for @directionIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get directionIncoming;

  /// No description provided for @directionOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get directionOutgoing;

  /// No description provided for @companiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Companies'**
  String get companiesTitle;

  /// No description provided for @companiesDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore workspaces and request access'**
  String get companiesDescription;

  /// No description provided for @joinRequest.
  ///
  /// In en, this message translates to:
  /// **'Join Request'**
  String get joinRequest;

  /// No description provided for @joinPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get joinPending;

  /// No description provided for @joinRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Join request sent to {name} (demo).'**
  String joinRequestSent(String name);

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore all workspace modules and central departments'**
  String get categoriesDescription;

  /// No description provided for @catOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get catOverview;

  /// No description provided for @catOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'Key metrics, executive dashboards & reports'**
  String get catOverviewBody;

  /// No description provided for @catDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get catDashboard;

  /// No description provided for @catClients.
  ///
  /// In en, this message translates to:
  /// **'Clients & Subscriptions'**
  String get catClients;

  /// No description provided for @catClientsBody.
  ///
  /// In en, this message translates to:
  /// **'Enterprise accounts, agreements and requests'**
  String get catClientsBody;

  /// No description provided for @catFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get catFinance;

  /// No description provided for @catFinanceBody.
  ///
  /// In en, this message translates to:
  /// **'Account management, expenses & payments'**
  String get catFinanceBody;

  /// No description provided for @catPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get catPayments;

  /// No description provided for @catWork.
  ///
  /// In en, this message translates to:
  /// **'Work & Projects'**
  String get catWork;

  /// No description provided for @catWorkBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks, agile sprints and engineering tools'**
  String get catWorkBody;

  /// No description provided for @catCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get catCommunication;

  /// No description provided for @catCommunicationBody.
  ///
  /// In en, this message translates to:
  /// **'Direct chat threads & virtual team meetings'**
  String get catCommunicationBody;

  /// No description provided for @catConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get catConversations;

  /// No description provided for @catMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get catMeetings;

  /// No description provided for @accountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountMenu;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects Management'**
  String get projectsTitle;

  /// No description provided for @projectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Overview of all current and past initiatives.'**
  String get projectsDescription;

  /// No description provided for @searchProjectsHint.
  ///
  /// In en, this message translates to:
  /// **'Search projects, client, or team...'**
  String get searchProjectsHint;

  /// No description provided for @metricTotalProjects.
  ///
  /// In en, this message translates to:
  /// **'Total Projects'**
  String get metricTotalProjects;

  /// No description provided for @filterAllClients.
  ///
  /// In en, this message translates to:
  /// **'All Clients'**
  String get filterAllClients;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @cardView.
  ///
  /// In en, this message translates to:
  /// **'Card view'**
  String get cardView;

  /// No description provided for @statusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get statusOnHold;

  /// No description provided for @fieldBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get fieldBudget;

  /// No description provided for @fieldProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get fieldProgress;

  /// No description provided for @fieldTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get fieldTeam;

  /// No description provided for @fieldTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get fieldTimeline;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} Days left'**
  String daysLeft(int count);

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @createNewProject.
  ///
  /// In en, this message translates to:
  /// **'Create New Project'**
  String get createNewProject;

  /// No description provided for @createNewProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Assign teammates, set milestones & track budgets'**
  String get createNewProjectBody;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

  /// No description provided for @editProject.
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get editProject;

  /// No description provided for @fieldProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Title'**
  String get fieldProjectTitle;

  /// No description provided for @fieldEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get fieldEmployees;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newConversation;

  /// No description provided for @filterDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get filterDirect;

  /// No description provided for @filterTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams & Channels'**
  String get filterTeams;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @callsPending.
  ///
  /// In en, this message translates to:
  /// **'Calls will be available when the meetings backend is ready.'**
  String get callsPending;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @videoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get videoCall;

  /// No description provided for @conversationInfo.
  ///
  /// In en, this message translates to:
  /// **'Conversation info'**
  String get conversationInfo;

  /// No description provided for @groupChat.
  ///
  /// In en, this message translates to:
  /// **'Group Chat'**
  String get groupChat;

  /// No description provided for @privateChat.
  ///
  /// In en, this message translates to:
  /// **'Private Chat'**
  String get privateChat;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @activeNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get activeNow;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message or press \'/\' for commands...'**
  String get messageHint;

  /// No description provided for @attachmentsPending.
  ///
  /// In en, this message translates to:
  /// **'Attachments will be available when the backend supports uploads.'**
  String get attachmentsPending;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @newConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new conversation'**
  String get newConversationTitle;

  /// No description provided for @newConversationBody.
  ///
  /// In en, this message translates to:
  /// **'Choose type and participants'**
  String get newConversationBody;

  /// No description provided for @conversationType.
  ///
  /// In en, this message translates to:
  /// **'Conversation Type'**
  String get conversationType;

  /// No description provided for @typeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get typeGroup;

  /// No description provided for @typeDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get typeDirect;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// No description provided for @groupPicture.
  ///
  /// In en, this message translates to:
  /// **'Group Picture'**
  String get groupPicture;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// No description provided for @noFileChosen.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get noFileChosen;

  /// No description provided for @selectParticipants.
  ///
  /// In en, this message translates to:
  /// **'Select multiple people to create a group.'**
  String get selectParticipants;

  /// No description provided for @selectOnePerson.
  ///
  /// In en, this message translates to:
  /// **'Select one person to start a direct chat.'**
  String get selectOnePerson;

  /// No description provided for @searchConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get searchConversationsHint;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get startChat;

  /// No description provided for @meetingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meetings Management'**
  String get meetingsTitle;

  /// No description provided for @meetingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Schedule, manage and join meetings across all companies'**
  String get meetingsDescription;

  /// No description provided for @scheduleMeeting.
  ///
  /// In en, this message translates to:
  /// **'Schedule meeting'**
  String get scheduleMeeting;

  /// No description provided for @joinByCode.
  ///
  /// In en, this message translates to:
  /// **'join by code'**
  String get joinByCode;

  /// No description provided for @meetingOverview.
  ///
  /// In en, this message translates to:
  /// **'Meeting overview'**
  String get meetingOverview;

  /// No description provided for @totalMeetings.
  ///
  /// In en, this message translates to:
  /// **'Total Meetings'**
  String get totalMeetings;

  /// No description provided for @liveNow.
  ///
  /// In en, this message translates to:
  /// **'Live Now'**
  String get liveNow;

  /// No description provided for @activeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Active'**
  String activeCount(int count);

  /// No description provided for @meetingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get meetingScheduled;

  /// No description provided for @meetingLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get meetingLive;

  /// No description provided for @meetingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get meetingWaiting;

  /// No description provided for @meetingEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get meetingEnded;

  /// No description provided for @meetingsCalendar.
  ///
  /// In en, this message translates to:
  /// **'Meetings Calendar'**
  String get meetingsCalendar;

  /// No description provided for @timezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Timezone: {zone}'**
  String timezoneLabel(String zone);

  /// No description provided for @todaysMeetings.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Meetings'**
  String get todaysMeetings;

  /// No description provided for @noMeetingsThisDay.
  ///
  /// In en, this message translates to:
  /// **'No meetings on this day'**
  String get noMeetingsThisDay;

  /// No description provided for @upcomingMeetings.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Meetings'**
  String get upcomingMeetings;

  /// No description provided for @searchMeetingsHint.
  ///
  /// In en, this message translates to:
  /// **'Search meetings, companies, or code...'**
  String get searchMeetingsHint;

  /// No description provided for @codeTypeParticipants.
  ///
  /// In en, this message translates to:
  /// **'Code · Type · Participants'**
  String get codeTypeParticipants;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @detailsBody.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive session logs and meeting parameters'**
  String get detailsBody;

  /// No description provided for @meetingId.
  ///
  /// In en, this message translates to:
  /// **'Meeting ID'**
  String get meetingId;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @scheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled At'**
  String get scheduledAt;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **'Started At'**
  String get startedAt;

  /// No description provided for @endedAt.
  ///
  /// In en, this message translates to:
  /// **'Ended At'**
  String get endedAt;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String minutes(int count);

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created By'**
  String get createdBy;

  /// No description provided for @peakParticipants.
  ///
  /// In en, this message translates to:
  /// **'Peak Participants'**
  String get peakParticipants;

  /// No description provided for @maxParticipants.
  ///
  /// In en, this message translates to:
  /// **'Max Participants'**
  String get maxParticipants;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @invitationRequired.
  ///
  /// In en, this message translates to:
  /// **'Invitation required'**
  String get invitationRequired;

  /// No description provided for @invitationRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This meeting is invitation-only. Ask the host to invite you.'**
  String get invitationRequiredBody;

  /// No description provided for @peakOf.
  ///
  /// In en, this message translates to:
  /// **'Peak {peak} of {max} allowed.'**
  String peakOf(int peak, int max);

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get refreshList;

  /// No description provided for @listUpToDate.
  ///
  /// In en, this message translates to:
  /// **'The list is up to date.'**
  String get listUpToDate;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @invitationsCount.
  ///
  /// In en, this message translates to:
  /// **'Invitations ({count})'**
  String invitationsCount(int count);

  /// No description provided for @invitationsBody.
  ///
  /// In en, this message translates to:
  /// **'Company members and approved clients can be invited.'**
  String get invitationsBody;

  /// No description provided for @inviteParticipant.
  ///
  /// In en, this message translates to:
  /// **'Invite Participant'**
  String get inviteParticipant;

  /// No description provided for @noInvitations.
  ///
  /// In en, this message translates to:
  /// **'No invitations sent yet'**
  String get noInvitations;

  /// No description provided for @noInvitationsBody.
  ///
  /// In en, this message translates to:
  /// **'Use the form above or click Invite to add participants to this meeting session.'**
  String get noInvitationsBody;

  /// No description provided for @featureChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get featureChat;

  /// No description provided for @featureScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get featureScreen;

  /// No description provided for @featureWhiteboard.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard'**
  String get featureWhiteboard;

  /// No description provided for @featureFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get featureFiles;

  /// No description provided for @scheduleMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule a New Meeting'**
  String get scheduleMeetingTitle;

  /// No description provided for @editMeeting.
  ///
  /// In en, this message translates to:
  /// **'Edit Meeting'**
  String get editMeeting;

  /// No description provided for @scheduleMeetingBody.
  ///
  /// In en, this message translates to:
  /// **'Set up seamless video collaboration with your team or external clients'**
  String get scheduleMeetingBody;

  /// No description provided for @stepDateTime.
  ///
  /// In en, this message translates to:
  /// **'1 - Select Date & Time'**
  String get stepDateTime;

  /// No description provided for @stepDateTimeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose meeting date and available time slot'**
  String get stepDateTimeBody;

  /// No description provided for @availableTimes.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE TIMES'**
  String get availableTimes;

  /// No description provided for @inviteDispatchNote.
  ///
  /// In en, this message translates to:
  /// **'Meeting link and invitation calendar ICS files will be automatically dispatched to all confirmed participants.'**
  String get inviteDispatchNote;

  /// No description provided for @stepDetails.
  ///
  /// In en, this message translates to:
  /// **'2 - Meeting Details'**
  String get stepDetails;

  /// No description provided for @stepDetailsBody.
  ///
  /// In en, this message translates to:
  /// **'Provide agenda and meeting specifications'**
  String get stepDetailsBody;

  /// No description provided for @meetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting Title'**
  String get meetingTitle;

  /// No description provided for @agenda.
  ///
  /// In en, this message translates to:
  /// **'Description & Agenda'**
  String get agenda;

  /// No description provided for @meetingType.
  ///
  /// In en, this message translates to:
  /// **'Meeting Type'**
  String get meetingType;

  /// No description provided for @onlineVideoMeeting.
  ///
  /// In en, this message translates to:
  /// **'Online Video Meeting'**
  String get onlineVideoMeeting;

  /// No description provided for @meetingStatus.
  ///
  /// In en, this message translates to:
  /// **'Meeting Status'**
  String get meetingStatus;

  /// No description provided for @companyClient.
  ///
  /// In en, this message translates to:
  /// **'Company / Client'**
  String get companyClient;

  /// No description provided for @stepParticipants.
  ///
  /// In en, this message translates to:
  /// **'3 - Participants & Guest Access'**
  String get stepParticipants;

  /// No description provided for @stepParticipantsBody.
  ///
  /// In en, this message translates to:
  /// **'Add internal team members or invite external emails'**
  String get stepParticipantsBody;

  /// No description provided for @searchEmployeesHint.
  ///
  /// In en, this message translates to:
  /// **'Search employees by name or type email...'**
  String get searchEmployeesHint;

  /// No description provided for @addExternal.
  ///
  /// In en, this message translates to:
  /// **'Add External'**
  String get addExternal;

  /// No description provided for @collaborationFeatures.
  ///
  /// In en, this message translates to:
  /// **'IN-MEETING COLLABORATION FEATURES'**
  String get collaborationFeatures;

  /// No description provided for @encryptedRoom.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted video room ready'**
  String get encryptedRoom;

  /// No description provided for @joinByCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Join by Code'**
  String get joinByCodeTitle;

  /// No description provided for @meetingCode.
  ///
  /// In en, this message translates to:
  /// **'Meeting Code'**
  String get meetingCode;

  /// No description provided for @roomPassword.
  ///
  /// In en, this message translates to:
  /// **'Room Password (Optional)'**
  String get roomPassword;

  /// No description provided for @joinMeeting.
  ///
  /// In en, this message translates to:
  /// **'Join Meeting'**
  String get joinMeeting;

  /// No description provided for @meetingNotFound.
  ///
  /// In en, this message translates to:
  /// **'No meeting matches this code.'**
  String get meetingNotFound;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String peopleCount(int count);

  /// No description provided for @polls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get polls;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @raiseHand.
  ///
  /// In en, this message translates to:
  /// **'Raise hand'**
  String get raiseHand;

  /// No description provided for @reactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactions;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @micMuted.
  ///
  /// In en, this message translates to:
  /// **'Speaker muted'**
  String get micMuted;

  /// No description provided for @mediaPending.
  ///
  /// In en, this message translates to:
  /// **'Audio and video connect once the meetings backend is available.'**
  String get mediaPending;

  /// No description provided for @meetingStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Meeting started at {time}'**
  String meetingStartedAt(String time);

  /// No description provided for @messageParticipantsHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message to participants...'**
  String get messageParticipantsHint;

  /// No description provided for @livePoll.
  ///
  /// In en, this message translates to:
  /// **'LIVE POLL'**
  String get livePoll;

  /// No description provided for @votesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} votes'**
  String votesCount(int count);

  /// No description provided for @tapToVote.
  ///
  /// In en, this message translates to:
  /// **'Tap an option to vote'**
  String get tapToVote;

  /// No description provided for @votedAs.
  ///
  /// In en, this message translates to:
  /// **'Voted as: {name}'**
  String votedAs(String name);

  /// No description provided for @noteTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Note title...'**
  String get noteTitleHint;

  /// No description provided for @noteBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write meeting notes or minutes here...'**
  String get noteBodyHint;

  /// No description provided for @saveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get saveNote;

  /// No description provided for @muteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute all'**
  String get muteAll;

  /// No description provided for @participant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get participant;

  /// No description provided for @encryptedMeeting.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted meeting'**
  String get encryptedMeeting;
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
