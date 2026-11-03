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

  @override
  String get viewDetails => 'View Details';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteTitle => 'Delete record?';

  @override
  String deleteBody(String what) {
    return '$what will be removed from this device.';
  }

  @override
  String get backendPending =>
      'This section is ready for the new WorkFlow API. Its data will appear here once the backend team publishes the endpoints.';

  @override
  String get selectHint => 'select';

  @override
  String get validationNumber => 'Enter a valid number';

  @override
  String get savedLocally =>
      'Saved on this device (demo) — not sent to the server yet.';

  @override
  String get deletedLocally => 'Removed on this device (demo).';

  @override
  String get exportReport => 'Export Report';

  @override
  String get exportPending =>
      'Export will be available when the backend supports it.';

  @override
  String get noRecords => 'No records match these filters';

  @override
  String get vsLastMonth => 'vs last month';

  @override
  String get invoicesTitle => 'Invoices Management';

  @override
  String get invoicesDescription =>
      'Track, manage, and process client billing across all registered companies.';

  @override
  String get searchInvoicesHint => 'Search invoices, company, or client...';

  @override
  String get metricTotalInvoices => 'Total Invoices';

  @override
  String get metricPaid => 'Paid';

  @override
  String get metricOverdue => 'Overdue';

  @override
  String get filterAllStatus => 'All Status';

  @override
  String get filterAllCompanies => 'All Companies';

  @override
  String get filterAllMethods => 'All Methods';

  @override
  String get rangeLast30 => 'Last 30 days';

  @override
  String get rangeLast90 => 'Last 90 days';

  @override
  String get rangeThisYear => 'This year';

  @override
  String get rangeAll => 'All time';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get fieldClient => 'Client';

  @override
  String get fieldProject => 'Project';

  @override
  String get fieldIssueDate => 'Issue date';

  @override
  String get fieldCompany => 'Company';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldInvoiceDate => 'Invoice Date';

  @override
  String get fieldDueDate => 'Due Date';

  @override
  String get fieldStatus => 'Status';

  @override
  String get fieldMethod => 'Method';

  @override
  String get fieldWallet => 'Wallet';

  @override
  String get fieldInvoice => 'Invoice';

  @override
  String get fieldEmployee => 'Employee';

  @override
  String get fieldPaymentMethod => 'Payment Method';

  @override
  String get fieldPaymentDate => 'Payment Date';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get createInvoice => 'Create Invoice';

  @override
  String get editInvoice => 'Edit Invoice';

  @override
  String get addPayment => 'Add Payment';

  @override
  String get editPayment => 'Edit Payment';

  @override
  String get paymentsTitle => 'Payment Records';

  @override
  String get paymentsDescription =>
      'Track, manage, and audit all incoming and outgoing transactions.';

  @override
  String get searchPaymentsHint => 'Search by invoice, company, or method...';

  @override
  String get metricTotalRevenue => 'TOTAL REVENUE';

  @override
  String get metricPendingPayments => 'PENDING PAYMENTS';

  @override
  String get metricTransactionVolume => 'TRANSACTION VOLUME';

  @override
  String invoicesAwaiting(int count) {
    return '$count invoices awaiting clearance';
  }

  @override
  String get directionIncoming => 'Incoming';

  @override
  String get directionOutgoing => 'Outgoing';

  @override
  String get companiesTitle => 'Available Companies';

  @override
  String get companiesDescription => 'Explore workspaces and request access';

  @override
  String get joinRequest => 'Join Request';

  @override
  String get joinPending => 'Pending';

  @override
  String joinRequestSent(String name) {
    return 'Join request sent to $name (demo).';
  }

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesDescription =>
      'Explore all workspace modules and central departments';

  @override
  String get catOverview => 'Overview';

  @override
  String get catOverviewBody => 'Key metrics, executive dashboards & reports';

  @override
  String get catDashboard => 'Dashboard';

  @override
  String get catClients => 'Clients & Subscriptions';

  @override
  String get catClientsBody => 'Enterprise accounts, agreements and requests';

  @override
  String get catFinance => 'Finance';

  @override
  String get catFinanceBody => 'Account management, expenses & payments';

  @override
  String get catPayments => 'Payments';

  @override
  String get catWork => 'Work & Projects';

  @override
  String get catWorkBody => 'Tasks, agile sprints and engineering tools';

  @override
  String get catCommunication => 'Communication';

  @override
  String get catCommunicationBody =>
      'Direct chat threads & virtual team meetings';

  @override
  String get catConversations => 'Conversations';

  @override
  String get catMeetings => 'Meetings';

  @override
  String get accountMenu => 'Account';

  @override
  String get projectsTitle => 'Projects Management';

  @override
  String get projectsDescription =>
      'Overview of all current and past initiatives.';

  @override
  String get searchProjectsHint => 'Search projects, client, or team...';

  @override
  String get metricTotalProjects => 'Total Projects';

  @override
  String get filterAllClients => 'All Clients';

  @override
  String get listView => 'List view';

  @override
  String get cardView => 'Card view';

  @override
  String get statusOnHold => 'On Hold';

  @override
  String get fieldBudget => 'Budget';

  @override
  String get fieldProgress => 'Progress';

  @override
  String get fieldTeam => 'Team';

  @override
  String get fieldTimeline => 'Timeline';

  @override
  String daysLeft(int count) {
    return '$count Days left';
  }

  @override
  String get moreActions => 'More actions';

  @override
  String get createNewProject => 'Create New Project';

  @override
  String get createNewProjectBody =>
      'Assign teammates, set milestones & track budgets';

  @override
  String get addProject => 'Add Project';

  @override
  String get editProject => 'Edit Project';

  @override
  String get fieldProjectTitle => 'Project Title';

  @override
  String get fieldEmployees => 'Employees';

  @override
  String get newConversation => 'New conversation';

  @override
  String get filterDirect => 'Direct';

  @override
  String get filterTeams => 'Teams & Channels';

  @override
  String unreadCount(int count) {
    return '$count unread';
  }

  @override
  String get you => 'You';

  @override
  String get callsPending =>
      'Calls will be available when the meetings backend is ready.';

  @override
  String get call => 'Call';

  @override
  String get videoCall => 'Video call';

  @override
  String get conversationInfo => 'Conversation info';

  @override
  String get groupChat => 'Group Chat';

  @override
  String get privateChat => 'Private Chat';

  @override
  String get participants => 'Participants';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get activeNow => 'Active now';

  @override
  String get messageHint => 'Type a message or press \'/\' for commands...';

  @override
  String get attachmentsPending =>
      'Attachments will be available when the backend supports uploads.';

  @override
  String get delivered => 'Delivered';

  @override
  String get newConversationTitle => 'Create a new conversation';

  @override
  String get newConversationBody => 'Choose type and participants';

  @override
  String get conversationType => 'Conversation Type';

  @override
  String get typeGroup => 'Group';

  @override
  String get typeDirect => 'Direct';

  @override
  String get groupName => 'Group Name';

  @override
  String get groupPicture => 'Group Picture';

  @override
  String get chooseFile => 'Choose File';

  @override
  String get noFileChosen => 'No file chosen';

  @override
  String get selectParticipants => 'Select multiple people to create a group.';

  @override
  String get selectOnePerson => 'Select one person to start a direct chat.';

  @override
  String get searchConversationsHint => 'Search conversations...';

  @override
  String get createGroup => 'Create Group';

  @override
  String get startChat => 'Start Chat';

  @override
  String get meetingsTitle => 'Meetings Management';

  @override
  String get meetingsDescription =>
      'Schedule, manage and join meetings across all companies';

  @override
  String get scheduleMeeting => 'Schedule meeting';

  @override
  String get joinByCode => 'join by code';

  @override
  String get meetingOverview => 'Meeting overview';

  @override
  String get totalMeetings => 'Total Meetings';

  @override
  String get liveNow => 'Live Now';

  @override
  String activeCount(int count) {
    return '$count Active';
  }

  @override
  String get meetingScheduled => 'Scheduled';

  @override
  String get meetingLive => 'Live';

  @override
  String get meetingWaiting => 'Waiting';

  @override
  String get meetingEnded => 'Ended';

  @override
  String get meetingsCalendar => 'Meetings Calendar';

  @override
  String timezoneLabel(String zone) {
    return 'Timezone: $zone';
  }

  @override
  String get todaysMeetings => 'Today\'s Meetings';

  @override
  String get noMeetingsThisDay => 'No meetings on this day';

  @override
  String get upcomingMeetings => 'Upcoming Meetings';

  @override
  String get searchMeetingsHint => 'Search meetings, companies, or code...';

  @override
  String get codeTypeParticipants => 'Code · Type · Participants';

  @override
  String get details => 'Details';

  @override
  String get detailsBody => 'Comprehensive session logs and meeting parameters';

  @override
  String get meetingId => 'Meeting ID';

  @override
  String get fieldType => 'Type';

  @override
  String get scheduledAt => 'Scheduled At';

  @override
  String get privacy => 'Privacy';

  @override
  String get public => 'Public';

  @override
  String get private => 'Private';

  @override
  String get startedAt => 'Started At';

  @override
  String get endedAt => 'Ended At';

  @override
  String get duration => 'Duration';

  @override
  String minutes(int count) {
    return '$count minutes';
  }

  @override
  String get createdBy => 'Created By';

  @override
  String get peakParticipants => 'Peak Participants';

  @override
  String get maxParticipants => 'Max Participants';

  @override
  String get features => 'Features';

  @override
  String get description => 'Description';

  @override
  String get invitationRequired => 'Invitation required';

  @override
  String get invitationRequiredBody =>
      'This meeting is invitation-only. Ask the host to invite you.';

  @override
  String peakOf(int peak, int max) {
    return 'Peak $peak of $max allowed.';
  }

  @override
  String get refreshList => 'Refresh list';

  @override
  String get listUpToDate => 'The list is up to date.';

  @override
  String get user => 'User';

  @override
  String get host => 'Host';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String invitationsCount(int count) {
    return 'Invitations ($count)';
  }

  @override
  String get invitationsBody =>
      'Company members and approved clients can be invited.';

  @override
  String get inviteParticipant => 'Invite Participant';

  @override
  String get noInvitations => 'No invitations sent yet';

  @override
  String get noInvitationsBody =>
      'Use the form above or click Invite to add participants to this meeting session.';

  @override
  String get featureChat => 'Chat';

  @override
  String get featureScreen => 'Screen';

  @override
  String get featureWhiteboard => 'Whiteboard';

  @override
  String get featureFiles => 'Files';

  @override
  String get scheduleMeetingTitle => 'Schedule a New Meeting';

  @override
  String get editMeeting => 'Edit Meeting';

  @override
  String get scheduleMeetingBody =>
      'Set up seamless video collaboration with your team or external clients';

  @override
  String get stepDateTime => '1 - Select Date & Time';

  @override
  String get stepDateTimeBody => 'Choose meeting date and available time slot';

  @override
  String get availableTimes => 'AVAILABLE TIMES';

  @override
  String get inviteDispatchNote =>
      'Meeting link and invitation calendar ICS files will be automatically dispatched to all confirmed participants.';

  @override
  String get stepDetails => '2 - Meeting Details';

  @override
  String get stepDetailsBody => 'Provide agenda and meeting specifications';

  @override
  String get meetingTitle => 'Meeting Title';

  @override
  String get agenda => 'Description & Agenda';

  @override
  String get meetingType => 'Meeting Type';

  @override
  String get onlineVideoMeeting => 'Online Video Meeting';

  @override
  String get meetingStatus => 'Meeting Status';

  @override
  String get companyClient => 'Company / Client';

  @override
  String get stepParticipants => '3 - Participants & Guest Access';

  @override
  String get stepParticipantsBody =>
      'Add internal team members or invite external emails';

  @override
  String get searchEmployeesHint => 'Search employees by name or type email...';

  @override
  String get addExternal => 'Add External';

  @override
  String get collaborationFeatures => 'IN-MEETING COLLABORATION FEATURES';

  @override
  String get encryptedRoom => 'End-to-end encrypted video room ready';

  @override
  String get joinByCodeTitle => 'Join by Code';

  @override
  String get meetingCode => 'Meeting Code';

  @override
  String get roomPassword => 'Room Password (Optional)';

  @override
  String get joinMeeting => 'Join Meeting';

  @override
  String get meetingNotFound => 'No meeting matches this code.';

  @override
  String get minimize => 'Minimize';

  @override
  String peopleCount(int count) {
    return '$count people';
  }

  @override
  String get polls => 'Polls';

  @override
  String get notes => 'Notes';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get camera => 'Camera';

  @override
  String get raiseHand => 'Raise hand';

  @override
  String get reactions => 'Reactions';

  @override
  String get moreOptions => 'More options';

  @override
  String get leave => 'Leave';

  @override
  String get micMuted => 'Speaker muted';

  @override
  String get mediaPending =>
      'Audio and video connect once the meetings backend is available.';

  @override
  String meetingStartedAt(String time) {
    return 'Meeting started at $time';
  }

  @override
  String get messageParticipantsHint => 'Type a message to participants...';

  @override
  String get livePoll => 'LIVE POLL';

  @override
  String votesCount(int count) {
    return '$count votes';
  }

  @override
  String get tapToVote => 'Tap an option to vote';

  @override
  String votedAs(String name) {
    return 'Voted as: $name';
  }

  @override
  String get noteTitleHint => 'Note title...';

  @override
  String get noteBodyHint => 'Write meeting notes or minutes here...';

  @override
  String get saveNote => 'Save note';

  @override
  String get muteAll => 'Mute all';

  @override
  String get participant => 'Participant';

  @override
  String get encryptedMeeting => 'End-to-end encrypted meeting';
}
