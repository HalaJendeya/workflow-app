// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'WorkFlow';

  @override
  String get portalClient => 'عميل';

  @override
  String get portalEmployee => 'موظف';

  @override
  String get designPendingTitle => 'التصميم قيد الانتظار';

  @override
  String get designPendingBody =>
      'سيتم بناء هذه الشاشة وفق تصميم Figma الرسمي بعد منح صلاحية الوصول إلى الملف.';

  @override
  String get demoModeBanner => 'بيانات تجريبية — لا يتم حفظ أي شيء على الخادم';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get emptyState => 'لا يوجد شيء هنا بعد';

  @override
  String get errorNetwork => 'تعذر الوصول إلى الخادم. تحقق من اتصالك.';

  @override
  String get errorSessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errorForbidden => 'ليست لديك صلاحية الوصول إلى هذا.';

  @override
  String get errorNotFound => 'هذا العنصر لم يعد موجودًا.';

  @override
  String get errorValidation => 'يرجى مراجعة الحقول المحددة.';

  @override
  String errorRateLimited(int seconds) {
    return 'محاولات كثيرة جدًا. حاول مرة أخرى بعد $seconds ثانية.';
  }

  @override
  String get errorServer => 'حدث خطأ من جهتنا. يرجى المحاولة مرة أخرى.';

  @override
  String get errorUnknown => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get accountTypeTitle => 'نوع الحساب';

  @override
  String get accountTypeClientTitle => 'عميل';

  @override
  String get accountTypeClientBody => 'أبحث عن شركات لتنفيذ مشاريعي';

  @override
  String get accountTypeEmployeeTitle => 'موظف';

  @override
  String get accountTypeEmployeeBody => 'أدير المشاريع وأتعامل مع العملاء';

  @override
  String get next => 'التالي';

  @override
  String get noAccountPrompt => 'ليس لديك حساب؟';

  @override
  String get createClientAccount => 'إنشاء حساب عميل';

  @override
  String get loginWelcome => 'مرحبًا ';

  @override
  String get loginWelcomeAccent => 'بعودتك!';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get emailHint => 'example123@gmail.com';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordHint => 'أدخل كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get signUpPrompt => 'ليس لديك حساب؟';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get registerTitleLead => 'إنشاء ';

  @override
  String get registerTitleAccent => 'حساب';

  @override
  String get registerSubtitle => 'تسجيل';

  @override
  String get userNameLabel => 'اسم المستخدم';

  @override
  String get userNameHint => 'محمود علي';

  @override
  String get agreeTermsLead => 'أوافق على ';

  @override
  String get agreeTermsTerms => 'الشروط';

  @override
  String get agreeTermsAnd => ' و';

  @override
  String get agreeTermsConditions => 'الأحكام';

  @override
  String get signInButton => 'تسجيل';

  @override
  String get haveAccountPrompt => 'لديك حساب بالفعل؟';

  @override
  String get loginLink => 'تسجيل الدخول';

  @override
  String get forgotTitle => 'نسيت كلمة المرور؟';

  @override
  String get forgotBody =>
      'أدخل بريدك الإلكتروني المسجل وسنرسل لك رمزًا لإعادة تعيين كلمة المرور.';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get verifyTitle => 'رمز التحقق';

  @override
  String verifyBody(int length, String email) {
    return 'أرسلنا رمزًا مكونًا من $length أرقام إلى ($email)';
  }

  @override
  String get verifyButton => 'تحقق';

  @override
  String get noCodePrompt => 'لم يصلك الرمز؟';

  @override
  String get resend => 'إعادة الإرسال';

  @override
  String get codeResent => 'تم إرسال رمز جديد.';

  @override
  String get newPasswordTitle => 'إنشاء كلمة مرور جديدة';

  @override
  String get newPasswordBody =>
      'يجب أن تختلف كلمة المرور الجديدة عن كلمات المرور السابقة.';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get save => 'حفظ';

  @override
  String get successAccountTitle => 'تم إنشاء الحساب بنجاح!';

  @override
  String get successAccountBody =>
      'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة.';

  @override
  String get successPasswordTitle => 'تم تحديث كلمة المرور بنجاح!';

  @override
  String get validationRequired => 'هذا الحقل مطلوب';

  @override
  String get validationEmail => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String validationPasswordMin(int min) {
    return 'استخدم $min أحرف على الأقل';
  }

  @override
  String get validationPasswordMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get validationOtp => 'أدخل الرمز كاملًا';

  @override
  String get validationTerms => 'يرجى الموافقة على الشروط والأحكام';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCompanies => 'الشركات';

  @override
  String get navInvoices => 'الفواتير';

  @override
  String get navChat => 'المحادثات';

  @override
  String get navMore => 'المزيد';

  @override
  String get overviewBreadcrumb => 'نظرة عامة';

  @override
  String welcomeBackName(String name) {
    return 'مرحبًا بعودتك، $name';
  }

  @override
  String get welcomeBack => 'مرحبًا بعودتك';

  @override
  String get searchHint => 'بحث....';

  @override
  String get tasksTitle => 'المهام';

  @override
  String tasksFilterProjects(int count) {
    return 'المشاريع $count';
  }

  @override
  String get tasksFilterMeetings => 'الاجتماعات';

  @override
  String get tasksFilterGeneral => 'عام';

  @override
  String get addMicroTask => 'إضافة مهمة شخصية صغيرة';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String notificationsFilterAll(int count) {
    return 'الكل $count';
  }

  @override
  String get notificationsFilterMentions => 'الإشارات';

  @override
  String get notificationsFilterProjects => 'المشاريع';

  @override
  String get markAllRead => 'تعليم الكل كمقروء';

  @override
  String get notificationStatusTitle => 'عرض';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterUnread => 'غير مقروء';

  @override
  String get filterRead => 'مقروء';

  @override
  String get featureUnavailable =>
      'هذا القسم غير متاح بعد — واجهة WorkFlow البرمجية لا توفره.';

  @override
  String get roleClient => 'عميل';

  @override
  String get roleEmployee => 'موظف';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get navTasks => 'المهام';

  @override
  String get navProjects => 'المشاريع';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String get notificationsEmpty => 'لا توجد إشعارات جديدة';

  @override
  String get noResults => 'لا توجد نتائج مطابقة لبحثك';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get create => 'إنشاء';

  @override
  String get cancel => 'إلغاء';

  @override
  String get deleteTitle => 'حذف السجل؟';

  @override
  String deleteBody(String what) {
    return 'سيتم حذف $what من هذا الجهاز.';
  }

  @override
  String get backendPending =>
      'هذا القسم جاهز لواجهة WorkFlow البرمجية الجديدة. ستظهر البيانات هنا بعد أن ينشر فريق الخادم نقاط الاتصال.';

  @override
  String get selectHint => 'اختر';

  @override
  String get validationNumber => 'أدخل رقمًا صحيحًا';

  @override
  String get savedLocally =>
      'تم الحفظ على هذا الجهاز (تجريبي) — لم يُرسل إلى الخادم بعد.';

  @override
  String get deletedLocally => 'تم الحذف من هذا الجهاز (تجريبي).';

  @override
  String get exportReport => 'تصدير التقرير';

  @override
  String get exportPending => 'سيتوفر التصدير عندما يدعمه الخادم.';

  @override
  String get noRecords => 'لا توجد سجلات مطابقة لهذه الفلاتر';

  @override
  String get vsLastMonth => 'مقارنة بالشهر الماضي';

  @override
  String get invoicesTitle => 'إدارة الفواتير';

  @override
  String get invoicesDescription =>
      'تتبّع فواتير العملاء وأدرها وعالجها لجميع الشركات المسجلة.';

  @override
  String get searchInvoicesHint => 'ابحث في الفواتير أو الشركة أو العميل...';

  @override
  String get metricTotalInvoices => 'إجمالي الفواتير';

  @override
  String get metricPaid => 'مدفوعة';

  @override
  String get metricOverdue => 'متأخرة';

  @override
  String get filterAllStatus => 'كل الحالات';

  @override
  String get filterAllCompanies => 'كل الشركات';

  @override
  String get filterAllMethods => 'كل الطرق';

  @override
  String get rangeLast30 => 'آخر 30 يومًا';

  @override
  String get rangeLast90 => 'آخر 90 يومًا';

  @override
  String get rangeThisYear => 'هذا العام';

  @override
  String get rangeAll => 'كل الأوقات';

  @override
  String get statusPaid => 'مدفوعة';

  @override
  String get statusOverdue => 'متأخرة';

  @override
  String get statusDraft => 'مسودة';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusInProgress => 'قيد التنفيذ';

  @override
  String get fieldClient => 'العميل';

  @override
  String get fieldProject => 'المشروع';

  @override
  String get fieldIssueDate => 'تاريخ الإصدار';

  @override
  String get fieldCompany => 'الشركة';

  @override
  String get fieldCurrency => 'العملة';

  @override
  String get fieldAmount => 'المبلغ';

  @override
  String get fieldInvoiceDate => 'تاريخ الفاتورة';

  @override
  String get fieldDueDate => 'تاريخ الاستحقاق';

  @override
  String get fieldStatus => 'الحالة';

  @override
  String get fieldMethod => 'الطريقة';

  @override
  String get fieldWallet => 'المحفظة';

  @override
  String get fieldInvoice => 'الفاتورة';

  @override
  String get fieldEmployee => 'الموظف';

  @override
  String get fieldPaymentMethod => 'طريقة الدفع';

  @override
  String get fieldPaymentDate => 'تاريخ الدفع';

  @override
  String get fieldNotes => 'ملاحظات';

  @override
  String get createInvoice => 'إنشاء فاتورة';

  @override
  String get editInvoice => 'تعديل الفاتورة';

  @override
  String get addPayment => 'إضافة دفعة';

  @override
  String get editPayment => 'تعديل الدفعة';

  @override
  String get paymentsTitle => 'سجلات الدفع';

  @override
  String get paymentsDescription =>
      'تتبّع جميع المعاملات الواردة والصادرة وأدرها ودقّقها.';

  @override
  String get searchPaymentsHint => 'ابحث بالفاتورة أو الشركة أو الطريقة...';

  @override
  String get metricTotalRevenue => 'إجمالي الإيرادات';

  @override
  String get metricPendingPayments => 'مدفوعات معلقة';

  @override
  String get metricTransactionVolume => 'حجم المعاملات';

  @override
  String invoicesAwaiting(int count) {
    return '$count فواتير بانتظار التسوية';
  }

  @override
  String get directionIncoming => 'واردة';

  @override
  String get directionOutgoing => 'صادرة';

  @override
  String get companiesTitle => 'الشركات المتاحة';

  @override
  String get companiesDescription => 'استكشف مساحات العمل واطلب الانضمام';

  @override
  String get joinRequest => 'طلب انضمام';

  @override
  String get joinPending => 'قيد الانتظار';

  @override
  String joinRequestSent(String name) {
    return 'تم إرسال طلب الانضمام إلى $name (تجريبي).';
  }

  @override
  String get categoriesTitle => 'الأقسام';

  @override
  String get categoriesDescription =>
      'استكشف جميع وحدات مساحة العمل والأقسام الرئيسية';

  @override
  String get catOverview => 'نظرة عامة';

  @override
  String get catOverviewBody => 'المؤشرات الرئيسية ولوحات المتابعة والتقارير';

  @override
  String get catDashboard => 'لوحة المتابعة';

  @override
  String get catClients => 'العملاء والاشتراكات';

  @override
  String get catClientsBody => 'حسابات المؤسسات والاتفاقيات والطلبات';

  @override
  String get catFinance => 'المالية';

  @override
  String get catFinanceBody => 'إدارة الحسابات والمصروفات والمدفوعات';

  @override
  String get catPayments => 'المدفوعات';

  @override
  String get catWork => 'العمل والمشاريع';

  @override
  String get catWorkBody => 'المهام والدورات الرشيقة وأدوات الهندسة';

  @override
  String get catCommunication => 'التواصل';

  @override
  String get catCommunicationBody =>
      'المحادثات المباشرة واجتماعات الفريق الافتراضية';

  @override
  String get catConversations => 'المحادثات';

  @override
  String get catMeetings => 'الاجتماعات';

  @override
  String get accountMenu => 'الحساب';

  @override
  String get projectsTitle => 'إدارة المشاريع';

  @override
  String get projectsDescription =>
      'نظرة عامة على جميع المبادرات الحالية والسابقة.';

  @override
  String get searchProjectsHint => 'ابحث في المشاريع أو العميل أو الفريق...';

  @override
  String get metricTotalProjects => 'إجمالي المشاريع';

  @override
  String get filterAllClients => 'كل العملاء';

  @override
  String get listView => 'عرض القائمة';

  @override
  String get cardView => 'عرض البطاقات';

  @override
  String get statusOnHold => 'معلّق';

  @override
  String get fieldBudget => 'الميزانية';

  @override
  String get fieldProgress => 'التقدم';

  @override
  String get fieldTeam => 'الفريق';

  @override
  String get fieldTimeline => 'المدة';

  @override
  String daysLeft(int count) {
    return 'متبقٍ $count يوم';
  }

  @override
  String get moreActions => 'إجراءات إضافية';

  @override
  String get createNewProject => 'إنشاء مشروع جديد';

  @override
  String get createNewProjectBody =>
      'عيّن أعضاء الفريق وحدد المراحل وتابع الميزانيات';

  @override
  String get addProject => 'إضافة مشروع';

  @override
  String get editProject => 'تعديل المشروع';

  @override
  String get fieldProjectTitle => 'عنوان المشروع';

  @override
  String get fieldEmployees => 'الموظفون';

  @override
  String get newConversation => 'محادثة جديدة';

  @override
  String get filterDirect => 'مباشرة';

  @override
  String get filterTeams => 'الفرق والقنوات';

  @override
  String unreadCount(int count) {
    return '$count غير مقروءة';
  }

  @override
  String get you => 'أنت';

  @override
  String get callsPending => 'ستتوفر المكالمات عندما تجهز خدمة الاجتماعات.';

  @override
  String get call => 'اتصال';

  @override
  String get videoCall => 'مكالمة فيديو';

  @override
  String get conversationInfo => 'معلومات المحادثة';

  @override
  String get groupChat => 'محادثة جماعية';

  @override
  String get privateChat => 'محادثة خاصة';

  @override
  String get participants => 'المشاركون';

  @override
  String membersCount(int count) {
    return '$count أعضاء';
  }

  @override
  String get activeNow => 'نشط الآن';

  @override
  String get messageHint => 'اكتب رسالة أو اضغط \'/\' للأوامر...';

  @override
  String get attachmentsPending =>
      'المرفقات غير متاحة في التطبيق بعد — تحتاج أداة لاختيار الملفات. واجهة WorkFlow تقبل الصور وملفات PDF والنصوص.';

  @override
  String get delivered => 'تم التسليم';

  @override
  String get newConversationTitle => 'إنشاء محادثة جديدة';

  @override
  String get newConversationBody => 'اختر النوع والمشاركين';

  @override
  String get conversationType => 'نوع المحادثة';

  @override
  String get typeGroup => 'مجموعة';

  @override
  String get typeDirect => 'مباشرة';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get groupPicture => 'صورة المجموعة';

  @override
  String get chooseFile => 'اختر ملفًا';

  @override
  String get noFileChosen => 'لم يتم اختيار ملف';

  @override
  String get selectParticipants => 'اختر عدة أشخاص لإنشاء مجموعة.';

  @override
  String get selectOnePerson => 'اختر شخصًا واحدًا لبدء محادثة مباشرة.';

  @override
  String get searchConversationsHint => 'ابحث في المحادثات...';

  @override
  String get createGroup => 'إنشاء المجموعة';

  @override
  String get startChat => 'بدء المحادثة';

  @override
  String get meetingsTitle => 'إدارة الاجتماعات';

  @override
  String get meetingsDescription =>
      'جدولة الاجتماعات وإدارتها والانضمام إليها عبر جميع الشركات';

  @override
  String get scheduleMeeting => 'جدولة اجتماع';

  @override
  String get joinByCode => 'انضمام بالرمز';

  @override
  String get meetingOverview => 'نظرة عامة على الاجتماعات';

  @override
  String get totalMeetings => 'إجمالي الاجتماعات';

  @override
  String get liveNow => 'مباشر الآن';

  @override
  String activeCount(int count) {
    return '$count نشط';
  }

  @override
  String get meetingScheduled => 'مجدول';

  @override
  String get meetingLive => 'مباشر';

  @override
  String get meetingWaiting => 'بالانتظار';

  @override
  String get meetingEnded => 'منتهٍ';

  @override
  String get meetingsCalendar => 'تقويم الاجتماعات';

  @override
  String timezoneLabel(String zone) {
    return 'المنطقة الزمنية: $zone';
  }

  @override
  String get todaysMeetings => 'اجتماعات اليوم';

  @override
  String get noMeetingsThisDay => 'لا توجد اجتماعات في هذا اليوم';

  @override
  String get upcomingMeetings => 'الاجتماعات القادمة';

  @override
  String get searchMeetingsHint => 'ابحث في الاجتماعات أو الشركات أو الرمز...';

  @override
  String get codeTypeParticipants => 'الرمز · النوع · المشاركون';

  @override
  String get details => 'التفاصيل';

  @override
  String get detailsBody => 'سجلات الجلسة ومعايير الاجتماع';

  @override
  String get meetingId => 'معرّف الاجتماع';

  @override
  String get fieldType => 'النوع';

  @override
  String get scheduledAt => 'موعد الجدولة';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get public => 'عام';

  @override
  String get private => 'خاص';

  @override
  String get startedAt => 'بدأ في';

  @override
  String get endedAt => 'انتهى في';

  @override
  String get duration => 'المدة';

  @override
  String minutes(int count) {
    return '$count دقيقة';
  }

  @override
  String get createdBy => 'أنشأه';

  @override
  String get peakParticipants => 'ذروة المشاركين';

  @override
  String get maxParticipants => 'الحد الأقصى للمشاركين';

  @override
  String get features => 'الميزات';

  @override
  String get description => 'الوصف';

  @override
  String get invitationRequired => 'دعوة مطلوبة';

  @override
  String get invitationRequiredBody =>
      'هذا الاجتماع بالدعوة فقط. اطلب من المضيف دعوتك.';

  @override
  String peakOf(int peak, int max) {
    return 'الذروة $peak من $max مسموح.';
  }

  @override
  String get refreshList => 'تحديث القائمة';

  @override
  String get listUpToDate => 'القائمة محدّثة.';

  @override
  String get user => 'مستخدم';

  @override
  String get host => 'المضيف';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'غير متصل';

  @override
  String invitationsCount(int count) {
    return 'الدعوات ($count)';
  }

  @override
  String get invitationsBody => 'يمكن دعوة أعضاء الشركة والعملاء المعتمدين.';

  @override
  String get inviteParticipant => 'دعوة مشارك';

  @override
  String get noInvitations => 'لم تُرسل أي دعوات بعد';

  @override
  String get noInvitationsBody =>
      'استخدم النموذج أعلاه أو اضغط دعوة لإضافة مشاركين إلى هذه الجلسة.';

  @override
  String get featureChat => 'الدردشة';

  @override
  String get featureScreen => 'الشاشة';

  @override
  String get featureWhiteboard => 'السبورة';

  @override
  String get featureFiles => 'الملفات';

  @override
  String get scheduleMeetingTitle => 'جدولة اجتماع جديد';

  @override
  String get editMeeting => 'تعديل الاجتماع';

  @override
  String get scheduleMeetingBody =>
      'جهّز تعاونًا مرئيًا سلسًا مع فريقك أو عملائك';

  @override
  String get stepDateTime => '1 - اختر التاريخ والوقت';

  @override
  String get stepDateTimeBody => 'اختر تاريخ الاجتماع والوقت المتاح';

  @override
  String get availableTimes => 'الأوقات المتاحة';

  @override
  String get inviteDispatchNote =>
      'سيتم إرسال رابط الاجتماع وملفات التقويم تلقائيًا لجميع المشاركين المؤكدين.';

  @override
  String get stepDetails => '2 - تفاصيل الاجتماع';

  @override
  String get stepDetailsBody => 'أدخل جدول الأعمال ومواصفات الاجتماع';

  @override
  String get meetingTitle => 'عنوان الاجتماع';

  @override
  String get agenda => 'الوصف وجدول الأعمال';

  @override
  String get meetingType => 'نوع الاجتماع';

  @override
  String get onlineVideoMeeting => 'اجتماع فيديو عبر الإنترنت';

  @override
  String get meetingStatus => 'حالة الاجتماع';

  @override
  String get companyClient => 'الشركة / العميل';

  @override
  String get stepParticipants => '3 - المشاركون ووصول الضيوف';

  @override
  String get stepParticipantsBody => 'أضف أعضاء الفريق أو ادعُ بريدًا خارجيًا';

  @override
  String get searchEmployeesHint => 'ابحث عن الموظفين بالاسم أو اكتب بريدًا...';

  @override
  String get addExternal => 'إضافة خارجي';

  @override
  String get collaborationFeatures => 'ميزات التعاون أثناء الاجتماع';

  @override
  String get encryptedRoom => 'غرفة فيديو مشفّرة بالكامل جاهزة';

  @override
  String get joinByCodeTitle => 'انضمام بالرمز';

  @override
  String get meetingCode => 'رمز الاجتماع';

  @override
  String get roomPassword => 'كلمة مرور الغرفة (اختياري)';

  @override
  String get joinMeeting => 'انضمام للاجتماع';

  @override
  String get meetingNotFound => 'لا يوجد اجتماع بهذا الرمز.';

  @override
  String get minimize => 'تصغير';

  @override
  String peopleCount(int count) {
    return '$count أشخاص';
  }

  @override
  String get polls => 'الاستطلاعات';

  @override
  String get notes => 'الملاحظات';

  @override
  String get mute => 'كتم';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get camera => 'الكاميرا';

  @override
  String get raiseHand => 'رفع اليد';

  @override
  String get reactions => 'التفاعلات';

  @override
  String get moreOptions => 'خيارات أخرى';

  @override
  String get leave => 'مغادرة';

  @override
  String get micMuted => 'الميكروفون مكتوم';

  @override
  String get mediaPending => 'يتصل الصوت والفيديو عند توفر خدمة الاجتماعات.';

  @override
  String meetingStartedAt(String time) {
    return 'بدأ الاجتماع في $time';
  }

  @override
  String get messageParticipantsHint => 'اكتب رسالة للمشاركين...';

  @override
  String get livePoll => 'استطلاع مباشر';

  @override
  String votesCount(int count) {
    return '$count أصوات';
  }

  @override
  String get tapToVote => 'اضغط على خيار للتصويت';

  @override
  String votedAs(String name) {
    return 'صوّت باسم: $name';
  }

  @override
  String get noteTitleHint => 'عنوان الملاحظة...';

  @override
  String get noteBodyHint => 'اكتب ملاحظات الاجتماع هنا...';

  @override
  String get saveNote => 'حفظ الملاحظة';

  @override
  String get muteAll => 'كتم الجميع';

  @override
  String get participant => 'مشارك';

  @override
  String get encryptedMeeting => 'اجتماع مشفّر بالكامل';

  @override
  String get navSprints => 'الدورات';

  @override
  String get timesheetsShort => 'سجلات الدوام';

  @override
  String get priorityLow => 'منخفضة';

  @override
  String get priorityMedium => 'متوسطة';

  @override
  String get priorityHigh => 'عالية';

  @override
  String get priorityUrgent => 'عاجلة';

  @override
  String get backlog => 'قائمة الانتظار';

  @override
  String get toDo => 'للتنفيذ';

  @override
  String get taskCode => 'المهمة';

  @override
  String get priority => 'الأولوية';

  @override
  String get startDate => 'تاريخ البدء';

  @override
  String get endDate => 'تاريخ الانتهاء';

  @override
  String get tasksManagement => 'إدارة المهام';

  @override
  String get tasksManagementBody =>
      'نظرة عامة وإدارة لجميع المهام النشطة عبر المشاريع';

  @override
  String get addTask => 'إضافة مهمة';

  @override
  String get editTask => 'تعديل المهمة';

  @override
  String get activeTasks => 'المهام النشطة';

  @override
  String get completionVelocity => 'سرعة الإنجاز الإجمالية';

  @override
  String get totalBudgetUtilization => 'إجمالي استخدام الميزانية';

  @override
  String get budgetAllocations => 'مجموع المعدل × التخصيصات';

  @override
  String get loggedHours => 'الساعات المسجلة';

  @override
  String get hoursThisPeriod => 'الساعات المسجلة في هذه الفترة';

  @override
  String get searchTasksHint => 'ابحث بعنوان المهمة أو المشروع أو الموظف...';

  @override
  String get allProjects => 'كل المشاريع';

  @override
  String get allAssignees => 'كل المكلّفين';

  @override
  String get priorityLevel => 'مستوى الأولوية';

  @override
  String get view => 'عرض';

  @override
  String showingRange(int from, int to, int total) {
    return 'عرض $from–$to من $total';
  }

  @override
  String get taskTitle => 'عنوان المهمة';

  @override
  String get assignee => 'المكلّف';

  @override
  String get storyPoints => 'نقاط القصة';

  @override
  String get taskDate => 'تاريخ المهمة';

  @override
  String get sprintBacklog => 'الدورة وقائمة الانتظار';

  @override
  String get sprintBacklogBody =>
      'أدر قائمة المنتج ووزّع الموارد وتابع أداء الدورة.';

  @override
  String get kanban => 'كانبان';

  @override
  String get createSprint => 'إنشاء دورة';

  @override
  String get sprintName => 'اسم الدورة';

  @override
  String get noTasksInColumn => 'لا توجد مهام في هذا العمود';

  @override
  String points(int count) {
    return '$count نقاط';
  }

  @override
  String subtasksDone(int done, int total) {
    return 'المهام الفرعية: $done/$total منجزة';
  }

  @override
  String get moveTo => 'نقل إلى';

  @override
  String get approved => 'معتمد';

  @override
  String get rejected => 'مرفوض';

  @override
  String get timesheetsTitle => 'لوحة سجلات الدوام';

  @override
  String get timesheetsBody =>
      'راجع الساعات المسجلة والموافقات والمستحقات عبر المشاريع';

  @override
  String get totalHours => 'إجمالي الساعات';

  @override
  String get totalSalaries => 'إجمالي الرواتب';

  @override
  String get searchTimesheetsHint => 'ابحث في المهمة أو المشروع أو الموظف...';

  @override
  String get accountId => 'معرّف الحساب';

  @override
  String achievedValue(int count, int percent) {
    return '$count · تم إنجاز $percent%';
  }

  @override
  String get activeClientProjects => 'مشاريع العميل النشطة والمخرجات';

  @override
  String get activeHub => 'مركز نشط';

  @override
  String get activeInSprint => 'نشطة في السبرنت';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get changePasswordBody => 'حدّث كلمة مرور حسابك للحفاظ على الأمان.';

  @override
  String get completedMilestones => 'المراحل المكتملة';

  @override
  String get confirmDeletion => 'أؤكد الحذف';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get contractBudget => 'ميزانية العقد';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get dangerZone => 'منطقة الخطر';

  @override
  String get dashboardBody =>
      'نظرة عامة على مشاريعك وفواتيرك والشركات المرتبطة.';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountBody =>
      'إزالة حسابك وجميع البيانات المرتبطة به نهائيًا.';

  @override
  String get deleteAccountWarning =>
      'هل أنت متأكد من حذف حسابك؟ لا يمكن التراجع عن هذا الإجراء. ستُمحى جميع مشاريعك وملفاتك وإعداداتك من خوادمنا نهائيًا وفورًا.';

  @override
  String get deletionIrreversible =>
      'أدرك أنه لا يمكن استعادة بياناتي بعد هذه الخطوة.';

  @override
  String get deliverableBreakdown => 'تفصيل تقدّم المخرجات';

  @override
  String get downloadReceipt => 'تنزيل الإيصال';

  @override
  String efficiencyDelta(String delta) {
    return 'كفاءة $delta';
  }

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get expenditureTrends => 'اتجاهات الإنفاق والفوترة';

  @override
  String get expenditureTrendsBody => 'وتيرة الإنفاق وتسليم الفواتير المعتمدة';

  @override
  String get filterStatus => 'تصفية الحالة';

  @override
  String get financialSummary => 'الملخص المالي ورصيد الضمان';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String inDevValue(int count, int percent) {
    return '$count · $percent% قيد التطوير';
  }

  @override
  String get invoicedSeries => 'المفوتر (\$)';

  @override
  String get issueDate => 'تاريخ الإصدار';

  @override
  String get keepProfileUpToDate => 'حافظ على ملفك الشخصي محدّثًا';

  @override
  String get keepProfileUpToDateBody =>
      'يساعدنا الملف المكتمل على خدمتك بشكل أفضل.';

  @override
  String kpisTracked(int count) {
    return '$count مؤشرات متابَعة • المخرجات والمؤشرات الرئيسية';
  }

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get latestInvoices => 'أحدث الفواتير والإيصالات';

  @override
  String get milestoneVelocity => 'المخرجات وسرعة إنجاز المراحل';

  @override
  String milestonesTotal(int count) {
    return 'إجمالي المراحل $count';
  }

  @override
  String get monthlyRevenue => 'الإيراد الشهري';

  @override
  String get newMilestoneRequest => 'طلب مرحلة جديدة';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get onSchedule => 'ضمن الجدول';

  @override
  String get overviewMetrics => 'نظرة عامة ومؤشرات';

  @override
  String get passwordChanged => 'تم تحديث كلمة المرور';

  @override
  String get passwordRule =>
      'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل وتتضمن أحرفًا وأرقامًا ورموزًا.';

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String peakValue(String label, String amount) {
    return 'الذروة $label: $amount';
  }

  @override
  String get pendingReview => 'بانتظار المراجعة';

  @override
  String percentItems(int percent, int count) {
    return '$percent% ($count عناصر)';
  }

  @override
  String get periodDay => 'يوم';

  @override
  String get periodMonth => 'شهر';

  @override
  String get periodWeek => 'أسبوع';

  @override
  String get periodYear => 'سنة';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get profileDetails => 'تفاصيل الملف الشخصي';

  @override
  String get profileDetailsBody => 'أدِر معلوماتك الشخصية وتفضيلاتك.';

  @override
  String get profileSaved => 'تم تحديث الملف الشخصي';

  @override
  String queuedValue(int count, int percent) {
    return '$count · $percent% في الانتظار';
  }

  @override
  String get realtimeOverview => 'نظرة فورية على الحالة';

  @override
  String recentCount(int count) {
    return '$count حديثة';
  }

  @override
  String revenueTarget(String amount, String percent) {
    return 'الهدف: $amount ($percent%)';
  }

  @override
  String get reviewQa => 'المراجعة وضمان الجودة';

  @override
  String roadmapValue(int count) {
    return '$count · خارطة الطريق';
  }

  @override
  String get roleLabel => 'الدور';

  @override
  String runningCount(int count) {
    return '$count قيد التنفيذ';
  }

  @override
  String get settledSeries => 'المسدد (\$)';

  @override
  String get targetDelivery => 'موعد التسليم المستهدف';

  @override
  String get totalSprints => 'إجمالي السبرنتات';

  @override
  String get uploadNewImage => 'رفع صورة جديدة';

  @override
  String get verifiedClientAccount => 'حساب عميل موثّق';

  @override
  String viewAllCount(int count) {
    return 'عرض الكل ($count)';
  }

  @override
  String get workAllocation => 'توزيع العمل والمهام';

  @override
  String get workOverview => 'نظرة على العمل';

  @override
  String get yourAccount => 'حسابك';

  @override
  String get employeeDashboardBody =>
      'نظرة سريعة على عملك وساعاتك وتقدّم السبرنت.';

  @override
  String get revenue => 'الإيرادات';

  @override
  String targetShort(String amount) {
    return 'الهدف $amount';
  }

  @override
  String tasksCount(int count) {
    return '+$count مهام';
  }

  @override
  String highPriorityCount(int count) {
    return '$count عالية الأولوية';
  }

  @override
  String get completedUpper => 'المكتملة';

  @override
  String velocityPercent(int percent) {
    return 'سرعة $percent%';
  }

  @override
  String weeklyPercent(int percent) {
    return '$percent% أسبوعيًا';
  }

  @override
  String get workingHoursTrend => 'ساعات العمل والاتجاه';

  @override
  String get hrsUnit => 'ساعة';

  @override
  String get currentWeek => 'الأسبوع الحالي';

  @override
  String get hoursVsTarget => 'الساعات اليومية المسجلة مقابل الهدف';

  @override
  String loggedLegend(String hours) {
    return 'المسجلة ($hours)';
  }

  @override
  String targetLegend(String hours) {
    return 'الهدف ($hours/يوم)';
  }

  @override
  String get dayMon => 'إثن';

  @override
  String get dayTue => 'ثلا';

  @override
  String get dayWed => 'أرب';

  @override
  String get dayThu => 'خمي';

  @override
  String get dayFri => 'جمع';

  @override
  String get daySat => 'سبت';

  @override
  String get daySun => 'أحد';

  @override
  String get avgDaily => 'المتوسط اليومي';

  @override
  String get focusRate => 'معدل التركيز';

  @override
  String get timesheetLabel => 'سجل الدوام';

  @override
  String get taskDistribution => 'توزيع المهام';

  @override
  String get taskDistributionBody => 'قائمة السبرنت الحالية وحالتها';

  @override
  String get allTasks => 'كل المهام';

  @override
  String get tasksUpper => 'مهام';

  @override
  String percentDone(int percent) {
    return '$percent% منجز';
  }

  @override
  String onTrackEta(int days) {
    return 'على المسار (متبقٍ $days يوم)';
  }

  @override
  String get activeTasksMilestones => 'المهام النشطة والمراحل';

  @override
  String get viewBacklog => 'عرض قائمة المهام';

  @override
  String percentComplete(int percent) {
    return '$percent% مكتمل';
  }

  @override
  String get revenueTrajectory => 'مسار الإيرادات';

  @override
  String get revenueTrajectoryBody => 'الأرباح مقابل الأهداف الشهرية';

  @override
  String yoyDelta(int percent) {
    return '+$percent% سنويًا';
  }

  @override
  String get actionNeedsBackend =>
      'لم يتم الحفظ: لا يوجد endpoint موثّق لهذا الإجراء على الخادم بعد.';

  @override
  String get statusUnpaid => 'غير مدفوعة';

  @override
  String get statusPartiallyPaid => 'مدفوعة جزئياً';

  @override
  String get fieldPaid => 'المدفوع';

  @override
  String get fieldRemaining => 'المتبقي';

  @override
  String get dashProjects => 'المشاريع';

  @override
  String get dashCompleted => 'المشاريع المكتملة';

  @override
  String get dashInProgress => 'المشاريع قيد التنفيذ';

  @override
  String get dashLiveOnly =>
      'يعرض الخادم أعداد المشاريع فقط؛ أما بقية أقسام اللوحة فتحتاج إلى ردّ موثّق من الخادم.';

  @override
  String get totalEarned => 'إجمالي المستحق';

  @override
  String get paidSalary => 'الراتب المدفوع';

  @override
  String get unpaidSalary => 'الراتب غير المدفوع';

  @override
  String get projectLeader => 'قائد المشروع';

  @override
  String get inReview => 'قيد المراجعة';

  @override
  String get meetingCancelled => 'ملغى';

  @override
  String get meetingTypeInstant => 'فوري';

  @override
  String get acceptInvitation => 'قبول';

  @override
  String get declineInvitation => 'رفض';

  @override
  String get invitationAccepted => 'تم قبول الدعوة.';

  @override
  String get invitationDeclined => 'تم رفض الدعوة.';

  @override
  String get myInvitations => 'دعواتي';

  @override
  String get yourInvitation => 'دعوتك';

  @override
  String get invitationStatusAccepted => 'مقبولة';

  @override
  String get invitationStatusDeclined => 'مرفوضة';

  @override
  String get invitationStatusExpired => 'منتهية';

  @override
  String invitedBy(String name) {
    return 'دعوة من $name';
  }

  @override
  String get meetingJoinUnavailable =>
      'الانضمام إلى اجتماع من التطبيق غير متاح بعد — لا توفر واجهة WorkFlow بحثاً عن الاجتماع برمزه، والتطبيق لا يتضمن عميل الوسائط LiveKit.';

  @override
  String get meetingCreateUnavailable =>
      'لا يمكن إنشاء اجتماعات من هذا الحساب — لا توفر واجهة WorkFlow مسار إنشاء لدورك.';

  @override
  String durationSeconds(int h, int m, int s) {
    return '$hس $mد $sث';
  }

  @override
  String calendarShowsLatest(int count) {
    return 'يعرض التقويم آخر $count اجتماع.';
  }

  @override
  String get noActiveSprint => 'لا يوجد سبرنت حالي لهذا المشروع.';

  @override
  String sprintPoints(int done, int total, int percent) {
    return '$done / $total نقطة · $percent%';
  }

  @override
  String get taskStatusUpdated => 'تم تحديث حالة المهمة.';

  @override
  String get sprintCreateUnavailable =>
      'لا يمكن إنشاء سبرنت من حساب موظف — لا توفر واجهة WorkFlow مسار إنشاء سبرنت لهذا الدور.';

  @override
  String backlogFirstPage(int shown, int total) {
    return 'عرض $shown من $total مهمة في الـ Backlog.';
  }

  @override
  String sprintsCount(int count) {
    return 'السبرنتات ($count)';
  }

  @override
  String get validationPositive => 'أدخل مبلغاً أكبر من 0';

  @override
  String get validationWholeNumber => 'أدخل عدداً صحيحاً';

  @override
  String get validationDueBeforeIssue =>
      'لا يمكن أن يسبق تاريخ الاستحقاق تاريخ الفاتورة';

  @override
  String get invoiceCreateUnavailable =>
      'لا يمكن إنشاء فواتير من هذا الحساب — لا توفر واجهة WorkFlow مسار إنشاء فاتورة للعملاء.';

  @override
  String get paymentCreateUnavailable =>
      'لا يمكن تسجيل دفعات من هذا الحساب — لا توفر واجهة WorkFlow مسار إنشاء دفعة للعملاء.';

  @override
  String get projectCreateUnavailable =>
      'لا يمكن إنشاء مشاريع من هذا الحساب — لا توفر واجهة WorkFlow مسار إنشاء مشروع لدورك.';

  @override
  String get taskCreateUnavailable =>
      'لا يمكن إنشاء مهام من هنا بعد — تقبل واجهة WorkFlow المهام الجديدة من قائد المشروع فقط، وهذا النموذج غير مربوط بها.';

  @override
  String get emojiUseKeyboard =>
      'استخدم زر الرموز التعبيرية في لوحة المفاتيح — لا يوجد في التطبيق منتقٍ للرموز بعد.';

  @override
  String get voiceNotSupported =>
      'الرسائل الصوتية غير مدعومة — تقبل واجهة WorkFlow الصور وملفات PDF والنصوص فقط.';

  @override
  String get imagePickerPending =>
      'تغيير الصورة غير متاح في التطبيق بعد — يحتاج أداة لاختيار الصور. واجهة WorkFlow تقبل الرفع.';

  @override
  String get conversationCreateUnavailable =>
      'بدء محادثة غير مربوط بواجهة WorkFlow بعد — هذا النموذج يعمل في الوضع التجريبي فقط.';

  @override
  String get meetingTimeInPast => 'اختر تاريخاً ووقتاً لم يمضيا';

  @override
  String get deleteAccountTitle => 'حذف حسابك؟';

  @override
  String get deleteAccountConfirmBody =>
      'سيُحذف حسابك في WorkFlow وبياناته نهائياً. لا يمكن التراجع عن ذلك.';

  @override
  String get employeeDeleteUnavailable =>
      'حسابات الموظفين يغلقها مسؤول الشركة — لا تسمح واجهة WorkFlow للموظف بحذف حسابه بنفسه.';

  @override
  String get tipEmoji => 'رموز تعبيرية';

  @override
  String get tipAttachFile => 'إرفاق ملف';

  @override
  String get tipAttachImage => 'إرفاق صورة';

  @override
  String get tipVoice => 'رسالة صوتية';

  @override
  String get tipSend => 'إرسال الرسالة';

  @override
  String get noConversationsYet => 'لا توجد محادثات بعد.';

  @override
  String get noMeetingsYet => 'لا توجد اجتماعات بعد.';

  @override
  String get underReview => 'قيد المراجعة';

  @override
  String get fieldDate => 'التاريخ';

  @override
  String get fieldHours => 'الساعات';

  @override
  String get fieldRate => 'السعر';

  @override
  String get wrongPortalClient => 'هذا الحساب ليس حساب عميل. ارجع واختر موظف.';

  @override
  String get wrongPortalEmployee =>
      'هذا الحساب ليس حساب موظف. ارجع واختر عميل.';

  @override
  String get myCompaniesNote =>
      'الشركات المرتبطة بحسابك. لا يوفّر الخادم بعد حالة عضويتك أو قائمة بالشركات التي يمكنك الانضمام إليها.';

  @override
  String get noCompaniesYet => 'حسابك غير مرتبط بأي شركة بعد.';

  @override
  String get runningLabel => 'قيد التنفيذ';

  @override
  String get viewAllLabel => 'عرض الكل';

  @override
  String get sortNewest => 'الأحدث أولاً';

  @override
  String get sortOldest => 'الأقدم أولاً';

  @override
  String get sortDueSoonest => 'تاريخ الاستحقاق';

  @override
  String get sortHighestAmount => 'المبلغ الأعلى';

  @override
  String get statusConfirmed => 'مؤكدة';

  @override
  String get paymentRowsNote =>
      'الدفعات كما يعرضها الخادم. لا يذكر الخادم حالة كل دفعة أو عملتها، لذا يأتي فلتر الحالة والمجاميع أعلاه من الخادم.';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get paymentSummaryTitle => 'ملخص الدفعة';

  @override
  String get paymentSummaryNote =>
      'من قائمة الدفعات. لا يوثّق الخادم بعد التفاصيل الكاملة للدفعة، لذا تظهر حقول القائمة هذه فقط.';
}
