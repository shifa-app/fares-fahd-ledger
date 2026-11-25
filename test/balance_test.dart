import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/logic/balance.dart';

void main() {
  group('signedDelta', () {
    test('customer: sale increases what he owes us', () {
      expect(
        signedDelta(TxType.saleCredit, PersonType.customer, 500),
        500,
      );
    });

    test('customer: received payment decreases his debt', () {
      expect(
        signedDelta(TxType.paymentReceived, PersonType.customer, 200),
        -200,
      );
    });

    test('customer: discount decreases his debt', () {
      expect(
        signedDelta(TxType.discount, PersonType.customer, 50),
        -50,
      );
    });

    test('supplier: purchase increases what we owe', () {
      expect(
        signedDelta(TxType.purchaseCredit, PersonType.supplier, 1000),
        -1000,
      );
    });

    test('supplier: payment we made decreases what we owe', () {
      expect(
        signedDelta(TxType.paymentPaid, PersonType.supplier, 400),
        400,
      );
    });

    test('supplier: discount decreases what we owe', () {
      expect(
        signedDelta(TxType.discount, PersonType.supplier, 100),
        100,
      );
    });
  });

  group('running and final balance', () {
    test('customer: sale 500 then payment 200 then discount 50 = 250', () {
      final deltas = [
        signedDelta(TxType.saleCredit, PersonType.customer, 500),
        signedDelta(TxType.paymentReceived, PersonType.customer, 200),
        signedDelta(TxType.discount, PersonType.customer, 50),
      ];
      expect(runningBalances(deltas), [500, 300, 250]);
      expect(finalBalance(deltas), 250);
      expect(balanceWord(finalBalance(deltas)), 'عليه');
    });

    test('supplier: purchase 1000 then payment 400 = -600 (له)', () {
      final deltas = [
        signedDelta(TxType.purchaseCredit, PersonType.supplier, 1000),
        signedDelta(TxType.paymentPaid, PersonType.supplier, 400),
      ];
      expect(runningBalances(deltas), [-1000, -600]);
      expect(finalBalance(deltas), -600);
      expect(balanceWord(finalBalance(deltas)), 'له');
    });

    test('empty ledger is zero and balanced', () {
      expect(finalBalance([]), 0);
      expect(runningBalances([]), isEmpty);
      expect(balanceWord(0), 'متعادل');
    });
  });

  group('summary', () {
    test('totals across persons', () {
      final result = summarizeBalances([500, -200, 0, 300]);
      expect(result.owedToUs, 800);
      expect(result.weOwe, 200);
      expect(result.net, 600);
    });
  });

  group('allowed transaction types', () {
    test('customer cannot record a purchase', () {
      expect(
        allowedTxTypes(PersonType.customer),
        contains(TxType.saleCredit),
      );
      expect(
        allowedTxTypes(PersonType.customer),
        isNot(contains(TxType.purchaseCredit)),
      );
    });

    test('supplier cannot record a sale', () {
      expect(
        allowedTxTypes(PersonType.supplier),
        contains(TxType.purchaseCredit),
      );
      expect(
        allowedTxTypes(PersonType.supplier),
        isNot(contains(TxType.saleCredit)),
      );
    });
  });

  group('formatMoney', () {
    test('whole pounds without decimals', () {
      expect(formatMoney(500), '500 جنيه');
      expect(formatMoney(1500), '1,500 جنيه');
    });

    test('absolute value is used', () {
      expect(formatMoney(-200), '200 جنيه');
    });
  });
}
