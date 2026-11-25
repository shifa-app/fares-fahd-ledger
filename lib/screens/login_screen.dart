import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../db/ledger_db.dart';
import '../widgets/app_footer.dart';
import 'terms_screen.dart';

/// Simple entry screen: the personal email is saved locally on the phone
/// and used only as the identity for the email backup. No OTP, no password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSaved});

  final void Function(String email) onSaved;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final trimmed = value.trim();
    if (!trimmed.contains('@')) return false;
    final parts = trimmed.split('@');
    return parts.length == 2 &&
        parts[0].isNotEmpty &&
        parts[1].contains('.');
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _error = 'أدخل إيميلاً صحيحاً، مثال: name@mail.com');
      return;
    }
    await LedgerDb.instance.saveEmail(email);
    widget.onSaved(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  logoHeaderAsset,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                appTagline,
                style: TextStyle(
                  fontSize: 20,
                  color: BrandColors.navy,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                'أدخل إيميلك الشخصي',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'يُحفظ الإيميل على هاتفك فقط، ويُستخدم كهوية للنسخة الاحتياطية. لا توجد كلمة مرور.',
                style: TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'الإيميل الشخصي',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.navy,
                  foregroundColor: BrandColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'دخول',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'شروط الاستخدام',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
