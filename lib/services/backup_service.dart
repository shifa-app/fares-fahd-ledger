import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../db/ledger_db.dart';

/// Email backup: exports all data as a JSON file and shares it through
/// the system share sheet (the user picks their own email app).
/// Nothing is sent directly from the code and no password is stored.
class BackupService {
  static Future<String> exportJson() async {
    final data = await LedgerDb.instance.exportAll();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<String> writeBackupFile(String json) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File(
      p.join(Directory.systemTemp.path, 'fares-fahd-backup-$stamp.json'),
    );
    await file.writeAsString(json);
    return file.path;
  }

  /// Opens the system share sheet with the JSON backup file attached.
  /// The user chooses their personal email app and their own address.
  static Future<void> shareBackup() async {
    final json = await exportJson();
    final path = await writeBackupFile(json);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية - فارس وفهد للحسابات',
        text: 'نسخة احتياطية من فارس وفهد للحسابات. احتفظ بهذا الملف لاسترجاع بياناتك.',
      ),
    );
  }

  /// Restores data from JSON text pasted by the user
  /// (open the backup file from the email and copy its content).
  static Future<({int persons, int entries})> restoreFromJson(
    String json,
  ) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('ملف النسخة غير صالح');
    }
    return LedgerDb.instance.importAll(decoded);
  }
}
