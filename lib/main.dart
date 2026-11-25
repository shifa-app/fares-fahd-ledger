import 'package:material_ui/material_ui.dart';

import 'app_info.dart';
import 'db/ledger_db.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const FaresFahdApp());
}

/// «فارس وفهد للحسابات» — FF (فارس للثقة، فهد للسرعة).
/// دفتر ديون للعملاء والموردين: حفظ محلي Offline-First،
/// نسخة احتياطية بالإيميل، كشف PDF، وتذكير واتساب عادي.
class FaresFahdApp extends StatefulWidget {
  const FaresFahdApp({super.key});

  @override
  State<FaresFahdApp> createState() => _FaresFahdAppState();
}

class _FaresFahdAppState extends State<FaresFahdApp> {
  String? _email;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkEmail();
  }

  Future<void> _checkEmail() async {
    final email = await LedgerDb.instance.getEmail();
    if (!mounted) return;
    setState(() {
      _email = email;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: BrandColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrandColors.navy,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: BrandColors.navy,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(size: 26, color: Colors.white),
          actionsIconTheme: const IconThemeData(
            size: 26,
            color: Colors.white,
          ),
          titleTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: BrandColors.gold,
          foregroundColor: BrandColors.navy,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
          labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      home: _checking
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(logoHeaderAsset, height: 180),
                    SizedBox(height: 16),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            )
          : _email == null
              ? LoginScreen(
                  onSaved: (email) => setState(() => _email = email),
                )
              : HomeScreen(
                  email: _email!,
                  onLogout: () => setState(() => _email = null),
                ),
    );
  }
}
