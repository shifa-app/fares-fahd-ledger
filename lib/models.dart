import 'logic/balance.dart';

class Person {
  const Person({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.type,
    this.notes = '',
  });

  final int? id;
  final String name;
  final String phone;
  final String address;
  final PersonType type;
  final String notes;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'type': type.code,
        'notes': notes,
      };

  factory Person.fromMap(Map<String, Object?> map) => Person(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        address: map['address'] as String? ?? '',
        type: personTypeFromCode(map['type'] as String? ?? 'customer'),
        notes: map['notes'] as String? ?? '',
      );

  Map<String, Object?> toJson() => toMap();

  factory Person.fromJson(Map<String, Object?> json) =>
      Person.fromMap(json);

  Person copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    PersonType? type,
    String? notes,
  }) =>
      Person(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        type: type ?? this.type,
        notes: notes ?? this.notes,
      );
}

class LedgerEntry {
  const LedgerEntry({
    this.id,
    required this.personId,
    required this.type,
    required this.amount,
    this.note = '',
    required this.date,
  });

  final int? id;
  final int personId;
  final TxType type;
  final double amount;
  final String note;
  final DateTime date;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'personId': personId,
        'type': type.code,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String().substring(0, 10),
      };

  factory LedgerEntry.fromMap(Map<String, Object?> map) => LedgerEntry(
        id: map['id'] as int?,
        personId: map['personId'] as int? ?? 0,
        type: txTypeFromCode(map['type'] as String? ?? 'saleCredit'),
        amount: (map['amount'] as num? ?? 0).toDouble(),
        note: map['note'] as String? ?? '',
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, Object?> toJson() => toMap();

  factory LedgerEntry.fromJson(Map<String, Object?> json) =>
      LedgerEntry.fromMap(json);
}

/// A person together with the running balance of their ledger.
class PersonWithBalance {
  const PersonWithBalance({required this.person, required this.balance});

  final Person person;
  final double balance;
}
