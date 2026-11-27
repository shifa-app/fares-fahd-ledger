# PROJECT_HANDOVER.md — «فارس وفهد للحسابات»

> **مرجع التسليم الإلزامي.** أي مطور أو وكيل ذكاء اصطناعي يستلم هذا التطبيق
> مستقبلاً يلتزم بهذا الملف حرفياً. هدفه: عدم كسر أي ميزة محاسبية، عدم
> فقدان بيانات العملاء، وعدم تغيير الهوية البصرية الحالية.
>
> **تاريخ التوثيق:** 27 نوفمبر 2026 — **الإصدار الموثق:** 1.0.9+10
> (versionName ‏1.0.9، ‏versionCode ‏10).
> **المستودع:** https://github.com/shifa-app/fares-fahd-ledger — فرع `main`
> — حساب GitHub ‏**shifa-app فقط** (أي حساب آخر ممنوع تماماً).
> **آخر التزام على `main` وقت التوثيق:** `bf708782` (تصحيح مثيل Codemagic
> إلى `mac_mini_m2`) — يليه التزام 1.0.9 ‏`4765cf66`.
> **رابط النشر الدائم:** https://github.com/shifa-app/fares-fahd-ledger/releases/latest
> — والتحميل المباشر الدائم:
> https://github.com/shifa-app/fares-fahd-ledger/releases/latest/download/fares-fahd-ledger.apk
>
> **تصحيحات موثقة ضد مسودات قديمة (لا «تصححها» عكسياً):** الإصدار الحالي
> 1.0.9+10 لا 1.0.6+7، والاختبارات **78** لا 70، واسم التطبيق
> «فارس وفهد للحسابات» فقط بلا «والخدمات المالية»، والتنقل شريط سفلي
> بتبويبين بلا أي Drawer، والخط Cairo فقط بلا Tajawal.

---

## 1 — الهوية التقنية وإعدادات البناء (Tech Stack & Build Config)

### 1.1 التقنية والإصدارات (مقروءة من الكود الفعلي)

| البند | القيمة | المصدر |
|---|---|---|
| الإطار | Flutter 3.50.0 — قناة stable (المراجعة `ab2912035e`، بتاريخ 2026-11-09) | `flutter --version` على جهاز البناء |
| Dart SDK | `^3.14.0` | `pubspec.yaml` — `environment.sdk` |
| Gradle | 9.5.0 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 9.3.1 | `android/settings.gradle.kts` |
| Kotlin | 2.4.20 | `android/settings.gradle.kts` — `jvmTarget = JVM_17` في `android/app/build.gradle.kts` |
| Java | 17 | `compileOptions` + `java: 17` في Codemagic |
| Google Services plugin | 4.4.2 | `android/settings.gradle.kts` |
| flutter-plugin-loader | 1.0.0 | `android/settings.gradle.kts` |
| compileSdk / minSdk / targetSdk | **افتراضيات Flutter** — غير مكتوبة صراحةً: `flutter.compileSdkVersion` و`flutter.minSdkVersion` و`flutter.targetSdkVersion` | `android/app/build.gradle.kts` |
| اسم الحزمة | `com.faresfahd.ledger` | `namespace` + `applicationId` في `android/app/build.gradle.kts` |
| الإصدار | `version: 1.0.9+10` في `pubspec.yaml` (versionName ‏1.0.9، ‏versionCode ‏10) | `pubspec.yaml` |
| المنصة | Android فقط — لا iOS (مؤجل: لا حساب مطور مدفوع)، لا ويب، لا سطح مكتب | قرار المالك |

### 1.2 الاعتماديات (pubspec.yaml)

- `flutter` (SDK) — `material_ui: ^1.1.0` — `cupertino_icons: ^1.0.8`
- `sqflite: ^2.4.6` + `path: ^1.9.1` — قاعدة البيانات المحلية.
- `pdf: ^3.13.1` — كشف الحساب — `share_plus: ^13.3.1` — مشاركة النسخة والكشف.
- `url_launcher: ^6.3.3` — روابط واتساب — `intl: ^0.20.3` — `http: ^1.2.2`
- `google_sign_in: ^6.2.1` + `googleapis: ^14.0.0` — النسخة السحابية (Drive).
- `flutter_contacts: ^1.1.9+1` — استيراد رقم من جهات الاتصال (بإذن عند الاستخدام).
- `qr_flutter: ^4.1.0` — رمز QR لرابط الإصدارات في كشف PDF.
- dev: `flutter_test` (SDK) — `flutter_lints: ^6.0.0` — `sqflite_common_ffi: ^2.4.7`
  (لاختبارات قاعدة البيانات).

### 1.3 البناء المحلي

- **الأمر الوحيد المعتمد:** `bash build-apk.sh` من داخل `~/workspace/ledger-app/`.
  السكربت يضبط `JAVA_HOME=~/programs/jdk-17` و`ANDROID_HOME=~/programs/android-sdk`
  و`GRADLE_USER_HOME`، ويفضّل IPv6 للـ loopback مع إعدادات البروكسي المستخرجة
  من متغيرات بيئة الجهاز وقت التشغيل فقط (لا بيانات اعتماد مكتوبة فيه).
  **البناء العادي `flutter build apk` يفشل على هذا الجهاز — لا تستخدمه.**
  الناتج: `build/app/outputs/flutter-apk/app-release.apk`.
- **قاعدة صارمة: لا بناءان متوازيان على هذا الجهاز أبداً** (1.5 نواة، ~8GB ذاكرة) —
  بناء Flutter/Gradle واحد في كل مرة، ويُسلسل مع أي بناء آخر.
- قرص `/tmp` صغير (512M) — استخدم `TMPDIR=/home/hatch/tmp` لأي عملية كبيرة.
- التحقق من APK بـ `aapt2` و`apksigner` في
  `/home/hatch/programs/android-sdk/build-tools/35.0.0/` (مع `PATH` فيه
  `/home/hatch/programs/jdk-17/bin`): الحزمة `com.faresfahd.ledger`،
  وversionCode ‏10+، وبصمة SHA-1 ‏`87:34:7D:…:86:D3` (انظر §1.4).

### 1.4 التوقيع (مسارات فقط — بلا كلمات مرور)

- إعداد التوقيع في `android/app/build.gradle.kts`: ‏`signingConfigs.pinnedDebug`
  يقرأ `rootProject.file("debug.keystore")` أي `android/debug.keystore`،
  وبناء `release` يوقَّع به دائماً — فكل بناء يحافظ على بصمة SHA-1 نفسها.
- **بصمة SHA-1:** `87:34:7D:C1:80:81:10:B9:DE:E2:AF:FC:A2:48:63:31:69:48:86:D3`
  — مسجلة في Firebase / عميل OAuth (انظر §1.5). **ممنوع** أن يقرأ أي بناء
  مخزناً من مجلد home الخاص بالباني: أُعيد إنشاء ذلك المخزن مرة (24/11)
  فتغيّرت البصمة صامتةً وكسرت دخول جوجل بالكود 10.
- `*.keystore` في `.gitignore` — **المخزن لا يُرفع إلى Git أبداً** (المستودع عام).
- **كلمات المرور غير موثقة في هذا الملف عمداً** — موجودة في إعداد التوقيع
  داخل المستودع وفي Codemagic فقط، ولا تُكتب في أي محادثة أو ذاكرة أبداً.
- لا يُنشأ مفتاح إصدار (release keystore) قبل حسم وضع النسخة المثبتة
  وتوافق التحديث ومراجعة خطة التوقيع مع المالك.

### 1.5 إعداد جوجل السحابي (خارج الكود — مطلوب لعمل النسخة السحابية)

- مشروع Firebase ‏**fares-fahd-ledger** (رقم 812532953493، بلا Analytics)
  بحساب `memohakem0@gmail.com` — تطبيق أندرويد بالحزمة `com.faresfahd.ledger`
  ومعرّف `1:812532953493:android:bdb25ce55fa6d6f435069c`.
- Drive API مفعّلة. شاشة OAuth ‏External/Testing بمستخدمَي اختبار
  `memohakem0@gmail.com` و`abofares62022@gmail.com`. عميل OAuth أندرويد
  `812532953493-60l982av90vs0mgbmcmc7nruc9c5qbe3.apps.googleusercontent.com`.
- ملف `android/app/google-services.json` (684 بايت) **ملتزم في المستودع** —
  يحتوي معرّفات عامة فقط (رقم المشروع ومعرّف العميل)، بلا أي سر.
  بدونه يفشل بناء Google Services عمداً حتى لا يُشحن إعداد ناقص صامتاً.
- مشروع شفاء (`shifa-da4c8`، حزمة `com.shifa.app`) منفصل تماماً ولم يُمس —
  لا تخلط بين المشروعين.

### 1.6 البناء الآلي — Codemagic (`codemagic.yaml`)

- سير العمل `android-release` — الجهاز `mac_mini_m2` — حد 60 دقيقة.
- **الخطة المجانية تعطي 500 دقيقة شهرياً على أجهزة macOS M2 فقط** للحسابات
  الشخصية؛ بناءات لينكس وويندوز بلا دقائق مجانية. `linux_x2` و`linux`
  يفشلان بالخطأ «The selected instance type is not available with the
  current billing plan» — **لا تغيّر `instance_type` أبداً**.
- المشغّل: دفع وسم `v*` (مثل `v1.0.9`) فقط — `triggering.events: [tag]`.
- البيئة: `flutter: stable` — `java: 17` — التوقيع `android_signing:
  - fares-fahd-debug-keystore` (مرجع المخزن المرفوع في Codemagic، يُنسخ
  إلى `android/debug.keystore` قبل البناء).
- الخطوات بالترتيب: `flutter pub get` ← `flutter analyze` ← `flutter test`
  ← نسخ المخزن ← `flutter build apk --release`.
- الملف الناتج: `build/app/outputs/flutter-apk/app-release.apk`.
- صفحة التطبيق: https://codemagic.io/app/6b066f615ac9b4145f927b13/settings —
  حساب Codemagic باسم Ossama وبريد `memohakem0@gmail.com` عبر GitHub ‏shifa-app
  فقط. الدخول برمز تحقق من 6 أحرف يُرسل إلى ذلك البريد (Gmail غير متصل
  بالمساعد — الرمز يأتي من المالك في المحادثة دائماً).
- **لا نشر تلقائي إلى GitHub من Codemagic** (يحتاج رمز GitHub في متغير
  بيئة آمن — غير مضبوط). النشر يدوي بعد البناء (انظر §1.7).
- التزامن واحد فقط في الخطة المجانية — لا تشغّل مهمتي Codemagic متوازيتين
  في محادثتين (تتعارضان على الموقع نفسه — `site_in_use`).

### 1.7 النشر على GitHub (يدوي — بعد كل إصدار)

- المستودع عام: https://github.com/shifa-app/fares-fahd-ledger — فرع `main`.
- **الدفع يتم بأداة اللقطة (snapshot) فقط** — بلا `gh auth login` ولا رموز
  PAT ولا أي رمز في المحادثة أو أوامر git. قبل أي دفع: تحقق من الحساب
  المسجل (يجب أن يكون **shifa-app** — account_id ‏`3ca6eb77…`)؛ إن كان
  غيره توقف فوراً. الملفات الثنائية (الصور والخطوط والأيقونات) موجودة
  أصلاً على `main` من رفع سابق — لا تُحذف ولا تُعاد. سجل المزامنة:
  `~/workspace/ledger-app.muse-github-snapshot-sync.json`.
- نمط الإصدار: وسم `vX.Y.Z` على `main` يطلق بناء Codemagic تلقائياً.
- **قاعدة اسم ملف الإصدار (معتمدة 26/11):** ملف APK الرئيسي في كل إصدار
  اسمه ثابت بلا رقم إصدار: `fares-fahd-ledger.apk` — فيكون رابط التحميل
  المباشر الدائم
  `https://github.com/shifa-app/fares-fahd-ledger/releases/latest/download/fares-fahd-ledger.apk`
  ثابتاً بعد أي تحديث. ملف Codemagic يبقى باسم مميز فيه رقم الإصدار
  (`fares-fahd-ledger-X.Y.Z-codemagic.apk`) حتى لا يتعارض مع الاسم الثابت.
- الإصدارات المنشورة حتى الآن: v1.0.2 حتى v1.0.9 (الأحدث v1.0.9 ‏Latest).

---

## 2 — خريطة الملفات والمجلدات (Architecture & File Map)

### 2.1 شجرة `lib/` (17 ملفاً)

```
lib/
├── app_info.dart                  # الهوية والثوابت والألوان والشعارات (§3)
├── main.dart                      # نقطة الدخول: RTL + الثيم + بوابة الإيميل
├── models.dart                    # Person / LedgerEntry / PersonWithBalance
├── logic/
│   └── balance.dart               # المنطق المحاسبي الخالص (بلا Flutter/DB) (§4.2)
├── db/
│   └── ledger_db.dart             # SQLite: الجداول + كل عمليات CRUD + التصدير/الاستيراد
├── screens/
│   ├── home_screen.dart           # التبويبان: لوحة التحكم + الأشخاص (§2.3)
│   ├── login_screen.dart          # الدخول بالإيميل فقط
│   ├── person_detail_screen.dart  # بطاقة الشخص: السجل + إضافة حركة + واتساب + PDF + حذف
│   └── terms_screen.dart          # شروط الاستخدام (من assets/terms_of_use_ar.md)
├── services/
│   ├── backup_service.dart        # النسخة اليدوية JSON عبر الإيميل (مشاركة نظام)
│   ├── cloud_backup_service.dart  # النسخة السحابية التلقائية Google Drive (§4.4)
│   ├── pdf_service.dart           # كشف حساب PDF عربي + QR
│   ├── profile_service.dart       # ملف النشاط التجاري (الاسم + هاتف العمل)
│   └── whatsapp_service.dart      # تذكير واتساب عبر wa.me (بلا Business API)
└── widgets/
    ├── amount_sheet.dart          # ورقة إضافة حركة جديدة
    ├── app_footer.dart            # فوتر الحقوق الموحد
    ├── charts.dart                # LineFlowChart + BarFlowChart (آخر 7 أيام)
    └── person_form.dart           # نموذج إضافة/تعديل شخص (+ استيراد من جهات الاتصال)
```

### 2.2 شجرة `assets/` (11 ملفاً)

```
assets/
├── fonts/
│   ├── Cairo-Variable.ttf         # خط الواجهة الوحيد (أوزان 400/500/600/700)
│   ├── NotoNaskhArabic-Regular.ttf
│   └── NotoNaskhArabic-Bold.ttf   # خط كشف PDF فقط
├── icon_wallet.png                # أيقونة 3D: معاملة جديدة (محفظة)
├── icon_chart.png                 # أيقونة 3D: التقارير (رسوم بيانية)
├── icon_people.png                # أيقونة 3D: الأشخاص
├── logo.jpg                       # الشعار الكامل بالاسم — كشف PDF فقط
├── logo_mark.png                  # الشعار (الرمز وحده) — أيقونة التطبيق
├── logo_header.png                # الشعار الكامل بالنص (شفاف) — بطاقة الترحيب + الدخول + التحميل
├── logo_symbol.png                # الشعار (الرمز وحده) — علامة AppBar الصغيرة
└── terms_of_use_ar.md             # شروط الاستخدام (15 قسماً، القانون المصري)
```

كل الشعارات والأيقونات **مقدمة من المستخدم — ممنوع تماماً استبدالها بصور
مولدة بالذكاء الاصطناعي**.

### 2.3 دور كل ملف رئيسي

| الملف | الدور |
|---|---|
| `lib/main.dart` | `FaresFahdApp`: ‏`MaterialApp` عربي RTL ‏(`locale: ar`، ‏`Directionality rtl`)، ثيم Cairo (§3)، شاشة تحميل بشعار `logo_header.png` (ارتفاع 180) أثناء قراءة الإيميل المحفوظ، ثم `LoginScreen` إن لم يوجد إيميل، وإلا `HomeScreen`. |
| `lib/app_info.dart` | الهوية: `appName = 'فارس وفهد للحسابات'`، ‏`appBrand = 'FF'`، ‏`appTagline = 'فارس للثقة، فهد للسرعة'`، ثوابت الأصول (`logoHeaderAsset` / `logoSymbolAsset` / `iconWalletAsset` …)، ‏`appReleasesUrl` (صفحة الإصدارات الدائمة)، سطرا الحقوق (للواجهة ولـ PDF)، وفئة `BrandColors` (§3.1). |
| `lib/screens/home_screen.dart` | الشاشة الرئيسية: شريط سفلي بتبويبين — **«لوحة تحكم»** و**«الأشخاص»** (لا Drawer إطلاقاً). لوحة التحكم: بطاقة ترحيب بالشعار والشعار النصي، ثلاث بطاقات (إجمالي الوارد / إجمالي الصادر / صافي المستحقات) بمحاذاة `stretch` (§3.4)، ملاحظة «الوارد والصادر نقدي فقط — البيع والشراء الآجل دين وليس تدفقاً نقدياً»، قائمة «النشاط الأخير» (آخر حركة لكل شخص — `recentPersonsWithLatestEntry`، حد 8)، رسما آخر 7 أيام «الوارد والصادر يومياً» (خطي + أعمدة). تبويب الأشخاص: بحث بالاسم/الهاتف + شرائح فلاتر (الكل / عملاء / موردين / له رصيد / عليه رصيد) + إضافة شخص. زر السحابة في AppBar يفتح نافذة النسخة السحابية؛ عند بدء التشغيل يُعرض استرجاع سحابي تلقائياً إن وُجدت نسخة (`_maybeOfferCloudRestore`). |
| `lib/screens/login_screen.dart` | الدخول بالإيميل الشخصي فقط: التحقق `contains('@')` فقط، يُحفظ محلياً في جدول `settings` بالمفتاح `email` كهوية — **بلا كلمة مرور وبلا OTP**. يعرض الشعار والشعار النصي وفوتر الحقوق. |
| `lib/screens/person_detail_screen.dart` | بطاقة الشخص: الرصيد الجارٍ بعد كل حركة، السجل الكامل (مسميات مختصرة + التاريخ الكامل بلا قص)، إضافة حركة بأنواعها المسموحة حسب نوع الشخص، حذف الشخص (يحذف حركاته معه — بتأكيد) وحذف حركة (بتأكيد)، زر واتساب للتذكير، زر كشف PDF. |
| `lib/screens/terms_screen.dart` | عرض `assets/terms_of_use_ar.md` حرفياً. |
| `lib/db/ledger_db.dart` | SQLite ‏`ledger.db`، الإصدار 1 (§4.1). كل الاستعلامات: بحث الأشخاص، حركات الشخص، الرصيد الجاري، الأشخاص بأرصدتهم، النشاط الأخير، كل الحركات للرسوم، العدّادات، التصدير/الاستيراد الكامل. |
| `lib/logic/balance.dart` | كل المنطق المحاسبي خالصاً وقابلاً للاختبار (§4.2 و§4.3). |
| `lib/services/backup_service.dart` | النسخة اليدوية (§4.4). |
| `lib/services/cloud_backup_service.dart` | النسخة السحابية التلقائية (§4.4). |
| `lib/services/pdf_service.dart` | `buildStatement` (كشف PDF) + `shareStatement` + ‏`appDownloadQrBytes` (QR ‏220px لرابط الإصدارات). |
| `lib/services/profile_service.dart` | حفظ/قراءة اسم النشاط وهاتف العمل من `settings`؛ يُستخدم في ترويسة PDF، والافتراضي اسم التطبيق. |
| `lib/services/whatsapp_service.dart` | `openWhatsApp(phone, message)`: تطبيع رقم مصري → صيغة دولية → `whatsapp://send` أولاً ثم `https://wa.me/` احتياطياً. |
| `lib/widgets/charts.dart` | `LineFlowChart` (منحنى أملس + تدرج + نقرة تعرض قيم اليوم) و`BarFlowChart` (أعمدة مجمعة) — رسم `CustomPainter` بلا اعتماديات إضافية، ارتفاع 170px، `ClipRect` (§3.5). |
| `lib/widgets/amount_sheet.dart` | ورقة إضافة حركة: النوع (حسب الشخص) + المبلغ + الملاحظة + التاريخ. |
| `lib/widgets/person_form.dart` | نموذج الشخص: الاسم/الهاتف/العنوان/النوع/ملاحظات + استيراد الرقم من جهات الاتصال. |
| `lib/widgets/app_footer.dart` | «جميع الحقوق محفوظة © فارس وفهد للحسابات» + «برمجة وتصميم أبو فارس» — أسفل شاشة الدخول ونهاية محتوى الرئيسية. |

### 2.4 شجرة `test/` (9 ملفات — §5.2 للتفصيل)

```
test/
├── balance_test.dart
├── dashboard_repro_test.dart
├── dashboard_stats_test.dart
├── pdf_text_test.dart
├── profile_qr_test.dart
├── quick_action_icons_test.dart
├── recent_persons_test.dart
├── terms_footer_test.dart
└── ui_logic_test.dart
```

### 2.5 ملفات الجذر والمجلدات الأخرى

- `codemagic.yaml` — البناء الآلي (§1.6). `build-apk.sh` — البناء المحلي (§1.3).
- `android/` — تطبيق أندرويد (Gradle/Kotlin)؛ `android/app/google-services.json`؛
  `android/app/src/main/kotlin/com/faresfahd/ledger/MainActivity.kt`.
- `docs/terms-of-use-ar.md` — مصدر شروط الاستخدام المعتمد (15 قسماً) —
  منسوخ حرفياً إلى `assets/terms_of_use_ar.md`.
- `docs/github-release/` — نسخ APK الإصدارات محلياً (**مستثناة من Git**).
- `README.md` — توثيق المشروع الكامل (بما فيه قسم «النسخة السحابية»).
- `analysis_options.yaml` — قواعد `flutter_lints`.

---

## 3 — قواعد الهوية البصرية والتصميم (Strict UI/UX Design System — ممنوع المساس بها)

### 3.1 نظام الألوان المعتمد (`BrandColors` في `lib/app_info.dart`)

| الاسم | القيمة | الاستخدام |
|---|---|---|
| `navy` | `#0D1726` | اللون الأساسي: AppBar، بطاقات الترحيب، حاويات الأيقونات، شريط قيم اليوم المحدد في الرسم |
| `navyDark` | `#070D18` | درجة كحلية أغمق |
| `gold` | `#D4AF37` | اللون المميز: زر الإجراء العائم، الخط الذهبي في الرسم، التمييز |
| `goldLight` | `#E3C766` | ذهبي فاتح |
| `brandBlue` | `#2E7FC2` | أزرق الشعار (حرف F) |
| `brandBlueLight` | `#7FB8E8` | أزرق فاتح |
| `background` | `#F4F6F9` | خلفية التطبيق (رمادي ثلجي) |
| `success` / `successBg` | `#16A34A` / `#DCFCE7` | الوارد و«له» — نص أخضر على خلفية خضراء فاتحة جداً |
| `danger` / `dangerBg` | `#DC2626` / `#FEE2E2` | الصادر و«عليه» — نص أحمر على خلفية حمراء فاتحة جداً |

**لا تغيّر أي قيمة سداسية عشرية، ولا تستبدل الألوان بألوان Material الافتراضية.**
أي لون جديد يجب أن يأتي من `BrandColors` حصراً.

### 3.2 الثيم العام (`lib/main.dart`)

- `useMaterial3: true` — `fontFamily: 'Cairo'` — `scaffoldBackgroundColor:
  BrandColors.background` — `colorScheme` من `ColorScheme.fromSeed(seedColor:
  BrandColors.navy, brightness: Brightness.light)`.
- AppBar: خلفية كحلية، نص أبيض، أيقونات مقاس 26 بيضاء، عنوان 20 بخط Cairo
  وزن 700.
- زر الإجراء العائم: خلفية ذهبية ونص كحلي.
- `textTheme`: ‏`bodyMedium` ‏18 وزن 500 — `bodyLarge` ‏20 وزن 500 —
  `titleLarge` ‏22 وزن 700 — `headlineMedium` ‏26 وزن 700 — `labelLarge`
  ‏18 وزن 700.
- الاتجاه RTL دائماً (`Directionality` ‏`TextDirection.rtl` + ‏`locale: ar`)،
  وشريط `debugShowCheckedModeBanner` مخفي.

### 3.3 الخطوط

- **خط الواجهة الوحيد: Cairo** — ملف `assets/fonts/Cairo-Variable.ttf`
  بأوزان 400 / 500 / 600 / 700 (معلن في `pubspec.yaml`).
- **Noto Naskh Arabic** (عادي + عريض) **لكشف PDF فقط** — لا يُستخدم في الواجهة.
- **لا يوجد Tajawal في المشروع إطلاقاً** — لا تضفه.
- تحذير موثق: خط Noto Naskh المضمّن في PDF **لا يحتوي رمز © ولا `-` ولا `–`**
  في خريطة حروفه (متحقق بـ fontTools) — لذلك سطر الحقوق في PDF بصيغة حروف
  عربية فقط: «جميع الحقوق محفوظة لفارس وفهد للحسابات» (انظر §5 — PDF).
  وفي الواجهة (خط Cairo) يعرض © بشكل طبيعي.

### 3.4 حاويات الأيقونات والمحاذاة (مضبوطة مؤخراً — لا تكسرها)

- **حاويات الأيقونات السريعة:** مربع كحلي مستدير **44×44** بلون `#0D1726`
  (`lib/screens/home_screen.dart:1284-1285`) بداخله أيقونة 3D ذهبية/زرقاء
  (`icon_wallet.png` لمعاملة جديدة، `icon_chart.png` للتقارير،
  `icon_people.png` للأشخاص). الصور تجلس على خلفية كحلية مسطحة فلا حاجة
  لأي عمل شفافية.
- **محاذاة بطاقات لوحة التحكم:** صف البطاقات الثلاث (إجمالي الوارد /
  إجمالي الصادر / صافي المستحقات) داخل `IntrinsicHeight` مع
  `CrossAxisAlignment.stretch` (حوالي السطر 950-956 في `home_screen.dart`)
  حتى تتساوى ارتفاعاتها مع بطاقة «صافي المستحقات» الأطول. **هذا إصلاح
  1.0.7 لانهيار اللوحة** (انظر §6.1) — إزالة `IntrinsicHeight` أو وضع
  `stretch` داخل تمرير غير مقيد يعيد الانهيار (ارتفاع لانهائي).
- **الشعار المعتمد:** حرف «ف» الذهبي وحرف «F» الأزرق (صورة ثلاثية الأبعاد
  مقدمة من المستخدم 24/11). `logo_header.png` (الكامل بالنص) في بطاقة
  الترحيب (ارتفاع 96) وشاشة الدخول وشاشة التحميل (ارتفاع 180)؛
  `logo_symbol.png` (الرمز وحده) علامة AppBar الصغيرة؛ `logo.jpg`
  (الكامل بالاسم) في كشف PDF فقط؛ `logo_mark.png` أيقونة التطبيق.
  الشعار النصي «فارس للثقة، فهد للسرعة» يظهر في بطاقة الترحيب وشاشة الدخول
  (`appTagline` في `app_info.dart`).
- **التنقل: شريط سفلي (BottomNavigationBar) بتبويبين فقط — «لوحة تحكم» و
  «الأشخاص». لا يوجد Drawer (قائمة جانبية) في أي مكان في الكود** — أي
  مسودة تذكر Drawer فهي خاطئة.

### 3.5 الرسوم البيانية (`lib/widgets/charts.dart`)

- رسمان `CustomPainter` بلا اعتماديات: `LineFlowChart` (منحنى أملس + تدرج
  تحت خط الوارد + نقرة على نقطة تعرض قيم ذلك اليوم في شريط كحلي) و
  `BarFlowChart` (أعمدة مجمعة وارد/صادر لكل يوم).
- الارتفاع ثابت 170px داخل `ClipRect`، والمنحنى Catmull-Rom محول إلى
  Bezier مع **تقييد كل إحداثيات y — نقاط الارتكاز ونقاط التحكم معاً —
  داخل نطاق الرسم** (إصلاح 1.0.7: نقاط التحكم كانت تتجاوز خط الصفر
  ~22dp مع بيانات مثل [0,0,0,0,0,0,220]).
- الألوان: الوارد أخضر `#16A34A`، الصادر أحمر `#DC2626`، خط اليوم المحدد
  ذهبي. تسميات المحور y مختصرة (`_shortMoney`: ‏1أ للألف، 1م للمليون).

### 3.6 الفوتر وسطر الحقوق

- `lib/widgets/app_footer.dart`: سطران — «جميع الحقوق محفوظة © فارس وفهد
  للحسابات» + «برمجة وتصميم أبو فارس» — يظهران أسفل شاشة الدخول ونهاية
  محتوى الرئيسية. لا تغيّر الصياغة ولا تحذف الفوتر من أي شاشة.

---

## 4 — هيكل البيانات والنسخ الاحتياطي (Data Schema & Cloud Backup — منطقة حساسة جداً)

### 4.1 قاعدة البيانات المحلية — SQLite (`lib/db/ledger_db.dart`)

- محرك `sqflite`، الملف `ledger.db`، الإصدار **1**، **Offline-First: بلا
  سيرفر وبلا شبكة**. كل البيانات محلية أولاً؛ السحابة نسخة فقط.
- جدول `persons`:

```sql
CREATE TABLE persons(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL,          -- 'customer' | 'supplier'
  notes TEXT NOT NULL DEFAULT ''
)
```

- جدول `entries`:

```sql
CREATE TABLE entries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  personId INTEGER NOT NULL,   -- FOREIGN KEY(personId) REFERENCES persons(id)
  type TEXT NOT NULL,          -- 'saleCredit' | 'purchaseCredit' |
                               -- 'paymentReceived' | 'paymentPaid' | 'discount'
  amount REAL NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  date TEXT NOT NULL           -- 'yyyy-MM-dd'
)
```

- جدول `settings` (مفتاح/قيمة):

```sql
CREATE TABLE settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
```

- مفاتيح `settings` المستخدمة فعلياً: `email` (هوية الدخول)، `cloud_email`
  (آخر حساب جوجل)، `cloud_last_upload` (ISO8601 لآخر رفع ناجح)،
  `cloud_last_error` (آخر خطأ سحابي بالعربية).
- **لا تغيّر أسماء الجداول أو الأعمدة أو أنواعها، ولا ترفع إصدار قاعدة
  البيانات، دون ترحيل (migration) يحفظ بيانات المستخدمين واختبار له.**
- حذف شخص يحذف حركاته معه في معاملة واحدة (`deletePerson`).
- النماذج (`lib/models.dart`): ‏`Person{id, name, phone, address, type,
  notes}` و`LedgerEntry{id, personId, type, amount, note, date}` — التاريخ
  يُخزن `date.toIso8601String().substring(0, 10)`، والنوع يُخزن برمزه
  (`type.code`) ويُقرأ بـ `txTypeFromCode` (أي رمز غير معروف يعود
  افتراضياً إلى `saleCredit` — لا تغيّر هذا السلوك صامتاً).

### 4.2 منطق حساب الرصيد (`lib/logic/balance.dart` — خالص، بلا Flutter/DB)

**الاتفاقية الموقعة (ممنوع تغييرها):** الرصيد موجب = **«عليه»** (الشخص مدين
لنا)، سالب = **«له»** (نحن مدينون له)، صفر = **«متعادل»**.
كل المبالغ بالجنيه المصري.

| نوع الحركة | الأثر الموقع `signedDelta` | التسمية الكاملة | التسمية المختصرة |
|---|---|---|---|
| `saleCredit` — بيع آجل | `+المبلغ` | بيع آجل | بيع آجل |
| `purchaseCredit` — شراء آجل | `−المبلغ` | شراء آجل | شراء آجل |
| `paymentReceived` — دفعة مستلمة | `−المبلغ` | دفعة نقدية مستلمة | دفعة مستلمة |
| `paymentPaid` — دفعة مدفوعة | `+المبلغ` | دفعة نقدية مدفوعة | دفعة مدفوعة |
| `discount` — خصم | عميل: `−المبلغ` / مورّد: `+المبلغ` | خصم | خصم |

- الأنواع المسموحة لكل شخص (`allowedTxTypes`): العميل — بيع آجل، دفعة
  مستلمة، خصم. المورّد — شراء آجل، دفعة مدفوعة، خصم. (اختبارات تمنع
  العكس: عميل لا يسجل شراءً، ومورّد لا يسجل بيعاً.)
- `runningBalances` — الرصيد الجاري بعد كل حركة بالترتيب.
  `finalBalance` — مجموع الدeltas. `balanceWord` — عليه/له/متعادل.
- `netBalanceLabel` — **خاص بلوحة التحكم فقط وليس بالأشخاص**: الصافي
  الموجب = «مديونية عملاء»، السالب = «مديونية علينا»، صفر = «متعادل».
- `summarizeBalances` — ‏`owedToUs` (مجموع الأرصدة الموجبة) و`weOwe`
  (مجموع القيم المطلقة للسالبة) و`net = owedToUs − weOwe`.
- `formatMoney` — «X جنيه» بفاصل آلاف وبلا كسور للمبالغ الصحيحة.
  `formatDayDate` — صيغة ثابتة `dd-MM-yyyy` (مثل 24-11-2026).
- `txClarification` — توضيح تحت المبلغ حتى لا يُقرأ + / − وحده:
  بيع آجل «على العميل»، شراء آجل «دين علينا»، دفعة مستلمة «سداد»، دفعة
  مدفوعة «سداد للمورّد»، خصم «خصم من الدين» / «خصم من المستحق».
- فلاتر تبويب الأشخاص (`PersonFilter`): الكل / عملاء / موردين / «له رصيد»
  (رصيد < 0) / «عليه رصيد» (رصيد > 0) — عبر `personMatchesFilter`.

### 4.3 الوارد والمنصرف والرسوم البيانية لآخر 7 أيام

- **القاعدة الذهبية (`flowOf`):** الوارد = **الدفعات المستلمة فقط**،
  والصادر = **الدفعات المدفوعة فقط**. البيع الآجل والشراء الآجل دَين
  وليسا تدفقاً نقدياً، والخصم ليس تدفقاً — كلها `(0, 0)`. عدّ البيع
  الآجل وارداً يضاعف المال (مثال موثق: مبيعات 90 + دفعة 50 كانت تُعرض
  140 خطأً).
- `totalFlow` — إجمالي الوارد/الصادر. `lastDaysFlows(entries, 7)` —
  تدفق يومي لآخر 7 أيام بترتيب الأقدم أولاً حتى اليوم، والأيام بلا
  حركات صفر. بلا أي أرقام تجريبية أبداً: الدفتر الفارغ يعرض أصفاراً.
- الرسمان في `lib/widgets/charts.dart` يقرآن `lastDaysFlows` من حركات
  قاعدة البيانات الحقيقية فقط (§3.5).

### 4.4 النسخ الاحتياطي — هيكل الملف والمساران

#### شكل ملف JSON (إصدار صيغة النسخة = 1 — `LedgerDb.exportAll`)

```json
{
  "app": "fares-fahd-ledger",
  "version": 1,
  "exportedAt": "2026-11-25T01:42:00.000",
  "email": "abofares62022@gmail.com",
  "persons": [ { "id": 1, "name": "...", "phone": "...", "address": "...",
                 "type": "customer", "notes": "" } ],
  "entries": [ { "id": 1, "personId": 1, "type": "saleCredit",
                 "amount": 500.0, "note": "", "date": "2026-11-24" } ]
}
```

- `importAll` يتحقق أن `persons` و`entries` قائمتان وإلا رمى
  `FormatException('ملف النسخة غير صالح')`، ثم **يستبدل كل البيانات
  المحلية في معاملة واحدة** ويعيد `(persons, entries)` المسترجعة،
  ويستعيد الإيميل إن وُجد.
- **قاعدة التوافق:** لا تغيّر أسماء الحقول ولا شكلها ولا `version` ولا
  اسم الملف دون ترحيل واختبار — نسخ قديمة بنفس الشكل يجب أن تستمر
  في الاسترجاع. أي تغيير هنا يمسح بيانات مستخدمين.

#### المسار اليدوي — `lib/services/backup_service.dart`

- `exportJson` — نفس `exportAll` بمسافة بادئة مسافتين.
- `writeBackupFile` — ملف مؤقت `fares-fahd-backup-YYYYMMDD-HHMM.json`
  في مجلد النظام المؤقت.
- `shareBackup` — مشاركة عبر `SharePlus` (الموضوع: «نسخة احتياطية -
  فارس وفهد للحسابات») — المستخدم يختار تطبيق بريده بنفسه؛ الكود لا
  يرسل شيئاً مباشرة ولا يخزن أي كلمة مرور.
- `restoreFromJson` — استرجاع من نص JSON يلصقه المستخدم.

#### المسار السحابي التلقائي — `lib/services/cloud_backup_service.dart`

- الدخول: `GoogleSignIn` بنطاق `driveAppdataScope` فقط.
- **اسم الملف: `fares-fahd-backup.json`** — **المساحة: `appDataFolder`**
  (الثابت `cloudBackupSpace`). القيمة المختصرة `appData` غير صالحة
  ويرد عليها Drive ‏`400 Invalid Value` (علة 1.0.3).
- `uploadNow`: يبحث عن الموجود بـ `files.list(spaces: appDataFolder,
  q: "name = 'fares-fahd-backup.json'", orderBy: 'modifiedTime desc',
  pageSize: 1)` — إن وُجد يحدّث بـ `files.update`، وإلا ينشئ بـ
  `files.create`. **قاعدة 1.0.9 (`backupUploadMetadata`): وصف التحديث
  يحمل الاسم فقط بلا `parents`** (Drive يرفض `parents` في جسم
  `files.update` بالخطأ 400)؛ ووصف الإنشاء يحمل
  `parents = [appDataFolder]`. بعد نجاح الرفع يُحفظ `cloud_last_upload`.
- `maybeAutoUpload` — رفع تلقائي صامت بعد كل تغيير محلي؛ لا يرمي
  استثناءً ولا يحجب الواجهة؛ وإن لم يكن المستخدم مسجلاً دخوله لا يفعل
  شيئاً.
- `downloadAndRestore` — تنزيل بـ `files.get` (fullMedia) ثم
  `restoreFromJson`. `checkForCloudBackup` — يعيد الاسم وتاريخ التعديل
  والحجم أو null.
- **قاعدة 1.0.8 (حالة الدخول):** ‏`signedInEmail` يعكس **الجلسة الحية
  فقط** (`currentUser != null`)، و`isSignedIn` كذلك؛ و`lastKnownEmail`
  (من `cloud_email`) **تلميح عرض فقط («آخر حساب») وليس دليل جلسة**.
  `refreshSession` يعيد الربط صامتاً قبل قراءة الحالة؛ `ensureSignedIn`
  يدخل تفاعلياً عند غياب الجلسة ثم يعيد المحاولة. الدالة الخالصة
  `cloudDialogActions({signedIn, lastKnownEmail})` تحدد ما تعرضه
  النافذة: جلسة حية ← رفع + استرجاع بلا زر دخول؛ بلا جلسة ← زر دخول
  فقط (بلا رفع/استرجاع) مع تلميح آخر حساب.
- `friendlyCloudError` — يحوّل كل خطأ إلى رسالة عربية، ولا يظهر نص
  تقني خام للمستخدم أبداً: ‏`sign_in_failed` / `f1: 10` /
  `DEVELOPER_ERROR` / `ApiException: 10` → رسالة «إعداد جوجل غير مكتمل»
  (تسجيل البصمة + google-services.json)؛ مشاكل الشبكة → رسالة شبكة؛
  `DetailedApiRequestError` / `400` → رسالة مجلد النسخة؛ أي استثناء
  آخر → رسالة عربية عامة. الثابت الموحد لعدم الدخول:
  `cloudNotSignedInMessage = 'لم يتم تسجيل الدخول بحساب جوجل بعد.'`
- حالة النسخ (`CloudBackupStatus`): ‏`notSignedIn` «غير مسجل بحساب جوجل
  بعد» / `signedInNotUploaded` «لم يتم النسخ بعد» / `uploaded` «اكتمل
  النسخ الاحتياطي» — وتُعرض مع عدّادَي الأشخاص والمعاملات الحقيقيين
  من قاعدة البيانات (بلا أرقام تجريبية) عبر `backupCopiedRows`.
- عند تثبيت جديد: بعد دخول جوجل يُبحث في appDataFolder وتُعرض النسخة
  للاسترجاع تلقائياً.

---

## 5 — سجل الميزات والاختبارات (Features & Test Suite)

### 5.1 الشاشات والوظائف العاملة حالياً (1.0.9)

- **الدخول:** إيميل شخصي فقط (`contains('@')`) يُحفظ محلياً كهوية —
  بلا كلمة مرور وبلا OTP وبلا سيرفر.
- **لوحة التحكم:** بطاقة ترحيب بالشعار والشعار النصي؛ ثلاث بطاقات
  (إجمالي الوارد / إجمالي الصادر / صافي المستحقات)؛ قائمة «النشاط
  الأخير» (آخر حركة لكل شخص، حد 8، مرتبة بالأحدث)؛ رسما آخر 7 أيام
  (خطي + أعمدة) مع أسطورة الوارد/الصادر ونقرة لعرض قيم اليوم.
- **الأشخاص:** إضافة/تعديل شخص (اسم/هاتف/عنوان/نوع عميل أو مورّد/
  ملاحظات) + استيراد الرقم من جهات الاتصال؛ بحث بالاسم أو الهاتف؛
  فلاتر (الكل / عملاء / موردين / له رصيد / عليه رصيد).
- **بطاقة الشخص:** الرصيد الجاري بعد كل حركة؛ السجل الكامل بمسميات
  مختصرة وتاريخ كامل؛ إضافة حركة بأنواعها المسموحة حسب نوع الشخص؛
  حذف الشخص (مع حركاته — بتأكيد) وحذف حركة (بتأكيد).
- **تذكير واتساب:** زر في بطاقة الشخص يفتح واتساب برسالة تذكير تتضمن
  اسم النشاط والرصيد — عبر `whatsapp://send` ثم `wa.me` احتياطياً.
  **بلا WhatsApp Business API وبلا روابط دفع.**
- **كشف حساب PDF عربي:** عنوان «كشف حساب» + التاريخ، بيانات الشخص
  (النوع/الاسم/الهاتف/العنوان)، جدول الحركات بالرصيد الجاري، الإجماليات،
  رمز QR لرابط الإصدارات الدائم، وتذييل الحقوق بصيغة بلا © (§3.3)؛
  مشاركة عبر ورقة مشاركة النظام. ترويسة النشاط من `ProfileService`
  (اسم النشاط + هاتف العمل، والافتراضي اسم التطبيق).
- **النسخة اليدوية:** تصدير JSON ومشاركته عبر الإيميل + استرجاع من نص
  ملصوق (§4.4).
- **النسخة السحابية:** دخول جوجل مرة واحدة → رفع تلقائي بعد كل تغيير
  إلى Drive appDataFolder → استرجاع تلقائي عند إعادة التثبيت بعد
  دخول جوجل → نافذة حالة (الدخول / آخر رفع / آخر خطأ / العدّادات)
  (§4.4).
- **شروط الاستخدام:** شاشة تعرض `assets/terms_of_use_ar.md` حرفياً
  (15 قسماً، القانون المصري، بريد الدعم `Faresosama1919@gmail.com`).
- **الفوتر:** سطر الحقوق + «برمجة وتصميم أبو فارس» في الدخول ونهاية
  الرئيسية.

**ممنوع/مؤجل صراحةً (لا تنفذه دون قرار مستقل من المالك):** الصوتي،
OCR، روابط الدفع، WhatsApp Business API، تعدد الفروع، Freemium، iOS.

### 5.2 حزمة الاختبارات — 78 اختباراً، كلها ناجحة

- **آخر تشغيل موثق قبل كتابة هذا الملف (27/11/2026، على الكود الحالي
  1.0.9): `flutter analyze` — ‏«No issues found!»؛ و`flutter test` —
  ‏«All tests passed!» ‏78/78، صفر فشل.**
- **أمر التشغيل:** `flutter test` (من جذر المشروع) — و`flutter analyze`
  قبله. في Codemagic يُشغَّلان تلقائياً قبل كل بناء (§1.6).
- **لا تسلّم أي تعديل قبل نجاح الاختبارات كاملة (78/78).** نجاح
  الاختبارات وحده ليس اعتماداً نهائياً — الاعتماد النهائي فحص حي
  على جهاز المالك — لكن فشل اختبار واحد يمنع التسليم.

| الملف | العدد | ما يغطيه |
|---|---|---|
| `test/balance_test.dart` | 14 | `signedDelta` لكل الأنواع، الرصيد الجاري والنهائي، `summarizeBalances`، الأنواع المسموحة، `formatMoney` |
| `test/dashboard_repro_test.dart` | 1 | انحدار 1.0.7: ‏`IntrinsicHeight + stretch` بلا استثناء وبلا تداخل (اختبار واجهة) |
| `test/dashboard_stats_test.dart` | 7 | `totalFlow` و`lastDaysFlows` (تجميع الأيام، الأصفار، 7 أيام تنتهي اليوم) |
| `test/pdf_text_test.dart` | 1 | نصوص PDF تستخدم حروفاً يملكها الخط المضمّن فقط |
| `test/profile_qr_test.dart` | 7 | حقول الملف التجاري، رسالة التذكير (اسم النشاط + الحقوق)، QR الإصدارات والرابط الدائم |
| `test/quick_action_icons_test.dart` | 2 | الأيقونات الثلاث مجمّعة وغير فارغة + قيم الألوان السداسية الدقيقة |
| `test/recent_persons_test.dart` | 4 | تجميع النشاط الأخير (صف واحد لكل شخص بآخر حركة) + الترتيب + حقول الملف |
| `test/terms_footer_test.dart` | 3 | نص الشروط (العنوان + بريد الدعم) + ويدجت الفوتر + ويدجت شاشة الشروط |
| `test/ui_logic_test.dart` | 39 | `formatDayDate`، ‏`txClarification`، فلاتر الأشخاص، `netBalanceLabel`، ‏`shortLabel`، ‏`BrandColors`، قواعد نافذة السحابة 1.0.8، وصف الرفع 1.0.9، رسائل الخطأ العربية، حالة النسخ |
| **المجموع** | **78** | |

---

## 6 — الخطوط الحمراء والمشاكل التي تم حلها (Strict Rules & Resolved Bugs)

### 6.1 خطوط حمراء — ممنوع إطلاقاً دون موافقة صريحة من المالك

1. تغيير أي لون أو خط أو شعار أو حجم حاوية أيقونة (44×44) أو محاذاة
   البطاقات (§3) — الهوية ثابتة.
2. تغيير اتفاقية الرصيد الموقعة (§4.2) أو عدّ البيع/الشراء الآجل
   تدفقاً نقدياً (§4.3) — يكسر كل الأرصدة والتقارير.
3. تغيير شكل ملف نسخة JSON أو `version` أو اسم الملف
   `fares-fahd-backup.json` أو مساحة `appDataFolder` (§4.4) — يمسح
   بيانات مستخدمين أو يكسر استرجاع نسخهم القديمة.
4. وضع `parents` في وصف `files.update` (علة 1.0.9) أو استخدام
   `appData` بدل `appDataFolder` (علة 1.0.3).
5. اعتبار الإيميل المحفوظ (`cloud_email`) دليل دخول (علة 1.0.8) —
   الجلسة الحية فقط.
6. أي رقم تجريبي أو عنصر مؤقت (placeholder) في الواجهة — الدفتر
   الفارغ يعرض أصفاراً حقيقية فقط.
7. صور مولدة بالذكاء الاصطناعي — كل الصور مقدمة من المستخدم.
8. إدخال أي سر أو كلمة مرور أو مفتاح API في المستودع أو في هذا
   الملف أو في أي محادثة — `*.keystore` مستثناة من Git.
9. الدفع إلى GitHub بأي حساب غير **shifa-app**، أو بأي طريقة غير
   أداة اللقطة (§1.7).
10. حذف التطبيق أو إعادة تثبيته أو مسح بياناته قبل تأكيد «اكتمل
    النسخ الاحتياطي» — انظر حادثة فقدان البيانات أدناه.
11. بناءان متوازيان على جهاز البناء (§1.3) أو مهمتا Codemagic
    متوازيتان (§1.6).
12. إعادة تنفيذ شيء موجود ويعمل صحيحاً، أو واجهات شكلية دون وظائف
    حقيقية، أو حذف ميزة دون موافقة.

### 6.2 سجل الإصدارات والأخطاء المُصلحة (لا تعِد كسرها)

| الإصدار | ما أُصلح / أُضيف — والسبب الجذري حيث يهم |
|---|---|
| 1.0.2+3 | «صافي المستحقات» + كبسولة «مديونية عملاء»؛ مسميات مختصرة؛ زر واتساب أخضر؛ تأكيد حذف. |
| 1.0.3+4 | إصلاح دخول جوجل (كود 10 DEVELOPER_ERROR → رسالة عربية)؛ شاشة حالة النسخ؛ شروط الاستخدام؛ فوتر الحقوق؛ الشعار الجديد. |
| 1.0.4+5 | مساحة Drive الصحيحة `appDataFolder` (بدل `appData` الخاطئة) + رسالة عربية لخطأ `DetailedApiRequestError`/400. |
| 1.0.5+6 | تجميع قائمة النشاط الأخير (صف واحد لكل شخص)؛ الرسم أسفل القائمة؛ بطاقة الملف التجاري؛ واتساب باسم النشاط؛ كشف PDF فيه QR لرابط الإصدارات (بلا © في PDF لأن الخط لا يحوي الرمز). |
| 1.0.6+7 | محاذاة البطاقات بـ `CrossAxisAlignment.stretch` + أيقونات 3D في حاويات كحلية 44×44. |
| 1.0.7+8 | **انهيار لوحة التحكم:** `stretch` داخل تمرير غير مقيد → ارتفاع لانهائي. الإصلاح: `IntrinsicHeight` حول صف البطاقات + `ClipRect` حول الرسّامين + تقييد إحداثيات المنحنى ونقاط تحكم Bezier. أكّد المالك حياً بلقطات أن اللوحة سليمة. |
| 1.0.8+9 | **علة دخول جوجل:** ‏`isSignedIn` كان يعتبر الإيميل المحفوظ جلسة حية فأخفى زر الدخول بينما الجلسة الفعلية غائبة بعد مسح البيانات. الإصلاح: `signedInEmail` للجلسة الحية فقط + `lastKnownEmail` تلميح + `refreshSession()` + `ensureSignedIn()` + `cloudDialogActions`. |
| 1.0.9+10 | **خطأ Drive ‏400 عند الرفع:** ‏`uploadNow()` كان يمرّر وصفاً واحداً فيه `parents` إلى `files.create` و`files.update` معاً، وDrive يرفض `parents` في `files.update`. الإصلاح: `backupUploadMetadata({isUpdate})` — التحديث بالاسم فقط. أكّد المالك حياً (25/11) أن الرفع السحابي يعمل — العلة مقفولة. |
| Codemagic | البناء 1 فشل: `linux_x2` غير متاح في الخطة المجانية → `mac_mini_m2` إلزامي. البناء 2 نجح (5m30s). ملف Codemagic يُرفع باسم مميز فيه رقم الإصدار بجانب الملف المحلي. |

### 6.3 حادثة فقدان البيانات (24/11) — الدرس الدائم

حذف المالك التطبيق وأعاد تثبيته متوقعاً عودة البيانات بالإيميل، **ولا
ملف JSON يدوي لديه**. البيانات كانت محلية فقط والسحابة لم تُرفع أبداً
فلم تُستعد — وأعاد إدخال البيانات بنفسه. **القاعدة: لا حذف/إعادة
تثبيت/مسح بيانات أبداً قبل تأكيد «اكتمل النسخ الاحتياطي».**
المسح اللاحق (25/11 05:38) استعاد البيانات من النسخة السحابية بنجاح
بعد دخول جوجل — النسخة كانت مكتملة (الأشخاص 1، المعاملات 5).

### 6.4 بنود مفتوحة معروفة (ليست أخطاء — لا «تصلحها» من تلقاء نفسك)

- **خطأ مطبعي في مصدر الشروط** (`docs/terms-of-use-ar.md` سطرا 29 و53:
  «للقانون» بلا ألف) — تُرك كما هو عمداً؛ يحتاج قرار تصحيح منفصلاً
  من المالك.
- **فحص `lintVital` معطّل في الإصدار** (`checkReleaseBuilds = false`):
  سببه انهيار أداة Lint نفسها في محلل JavaDoc على AGP ‏9.3.1 + JDK ‏17 —
  ليس مشكلة كود. Dart مغطى بـ `flutter analyze`.
- **مفتاح إصدار (release keystore):** لم يُنشأ بعد — القرار معلق على
  حسم وضع النسخة المثبتة وتوافق التحديث (§1.4).

---

## 7 — قائمة التحقق بعد أي تعديل (Verification Checklist)

قبل تسليم أي تعديل — بلا استثناء:

1. `flutter analyze` — صفر مشاكل.
2. `flutter test` — ‏78/78 ناجحة (أضف اختبار انحدار لأي علة تصلحها،
   كما فُعل في 1.0.8 و1.0.9).
3. راجع الملفات المعدلة حرفاً حرفاً مقابل هذا الملف: الألوان (§3)،
   اتفاقية الرصيد (§4.2)، شكل نسخة JSON (§4.4).
4. ابنِ APK بـ `bash build-apk.sh` وتحقق بـ `aapt2`/`apksigner`:
   الحزمة `com.faresfahd.ledger`، وversionCode صحيح، وبصمة SHA-1
   ‏`87:34:7D:…:86:D3`.
5. لا تدفع إلى GitHub إلا بحساب **shifa-app** وبأداة اللقطة (§1.7)،
   ولا وسم `v*` جديداً إلا بأمر المالك.
6. الاعتماد النهائي فحص حي على جهاز المالك — نجاح الاختبارات وحده
   ليس اعتماداً.

> «النهائي» عند المالك يعني إتمام كل ما نُوقش بكل مراحله — ولا يُقال
> «تم» إلا بعد تحقق حي من كل خطوة.
