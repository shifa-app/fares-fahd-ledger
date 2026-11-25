import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/app_info.dart';
import 'package:ledger/logic/balance.dart';
import 'package:ledger/models.dart';
import 'package:ledger/services/pdf_service.dart';
import 'package:ledger/services/whatsapp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const person = Person(
    name: 'أحمد',
    phone: '01000000000',
    address: '',
    type: PersonType.customer,
  );

  group('reminderMessage (business name + rights line)', () {
    test('custom business name is used, rights line is appended', () {
      final message = WhatsappService.reminderMessage(
        person,
        120,
        businessName: 'نشاطي',
      );
      expect(message, contains('في نشاطي هو'));
      expect(message, isNot(contains('في فارس وفهد للحسابات')));
      expect(message, contains(appRightsLine));
    });

    test('default business name is the app name', () {
      final message = WhatsappService.reminderMessage(person, 0);
      expect(message, contains('حسابك في $appName متعادل'));
      expect(message, contains(appRightsLine));
    });

    test('negative balance wording keeps the business name', () {
      final message = WhatsappService.reminderMessage(
        person,
        -50,
        businessName: 'نشاطي',
      );
      expect(message, contains('في نشاطي هو'));
      expect(message, contains(appRightsLine));
    });
  });

  group('app releases QR (PDF)', () {
    test('releases URL constant is the permanent latest page', () {
      expect(
        appReleasesUrl,
        'https://github.com/shifa-app/fares-fahd-ledger/releases/latest',
      );
    });

    test('QR generation yields non-empty PNG bytes', () async {
      final bytes = await PdfService.appDownloadQrBytes();
      expect(bytes.isNotEmpty, isTrue);
      // PNG magic bytes.
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('statement builds with the QR and the rights footer', () async {
      final bytes = await PdfService.buildStatement(
        person: person,
        entries: [
          LedgerEntry(
            personId: 1,
            type: TxType.saleCredit,
            amount: 100,
            date: DateTime(2026, 11, 25),
          ),
        ],
        running: [100],
        balance: 100,
        shopName: 'نشاطي',
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('PDF rights line uses only glyphs the embedded font has', () {
      // '©', '-', '/', '(', ')' and '•' are missing from
      // NotoNaskhArabic-Regular/Bold (fontTools cmap check).
      for (final c in ['©', '-', '/', '(', ')', '•']) {
        expect(
          appRightsLinePdf.contains(c),
          isFalse,
          reason: '«$c» is missing from the PDF font',
        );
      }
      expect(appRightsLinePdf, contains('فارس وفهد للحسابات'));
    });
  });
}
