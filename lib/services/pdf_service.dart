import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app_info.dart';
import '../logic/balance.dart';
import '../models.dart';

/// Arabic month names for PDF dates.
const _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Date as "24 نوفمبر 2026".
///
/// Uses only Arabic letters and Latin digits on purpose: the embedded
/// PDF font (Noto Naskh Arabic) has no glyphs for '-', '/', '(', ')' or
/// '•', so ISO dates ("2026-11-24") and parenthesised words rendered as
/// empty boxes in the PDF. Verified against the font files with fontTools.
String arabicDateString(DateTime date) =>
    '${date.day} ${_arabicMonths[date.month - 1]} ${date.year}';

/// Clean PDF statement (كشف حساب) for one person, in Arabic with an
/// embedded Arabic font, shared through the system share sheet.
class PdfService {
  /// PNG bytes of the QR code that opens the permanent releases page
  /// ([appReleasesUrl]) — printed at the bottom of the statement so
  /// the customer can download the app. The URL itself is never
  /// printed as text: the embedded font has no glyphs for '-' or '/'.
  static Future<Uint8List> appDownloadQrBytes({double size = 220}) async {
    final data = await QrPainter(
      data: appReleasesUrl,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    ).toImageData(size);
    final bytes = data?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذّر توليد رمز QR');
    }
    return bytes;
  }

  static Future<Uint8List> buildStatement({
    required Person person,
    required List<LedgerEntry> entries,
    required List<double> running,
    required double balance,
    required String shopName,
  }) async {
    final baseData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );
    final boldData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    );
    final base = pw.Font.ttf(baseData);
    final bold = pw.Font.ttf(boldData);
    final qrBytes = await appDownloadQrBytes();
    final qrImage = pw.MemoryImage(qrBytes);

    final today = arabicDateString(DateTime.now());
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: base, bold: bold),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              shopName,
              style: pw.TextStyle(font: bold, fontSize: 22),
            ),
            pw.Text(
              'كشف حساب  $today',
              style: pw.TextStyle(font: base, fontSize: 13),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Text(
              appRightsLinePdf,
              style: pw.TextStyle(font: base, fontSize: 11),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text(
            'بيانات ${person.type.label}: ${person.name}',
            style: pw.TextStyle(font: bold, fontSize: 16),
          ),
          pw.Text(
            'التليفون: ${person.phone}',
            style: pw.TextStyle(font: base, fontSize: 13),
          ),
          pw.Text(
            'العنوان: ${person.address}',
            style: pw.TextStyle(font: base, fontSize: 13),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2.4),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.8),
            },
            children: [
              _row(
                ['التاريخ', 'الحركة', 'البيان', 'المبلغ', 'الرصيد'],
                bold: true,
                base: base,
                boldFont: bold,
              ),
              for (var i = 0; i < entries.length; i++)
                _row(
                  [
                    arabicDateString(entries[i].date),
                    entries[i].type.label,
                    entries[i].note.isEmpty ? '-' : entries[i].note,
                    formatMoney(
                      signedDelta(entries[i].type, person.type, entries[i].amount),
                    ),
                    formatMoney(running[i]),
                  ],
                  base: base,
                  boldFont: bold,
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'الرصيد النهائي: ${formatMoney(balance.abs())} ${balanceWord(balance)}',
            style: pw.TextStyle(
              font: bold,
              fontSize: 16,
              color: balance > 0
                  ? PdfColors.green800
                  : balance < 0
                      ? PdfColors.red800
                      : PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Image(qrImage, width: 120, height: 120),
                pw.SizedBox(height: 6),
                pw.Text(
                  'حمّل التطبيق',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.TableRow _row(
    List<String> cells, {
    required pw.Font base,
    required pw.Font boldFont,
    bool bold = false,
  }) {
    return pw.TableRow(
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                c,
                style: pw.TextStyle(
                  font: bold ? boldFont : base,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static Future<void> shareStatement({
    required Person person,
    required List<LedgerEntry> entries,
    required List<double> running,
    required double balance,
    required String shopName,
  }) async {
    final bytes = await buildStatement(
      person: person,
      entries: entries,
      running: running,
      balance: balance,
      shopName: shopName,
    );
    final file = File(
      p.join(Directory.systemTemp.path, 'statement-${person.id ?? 0}.pdf'),
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'كشف حساب - ${person.name}',
        text: 'كشف حساب ${person.name} من $shopName',
      ),
    );
  }
}
