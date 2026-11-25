import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/app_info.dart';
import 'package:ledger/db/ledger_db.dart';
import 'package:ledger/logic/balance.dart';
import 'package:ledger/models.dart';
import 'package:ledger/services/profile_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('ledger-test-');
    databaseFactory = databaseFactoryFfi;
    await databaseFactoryFfi.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    final db = await LedgerDb.instance.database;
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> wipe() async {
    final db = await LedgerDb.instance.database;
    await db.delete('entries');
    await db.delete('persons');
    await db.delete('settings');
  }

  group('recentPersonsWithLatestEntry (one row per person)', () {
    test('a person with several entries appears once, with the latest',
        () async {
      await wipe();
      final db = LedgerDb.instance;
      final aId = await db.insertPerson(
        const Person(
          name: 'عميل أ',
          phone: '',
          address: '',
          type: PersonType.customer,
        ),
      );
      final bId = await db.insertPerson(
        const Person(
          name: 'عميل ب',
          phone: '',
          address: '',
          type: PersonType.customer,
        ),
      );
      // A: three entries — the latest is 90 on 2026-11-25.
      await db.insertEntry(
        LedgerEntry(
          personId: aId,
          type: TxType.saleCredit,
          amount: 75,
          date: DateTime(2026, 11, 20),
        ),
      );
      await db.insertEntry(
        LedgerEntry(
          personId: aId,
          type: TxType.saleCredit,
          amount: 55,
          date: DateTime(2026, 11, 21),
        ),
      );
      await db.insertEntry(
        LedgerEntry(
          personId: aId,
          type: TxType.saleCredit,
          amount: 90,
          date: DateTime(2026, 11, 25),
        ),
      );
      // B: a single entry on 2026-11-24.
      await db.insertEntry(
        LedgerEntry(
          personId: bId,
          type: TxType.paymentReceived,
          amount: 100,
          date: DateTime(2026, 11, 24),
        ),
      );

      final recent = await db.recentPersonsWithLatestEntry();
      expect(recent.length, 2);
      expect(recent[0].person.name, 'عميل أ');
      expect(recent[0].entry.amount, 90);
      expect(recent[0].entry.date, DateTime(2026, 11, 25));
      expect(recent[1].person.name, 'عميل ب');
      expect(recent[1].entry.amount, 100);
    });

    test('ordering follows the latest activity date', () async {
      await wipe();
      final db = LedgerDb.instance;
      final aId = await db.insertPerson(
        const Person(
          name: 'عميل أ',
          phone: '',
          address: '',
          type: PersonType.customer,
        ),
      );
      final bId = await db.insertPerson(
        const Person(
          name: 'عميل ب',
          phone: '',
          address: '',
          type: PersonType.customer,
        ),
      );
      await db.insertEntry(
        LedgerEntry(
          personId: aId,
          type: TxType.saleCredit,
          amount: 50,
          date: DateTime(2026, 11, 25),
        ),
      );
      await db.insertEntry(
        LedgerEntry(
          personId: bId,
          type: TxType.paymentReceived,
          amount: 30,
          date: DateTime(2026, 11, 26),
        ),
      );

      final recent = await db.recentPersonsWithLatestEntry();
      expect(recent.length, 2);
      expect(recent[0].person.name, 'عميل ب');
      expect(recent[0].entry.amount, 30);
      expect(recent[1].person.name, 'عميل أ');
    });
  });

  group('profile fields (save / load / business-name fallback)', () {
    test('profile fields save and load', () async {
      await wipe();
      await ProfileService.instance.saveProfile(
        name: 'أسامة',
        businessName: 'نشاطي',
        workPhone: '01000000000',
      );
      final loaded = await ProfileService.instance.loadProfile();
      expect(loaded.name, 'أسامة');
      expect(loaded.businessName, 'نشاطي');
      expect(loaded.workPhone, '01000000000');
      expect(await ProfileService.instance.businessName(), 'نشاطي');
    });

    test('business name falls back to the app name when empty', () async {
      await wipe();
      expect(await ProfileService.instance.businessName(), appName);
      expect(ProfileService.resolveBusinessName(null), appName);
      expect(ProfileService.resolveBusinessName(''), appName);
      expect(ProfileService.resolveBusinessName('   '), appName);
      expect(ProfileService.resolveBusinessName('نشاطي'), 'نشاطي');
    });
  });
}
