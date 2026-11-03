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
}
