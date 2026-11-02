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
}
