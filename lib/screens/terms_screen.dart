import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_info.dart';

/// «شروط الاستخدام» — full terms text bundled in the app (assets),
/// readable offline. The text is the user-approved file, copied
/// verbatim to assets/terms_of_use_ar.md — never edited in code.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String assetPath = 'assets/terms_of_use_ar.md';

  /// Loads the bundled terms text. Kept static so tests can call it
  /// without pumping the screen.
  static Future<String> loadTermsText() =>
      rootBundle.loadString(assetPath);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        title: const Text('شروط الاستخدام'),
      ),
      body: FutureBuilder<String>(
        future: loadTermsText(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'تعذّر تحميل شروط الاستخدام',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _termsWidgets(snapshot.data!),
            ),
          );
        },
      ),
    );
  }

  /// Minimal markdown rendering (no new dependency): `# ` is the
  /// document title, `## ` is a gold section heading, everything
  /// else is body text in Cairo.
  List<Widget> _termsWidgets(String text) {
    final widgets = <Widget>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
      } else if (line.startsWith('# ')) {
        widgets.add(
          Text(
            line.substring(2).trim(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: BrandColors.navy,
            ),
            textAlign: TextAlign.center,
          ),
        );
        widgets.add(const SizedBox(height: 12));
      } else if (line.startsWith('## ')) {
        widgets.add(
          Text(
            line.substring(3).trim(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: BrandColors.gold,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 6));
      } else {
        widgets.add(
          Text(
            line,
            style: const TextStyle(fontSize: 17, height: 1.6),
          ),
        );
      }
    }
    return widgets;
  }
}
