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
      'Attachments aren’t available in the app yet — it needs a file picker. The WorkFlow API already accepts images, PDF and text files.';

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

  @override
  String get navSprints => 'Sprints';

  @override
  String get timesheetsShort => 'Timesheets';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get backlog => 'Backlog';

  @override
  String get toDo => 'To do';

  @override
  String get taskCode => 'Task';

  @override
  String get priority => 'Priority';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get tasksManagement => 'Tasks Management';

  @override
  String get tasksManagementBody =>
      'Overview and administration of all active tasks across projects';

  @override
  String get addTask => 'Add Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get activeTasks => 'ACTIVE TASKS';

  @override
  String get completionVelocity => 'Overall completion velocity';

  @override
  String get totalBudgetUtilization => 'TOTAL BUDGET UTILIZATION';

  @override
  String get budgetAllocations => 'Sum rate × allocations';

  @override
  String get loggedHours => 'LOGGED HOURS';

  @override
  String get hoursThisPeriod => 'Hours logged this period';

  @override
  String get searchTasksHint => 'Search task title, project, employee...';

  @override
  String get allProjects => 'All Projects';

  @override
  String get allAssignees => 'All Assignees';

  @override
  String get priorityLevel => 'Priority Level';

  @override
  String get view => 'View';

  @override
  String showingRange(int from, int to, int total) {
    return 'Showing $from–$to of $total';
  }

  @override
  String get taskTitle => 'Task Title';

  @override
  String get assignee => 'Assignee';

  @override
  String get storyPoints => 'Story Points';

  @override
  String get taskDate => 'Task Date';

  @override
  String get sprintBacklog => 'Sprint & Backlog';

  @override
  String get sprintBacklogBody =>
      'Manage your product backlog, allocate resources, and track sprint performance.';

  @override
  String get kanban => 'Kanban';

  @override
  String get createSprint => 'Create Sprint';

  @override
  String get sprintName => 'Sprint name';

  @override
  String get noTasksInColumn => 'No tasks in this column';

  @override
  String points(int count) {
    return '$count pts';
  }

  @override
  String subtasksDone(int done, int total) {
    return 'Subtasks: $done/$total done';
  }

  @override
  String get moveTo => 'Move to';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get timesheetsTitle => 'Timesheets Dashboard';

  @override
  String get timesheetsBody =>
      'Review logged hours, approvals and payouts across projects';

  @override
  String get totalHours => 'Total Hours';

  @override
  String get totalSalaries => 'Total Salaries';

  @override
  String get searchTimesheetsHint => 'Search task, project, employee...';

  @override
  String get accountId => 'Account ID';

  @override
  String achievedValue(int count, int percent) {
    return '$count · $percent% achieved';
  }

  @override
  String get activeClientProjects => 'Active Client Projects & Deliverables';

  @override
  String get activeHub => 'Active Hub';

  @override
  String get activeInSprint => 'Active in sprint';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordBody =>
      'Update your account password to maintain security.';

  @override
  String get completedMilestones => 'Completed milestones';

  @override
  String get confirmDeletion => 'I confirm deletion';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get contractBudget => 'Contract Budget';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get dashboardBody =>
      'Overview of your projects, invoices, and linked companies.';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountBody =>
      'Permanently remove your account and all associated data.';

  @override
  String get deleteAccountWarning =>
      'Are you sure you want to delete your account? This action cannot be undone. All your projects, files, and settings will be permanently erased from our servers immediately.';

  @override
  String get deletionIrreversible =>
      'I understand that my data cannot be recovered after this point.';

  @override
  String get deliverableBreakdown => 'Deliverable progress breakdown';

  @override
  String get downloadReceipt => 'Download receipt';

  @override
  String efficiencyDelta(String delta) {
    return '$delta efficiency';
  }

  @override
  String get emailAddress => 'Email Address';

  @override
  String get expenditureTrends => 'Expenditure & Invoiced Trends';

  @override
  String get expenditureTrendsBody =>
      'Spending cadence & approved invoice delivery';

  @override
  String get filterStatus => 'Filter Status';

  @override
  String get financialSummary => 'Financial Summary & Escrow Balance';

  @override
  String get firstName => 'First Name';

  @override
  String inDevValue(int count, int percent) {
    return '$count · $percent% in dev';
  }

  @override
  String get invoicedSeries => 'Invoiced (\$)';

  @override
  String get issueDate => 'Issue Date';

  @override
  String get keepProfileUpToDate => 'Keep your profile up to date';

  @override
  String get keepProfileUpToDateBody =>
      'A complete profile helps us serve you better.';

  @override
  String kpisTracked(int count) {
    return '$count KPIs tracked • Key deliverables & KPIs';
  }

  @override
  String get lastName => 'Last Name';

  @override
  String get latestInvoices => 'Latest Invoices & Receipts';

  @override
  String get milestoneVelocity => 'Deliverables & Milestone Velocity';

  @override
  String milestonesTotal(int count) {
    return '$count Milestones Total';
  }

  @override
  String get monthlyRevenue => 'Monthly Revenue';

  @override
  String get newMilestoneRequest => 'New Milestone Request';

  @override
  String get newPassword => 'New Password';

  @override
  String get onSchedule => 'On Schedule';

  @override
  String get overviewMetrics => 'Overview & Metrics';

  @override
  String get passwordChanged => 'Password updated';

  @override
  String get passwordRule =>
      'Password must be at least 8 characters long and include a mix of letters, numbers, and symbols.';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String peakValue(String label, String amount) {
    return '$label Peak: $amount';
  }

  @override
  String get pendingReview => 'Pending Review';

  @override
  String percentItems(int percent, int count) {
    return '$percent% ($count items)';
  }

  @override
  String get periodDay => 'Day';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodYear => 'Year';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get profileDetails => 'Profile Details';

  @override
  String get profileDetailsBody =>
      'Manage your personal information and preferences.';

  @override
  String get profileSaved => 'Profile updated';

  @override
  String queuedValue(int count, int percent) {
    return '$count · $percent% queued';
  }

  @override
  String get realtimeOverview => 'Real-time status overview';

  @override
  String recentCount(int count) {
    return '$count Recent';
  }

  @override
  String revenueTarget(String amount, String percent) {
    return 'Target: $amount ($percent%)';
  }

  @override
  String get reviewQa => 'Review & QA';

  @override
  String roadmapValue(int count) {
    return '$count · Roadmap';
  }

  @override
  String get roleLabel => 'Role';

  @override
  String runningCount(int count) {
    return '$count Running';
  }

  @override
  String get settledSeries => 'Settled (\$)';

  @override
  String get targetDelivery => 'Target Delivery';

  @override
  String get totalSprints => 'Total Sprints';

  @override
  String get uploadNewImage => 'Upload New Image';

  @override
  String get verifiedClientAccount => 'Verified Client Account';

  @override
  String viewAllCount(int count) {
    return 'View All ($count)';
  }

  @override
  String get workAllocation => 'Work & Task Allocation';

  @override
  String get workOverview => 'Work overview';

  @override
  String get yourAccount => 'your account';

  @override
  String get employeeDashboardBody =>
      'Your work, hours and sprint progress at a glance.';

  @override
  String get revenue => 'Revenue';

  @override
  String targetShort(String amount) {
    return 'Target $amount';
  }

  @override
  String tasksCount(int count) {
    return '+$count Tasks';
  }

  @override
  String highPriorityCount(int count) {
    return '$count high priority';
  }

  @override
  String get completedUpper => 'Completed';

  @override
  String velocityPercent(int percent) {
    return '$percent% velocity';
  }

  @override
  String weeklyPercent(int percent) {
    return '$percent% weekly';
  }

  @override
  String get workingHoursTrend => 'Working Hours & Trend';

  @override
  String get hrsUnit => 'hrs';

  @override
  String get currentWeek => 'Current Week';

  @override
  String get hoursVsTarget => 'Daily logged hours vs. baseline target';

  @override
  String loggedLegend(String hours) {
    return 'Logged ($hours)';
  }

  @override
  String targetLegend(String hours) {
    return 'Target ($hours/day)';
  }

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get avgDaily => 'Avg daily';

  @override
  String get focusRate => 'Focus rate';

  @override
  String get timesheetLabel => 'Timesheet';

  @override
  String get taskDistribution => 'Task Distribution';

  @override
  String get taskDistributionBody => 'Current sprint backlog & status';

  @override
  String get allTasks => 'All Tasks';

  @override
  String get tasksUpper => 'TASKS';

  @override
  String percentDone(int percent) {
    return '$percent% Done';
  }

  @override
  String onTrackEta(int days) {
    return 'On track (ETA ${days}d)';
  }

  @override
  String get activeTasksMilestones => 'Active Tasks & Milestones';

  @override
  String get viewBacklog => 'View Backlog';

  @override
  String percentComplete(int percent) {
    return '$percent% Complete';
  }

  @override
  String get revenueTrajectory => 'Revenue Trajectory';

  @override
  String get revenueTrajectoryBody => 'Earnings vs monthly targets';

  @override
  String yoyDelta(int percent) {
    return '+$percent% YoY';
  }

  @override
  String get actionNeedsBackend =>
      'Not saved: this action has no verified server endpoint yet.';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get statusPartiallyPaid => 'Partially paid';

  @override
  String get fieldPaid => 'Paid';

  @override
  String get fieldRemaining => 'Remaining';

  @override
  String get dashProjects => 'Projects';

  @override
  String get dashCompleted => 'Completed projects';

  @override
  String get dashInProgress => 'Projects in progress';

  @override
  String get dashLiveOnly =>
      'The server reports project counts only; the other dashboard sections need a documented dashboard response.';

  @override
  String get totalEarned => 'Total earned';

  @override
  String get paidSalary => 'Paid salary';

  @override
  String get unpaidSalary => 'Unpaid salary';

  @override
  String get projectLeader => 'Project leader';

  @override
  String get inReview => 'In review';

  @override
  String get meetingCancelled => 'Cancelled';

  @override
  String get meetingTypeInstant => 'Instant';

  @override
  String get acceptInvitation => 'Accept';

  @override
  String get declineInvitation => 'Decline';

  @override
  String get invitationAccepted => 'Invitation accepted.';

  @override
  String get invitationDeclined => 'Invitation declined.';

  @override
  String get myInvitations => 'My invitations';

  @override
  String get yourInvitation => 'Your invitation';

  @override
  String get invitationStatusAccepted => 'Accepted';

  @override
  String get invitationStatusDeclined => 'Declined';

  @override
  String get invitationStatusExpired => 'Expired';

  @override
  String invitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get meetingJoinUnavailable =>
      'Joining a meeting from the app isn’t available yet — the WorkFlow API has no meeting lookup by code, and the app does not include the LiveKit media client.';

  @override
  String get meetingCreateUnavailable =>
      'Meetings can’t be created from this account — the WorkFlow API has no create route for your role.';

  @override
  String durationSeconds(int h, int m, int s) {
    return '${h}h ${m}m ${s}s';
  }

  @override
  String calendarShowsLatest(int count) {
    return 'The calendar shows the latest $count meetings.';
  }

  @override
  String get noActiveSprint => 'This project has no current sprint.';

  @override
  String sprintPoints(int done, int total, int percent) {
    return '$done / $total points · $percent%';
  }

  @override
  String get taskStatusUpdated => 'Task status updated.';

  @override
  String get sprintCreateUnavailable =>
      'Sprints can’t be created from an employee account — the WorkFlow API has no sprint create route for this role.';

  @override
  String backlogFirstPage(int shown, int total) {
    return 'Showing $shown of $total backlog tasks.';
  }

  @override
  String sprintsCount(int count) {
    return 'Sprints ($count)';
  }

  @override
  String get validationPositive => 'Enter an amount greater than 0';

  @override
  String get validationWholeNumber => 'Enter a whole number';

  @override
  String get validationDueBeforeIssue =>
      'The due date can’t be before the invoice date';

  @override
  String get invoiceCreateUnavailable =>
      'Invoices can’t be created from this account — the WorkFlow API has no invoice create route for clients.';

  @override
  String get paymentCreateUnavailable =>
      'Payments can’t be recorded from this account — the WorkFlow API has no payment create route for clients.';

  @override
  String get projectCreateUnavailable =>
      'Projects can’t be created from this account — the WorkFlow API has no project create route for your role.';

  @override
  String get taskCreateUnavailable =>
      'Tasks can’t be created here yet — the WorkFlow API accepts new tasks only from a project leader, and this form isn’t connected to it.';

  @override
  String get emojiUseKeyboard =>
      'Use your keyboard’s emoji button — the app has no emoji picker yet.';

  @override
  String get voiceNotSupported =>
      'Voice messages aren’t supported — the WorkFlow API accepts images, PDF and text files only.';

  @override
  String get imagePickerPending =>
      'Changing your photo isn’t available in the app yet — it needs an image picker. The WorkFlow API already accepts the upload.';

  @override
  String get conversationCreateUnavailable =>
      'Starting a conversation isn’t connected to the WorkFlow API yet — this form only works in demo mode.';

  @override
  String get meetingTimeInPast => 'Choose a date and time that haven’t passed';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmBody =>
      'Your WorkFlow account and its data will be permanently deleted. This can’t be undone.';

  @override
  String get employeeDeleteUnavailable =>
      'Employee accounts are closed by your company admin — the WorkFlow API doesn’t let employees delete their own account.';

  @override
  String get tipEmoji => 'Emoji';

  @override
  String get tipAttachFile => 'Attach a file';

  @override
  String get tipAttachImage => 'Attach an image';

  @override
  String get tipVoice => 'Voice message';

  @override
  String get tipSend => 'Send message';

  @override
  String get noConversationsYet => 'No conversations yet.';

  @override
  String get noMeetingsYet => 'No meetings yet.';

  @override
  String get underReview => 'Under Review';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldHours => 'Hours';

  @override
  String get fieldRate => 'Rate';

  @override
  String get wrongPortalClient =>
      'This account isn\'t a client account. Go back and choose Employee.';

  @override
  String get wrongPortalEmployee =>
      'This account isn\'t an employee account. Go back and choose Client.';

  @override
  String get myCompaniesNote =>
      'Companies linked to your account. The server doesn\'t report your membership status or list companies you could join yet.';

  @override
  String get noCompaniesYet => 'Your account isn\'t linked to any company yet.';

  @override
  String get runningLabel => 'Running';

  @override
  String get viewAllLabel => 'View All';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortDueSoonest => 'Due date';

  @override
  String get sortHighestAmount => 'Highest amount';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get paymentRowsNote =>
      'Payments as the server lists them. It doesn\'t report a payment\'s status or currency on each row, so the status filter and the totals above come from the server.';
}
