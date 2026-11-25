import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/screens/terms_screen.dart';
import 'package:ledger/widgets/app_footer.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('terms asset (assets/terms_of_use_ar.md)', () {
    test('loads and contains the title and support email', () async {
      // Read the bundled file from disk: awaiting rootBundle in a
      // plain test() leaves the test binding's asset channel in a
      // state where the TermsScreen widget test's FutureBuilder
      // never completes afterwards (verified: progress spinner
      // stuck for 10 pumps). The widget test below covers the
      // rootBundle path instead.
      final text = await File('assets/terms_of_use_ar.md').readAsString();
      expect(text, contains('شروط الاستخدام'));
      expect(text, contains('Faresosama1919@gmail.com'));
      // 15 sections, Egyptian law as governing law (section 14).
      expect('## '.allMatches(text).length, 15);
      expect(text, contains('جمهورية مصر العربية'));
      // The screen's loader reads the same asset.
      expect(TermsScreen.assetPath, 'assets/terms_of_use_ar.md');
    });
  });

  group('AppFooter widget', () {
    testWidgets('shows the rights line and the credit line', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppFooter()),
        ),
      );
      expect(find.text(AppFooter.rightsLine), findsOneWidget);
      expect(find.text(AppFooter.creditLine), findsOneWidget);
      expect(
        find.text('جميع الحقوق محفوظة © فارس وفهد للحسابات'),
        findsOneWidget,
      );
      expect(find.text('برمجة وتصميم أبو فارس'), findsOneWidget);
    });
  });

  group('TermsScreen widget', () {
    testWidgets('shows the title and the bundled text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsScreen()),
      );
      // The asset loads asynchronously; pump until the body text
      // appears (bounded loop, not pumpAndSettle: while the asset
      // loads, a CircularProgressIndicator spins forever, and
      // pumpAndSettle never settles on a never-ending animation).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .textContaining('Faresosama1919@gmail.com')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(find.text('شروط الاستخدام'), findsWidgets);
      expect(
        find.textContaining('Faresosama1919@gmail.com'),
        findsOneWidget,
      );
      expect(find.textContaining('جمهورية مصر العربية'), findsWidgets);
    });
  });
}
