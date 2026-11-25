import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/logic/balance.dart';

void main() {
  group('totalFlow', () {
    test('empty entries give zero inflow and outflow', () {
      final flow = totalFlow([]);
      expect(flow.inflow, 0);
      expect(flow.outflow, 0);
    });

    test('only a received payment counts as inflow (credit sale is debt, not cash)', () {
      final flow = totalFlow([
        (type: TxType.saleCredit, amount: 500),
        (type: TxType.paymentReceived, amount: 200),
      ]);
      expect(flow.inflow, 200);
      expect(flow.outflow, 0);
    });

    test('only a paid payment counts as outflow (credit purchase is debt, not cash)', () {
      final flow = totalFlow([
        (type: TxType.purchaseCredit, amount: 1000),
        (type: TxType.paymentPaid, amount: 400),
      ]);
      expect(flow.inflow, 0);
      expect(flow.outflow, 400);
    });

    test('user case: sales 15 + 75 and payment 50 give inflow 50, not 140', () {
      final flow = totalFlow([
        (type: TxType.saleCredit, amount: 15),
        (type: TxType.saleCredit, amount: 75),
        (type: TxType.paymentReceived, amount: 50),
      ]);
      expect(flow.inflow, 50);
      expect(flow.outflow, 0);
    });

    test('discount is excluded from flows', () {
      final flow = totalFlow([
        (type: TxType.discount, amount: 50),
      ]);
      expect(flow.inflow, 0);
      expect(flow.outflow, 0);
    });
  });

  group('lastDaysFlows', () {
    final today = DateTime(2026, 11, 24);

    test('empty entries give seven zero days ending today', () {
      final days = lastDaysFlows([], 7, today: today);
      expect(days.length, 7);
      expect(days.last.date, DateTime(2026, 11, 24));
      expect(days.first.date, DateTime(2026, 11, 18));
      for (final d in days) {
        expect(d.inflow, 0);
        expect(d.outflow, 0);
      }
    });

    test('entries are bucketed by calendar day', () {
      final days = lastDaysFlows([
        (
          type: TxType.paymentReceived,
          amount: 500,
          date: DateTime(2026, 11, 24),
        ),
        (
          type: TxType.paymentPaid,
          amount: 100,
          date: DateTime(2026, 11, 22),
        ),
        (
          type: TxType.paymentReceived,
          amount: 9999,
          date: DateTime(2026, 11, 10),
        ),
      ], 7, today: today);
      expect(days.last.inflow, 500);
      expect(days[4].outflow, 100);
      expect(days[4].inflow, 0);
      // The 10 Nov entry is outside the 7-day window: no day holds it.
      expect(days.fold<double>(0, (s, d) => s + d.inflow), 500);
    });
  });
}
