import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/logic/balance.dart';
import 'package:ledger/services/pdf_service.dart';

void main() {
  test('PDF strings use only glyphs the embedded font has', () {
    // Characters verified MISSING from NotoNaskhArabic-Regular/Bold
    // (fontTools cmap check 2026-11-24): '-', '/', '(', ')' and '•'
    // rendered as empty boxes in the statement PDF.
    const missing = ['-', '/', '(', ')', '•'];
    final samples = [
      arabicDateString(DateTime(2026, 11, 24)),
      'كشف حساب ${arabicDateString(DateTime(2026, 11, 24))}',
      'الرصيد النهائي: ${formatMoney(40)} ${balanceWord(40)}',
      'الرصيد النهائي: ${formatMoney(600)} ${balanceWord(-600)}',
    ];
    for (final s in samples) {
      for (final c in missing) {
        expect(s.contains(c), isFalse, reason: '«$s» contains «$c»');
      }
    }
    expect(arabicDateString(DateTime(2026, 11, 24)), '24 نوفمبر 2026');
    expect(balanceWord(40), 'عليه');
    expect(balanceWord(-600), 'له');
  });
}
