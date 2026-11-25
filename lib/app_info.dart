import 'package:material_ui/material_ui.dart';

/// App identity: «فارس وفهد للحسابات» — brand mark FF.
/// فارس للثقة، فهد للسرعة.
/// Official logo (user-provided, never AI-generated): assets/logo.jpg
/// (full logo with the name underneath, kept for the PDF statement)
/// and assets/logo_mark.png (the emblem only, for the app icon).
/// In-app brand images (user-provided, transparent PNG, 2026-11-24):
/// assets/logo_header.png (full logo with the text, for the welcome
/// card, the login screen and the loading screen) and
/// assets/logo_symbol.png (the emblem only, for the small AppBar mark).
const String appName = 'فارس وفهد للحسابات';
const String appBrand = 'FF';
const String appTagline = 'فارس للثقة، فهد للسرعة';

/// سطر الحقوق الموحد (للواجهة ورسائل واتساب — خط Cairo يعرض ©).
const String appRightsLine =
    'جميع الحقوق محفوظة © فارس وفهد للحسابات';

/// سطر الحقوق لملف PDF: خط Noto Naskh Arabic المضمّن في الكشف لا
/// يحتوي رمز © (ولا '-' ولا '–') فيُعرض كمربع فارغ، فتُستبدل
/// الصيغة هنا بصيغة حروف عربية فقط — متحقق من خريطة الحروف
/// (cmap) للخطين العادي والعريض بـ fontTools.
const String appRightsLinePdf =
    'جميع الحقوق محفوظة لفارس وفهد للحسابات';

/// صفحة الإصدارات الدائمة على GitHub — تشير دائماً إلى أحدث
/// إصدار، فيصلح رمز QR المطبوع في كشف PDF لكل النسخ القادمة
/// بلا تغيير. الرابط نفسه لا يُطبع نصاً في PDF لأن خطه لا
/// يحتوي '-' و'/'.
const String appReleasesUrl =
    'https://github.com/shifa-app/fares-fahd-ledger/releases/latest';
const String logoAsset = 'assets/logo.jpg';
const String logoMarkAsset = 'assets/logo_mark.png';
const String logoHeaderAsset = 'assets/logo_header.png';
const String logoSymbolAsset = 'assets/logo_symbol.png';

/// 3D gold/blue quick-action icons (user-provided 3×3 grid, cropped
/// 2026-11-25; each sits on the flat navy #0D1726 of its container,
/// so no transparency work is needed). Wallet = new transaction,
/// chart = reports, people = persons/clients.
const String iconWalletAsset = 'assets/icon_wallet.png';
const String iconChartAsset = 'assets/icon_chart.png';
const String iconPeopleAsset = 'assets/icon_people.png';

/// Brand colors — visual identity guide approved by the user (2026-11-24):
/// primary navy #0D1726, accent gold #D4AF37, background #F4F6F9,
/// success text #16A34A on #DCFCE7, danger text #DC2626 on #FEE2E2.
class BrandColors {
  static const Color navy = Color(0xFF0D1726);
  static const Color navyDark = Color(0xFF070D18);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE3C766);
  static const Color brandBlue = Color(0xFF2E7FC2);
  static const Color brandBlueLight = Color(0xFF7FB8E8);

  /// App background (snow grey).
  static const Color background = Color(0xFFF4F6F9);

  /// Inflow / «له» — green text on very light green.
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);

  /// Outflow / «عليه» — balanced red text on very light red.
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
}
