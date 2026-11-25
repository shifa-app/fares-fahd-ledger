import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../logic/balance.dart';
import '../models.dart';

/// Local SQLite database (Offline-First). No server, no network.
class LedgerDb {
  LedgerDb._();

  static final LedgerDb instance = LedgerDb._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'ledger.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE persons(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT ''
          )''');
        await db.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            personId INTEGER NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            FOREIGN KEY(personId) REFERENCES persons(id)
          )''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
      },
    );
    _db = db;
    return db;
  }

  // ---- Identity (personal email, used only for the backup) ----

  Future<String?> getEmail() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: const ['email'],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> saveEmail(String email) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'email', 'value': email.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearEmail() async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: const ['email']);
  }

  // ---- Generic settings (cloud backup state, etc.) ----

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- Persons ----

  Future<int> insertPerson(Person person) async {
    final db = await database;
    return db.insert('persons', person.toMap()..remove('id'));
  }

  Future<void> updatePerson(Person person) async {
    final db = await database;
    await db.update(
      'persons',
      person.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  Future<void> deletePerson(int personId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('entries', where: 'personId = ?', whereArgs: [personId]);
      await txn.delete('persons', where: 'id = ?', whereArgs: [personId]);
    });
  }

  Future<List<Person>> searchPersons(String query) async {
    final db = await database;
    final q = query.trim();
    final List<Map<String, Object?>> rows;
    if (q.isEmpty) {
      rows = await db.query('persons', orderBy: 'name ASC');
    } else {
      final like = '%$q%';
      rows = await db.query(
        'persons',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: [like, like],
        orderBy: 'name ASC',
      );
    }
    return rows.map(Person.fromMap).toList();
  }

  // ---- Entries ----

  Future<int> insertEntry(LedgerEntry entry) async {
    final db = await database;
    return db.insert('entries', entry.toMap()..remove('id'));
  }

  Future<void> deleteEntry(int entryId) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [entryId]);
  }

  Future<List<LedgerEntry>> entriesForPerson(int personId) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'personId = ?',
      whereArgs: [personId],
      orderBy: 'date ASC, id ASC',
    );
    return rows.map(LedgerEntry.fromMap).toList();
  }

  /// Counts of persons and entries (used by the cloud backup status
  /// screen — real local data, no demo numbers).
  Future<({int persons, int entries})> counts() async {
    final db = await database;
    final p = await db.rawQuery('SELECT COUNT(*) AS c FROM persons');
    final e = await db.rawQuery('SELECT COUNT(*) AS c FROM entries');
    return (
      persons: Sqflite.firstIntValue(p) ?? 0,
      entries: Sqflite.firstIntValue(e) ?? 0,
    );
  }

  /// Every entry in the ledger (used by the dashboard charts).
  Future<List<LedgerEntry>> allEntries() async {
    final db = await database;
    final rows = await db.query('entries', orderBy: 'date ASC, id ASC');
    return rows.map(LedgerEntry.fromMap).toList();
  }

  /// Most recent entries together with their person, newest first.
  /// Used by the dashboard "recent activity" list.
  Future<List<({LedgerEntry entry, Person person})>>
      recentEntriesWithPersons({int limit = 8}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT e.id AS eid, e.personId, e.type, e.amount, e.note, e.date,
             p.id AS pid, p.name, p.phone, p.address, p.type AS ptype,
             p.notes
      FROM entries e JOIN persons p ON p.id = e.personId
      ORDER BY e.date DESC, e.id DESC LIMIT ?
      ''',
      [limit],
    );
    return rows.map((row) {
      final entry = LedgerEntry.fromMap(<String, Object?>{
        'id': row['eid'],
        'personId': row['personId'],
        'type': row['type'],
        'amount': row['amount'],
        'note': row['note'],
        'date': row['date'],
      });
      final person = Person.fromMap(<String, Object?>{
        'id': row['pid'],
        'name': row['name'],
        'phone': row['phone'],
        'address': row['address'],
        'type': row['ptype'],
        'notes': row['notes'],
      });
      return (entry: entry, person: person);
    }).toList();
  }

  /// One row per person: each person's latest entry only, with
  /// persons ordered by their latest activity, newest first.
  /// Used by the dashboard "recent activity" list so a person with
  /// many transactions appears once (their latest transaction),
  /// and tapping the row opens their full record.
  Future<List<({LedgerEntry entry, Person person})>>
      recentPersonsWithLatestEntry({int limit = 8}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT e.id AS eid, e.personId, e.type, e.amount, e.note, e.date,
             p.id AS pid, p.name, p.phone, p.address, p.type AS ptype,
             p.notes
      FROM entries e JOIN persons p ON p.id = e.personId
      WHERE e.id = (
        SELECT e2.id FROM entries e2
        WHERE e2.personId = e.personId
        ORDER BY e2.date DESC, e2.id DESC LIMIT 1
      )
      ORDER BY e.date DESC, e.id DESC LIMIT ?
      ''',
      [limit],
    );
    return rows.map((row) {
      final entry = LedgerEntry.fromMap(<String, Object?>{
        'id': row['eid'],
        'personId': row['personId'],
        'type': row['type'],
        'amount': row['amount'],
        'note': row['note'],
        'date': row['date'],
      });
      final person = Person.fromMap(<String, Object?>{
        'id': row['pid'],
        'name': row['name'],
        'phone': row['phone'],
        'address': row['address'],
        'type': row['ptype'],
        'notes': row['notes'],
      });
      return (entry: entry, person: person);
    }).toList();
  }

  /// Final signed balance of one person, computed from their entries.
  Future<double> balanceForPerson(Person person) async {
    final entries = await entriesForPerson(person.id ?? 0);
    final deltas = entries
        .map((e) => signedDelta(e.type, person.type, e.amount))
        .toList();
    return finalBalance(deltas);
  }

  /// Running balances aligned with [entriesForPerson] order.
  Future<List<double>> runningBalancesForPerson(Person person) async {
    final entries = await entriesForPerson(person.id ?? 0);
    final deltas = entries
        .map((e) => signedDelta(e.type, person.type, e.amount))
        .toList();
    return runningBalances(deltas);
  }

  /// All persons with their final balances (optionally filtered by search).
  Future<List<PersonWithBalance>> personsWithBalances({String query = ''}) async {
    final persons = await searchPersons(query);
    final result = <PersonWithBalance>[];
    for (final person in persons) {
      result.add(
        PersonWithBalance(
          person: person,
          balance: await balanceForPerson(person),
        ),
      );
    }
    return result;
  }

  // ---- Backup / restore ----

  Future<Map<String, Object?>> exportAll() async {
    final db = await database;
    final personRows = await db.query('persons', orderBy: 'id ASC');
    final entryRows = await db.query('entries', orderBy: 'id ASC');
    final email = await getEmail();
    return <String, Object?>{
      'app': 'fares-fahd-ledger',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'email': email ?? '',
      'persons': personRows,
      'entries': entryRows,
    };
  }

  /// Replaces all local data with the backup content.
  /// Returns (number of persons, number of entries) restored.
  Future<({int persons, int entries})> importAll(
    Map<String, Object?> data,
  ) async {
    final personsRaw = data['persons'];
    final entriesRaw = data['entries'];
    if (personsRaw is! List || entriesRaw is! List) {
      throw const FormatException('ملف النسخة غير صالح');
    }
    final persons = personsRaw
        .whereType<Map<String, Object?>>()
        .map(Person.fromJson)
        .toList();
    final entries = entriesRaw
        .whereType<Map<String, Object?>>()
        .map(LedgerEntry.fromJson)
        .toList();
    final emailRaw = data['email'];
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('persons');
      for (final person in persons) {
        await txn.insert(
          'persons',
          person.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final entry in entries) {
        await txn.insert(
          'entries',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (emailRaw is String && emailRaw.isNotEmpty) {
        await txn.insert(
          'settings',
          {'key': 'email', 'value': emailRaw},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    return (persons: persons.length, entries: entries.length);
  }
}
