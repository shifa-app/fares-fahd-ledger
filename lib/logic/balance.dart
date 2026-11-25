// Pure balance logic for the ledger (no Flutter, no database).
//
// Signed balance convention:
//   > 0  => "عليه" (the person owes us: e.g. customer bought on credit
//             and has not paid yet)
//   < 0  => "له"    (we owe the person: e.g. supplier sold to us on
//             credit and we have not paid yet)
//   == 0 => "متعادل"
//
// All amounts are in Egyptian pounds (جنيه).

enum PersonType { customer, supplier }

PersonType personTypeFromCode(String code) =>
    code == 'supplier' ? PersonType.supplier : PersonType.customer;

extension PersonTypeLabel on PersonType {
  String get label => switch (this) {
        PersonType.customer => 'عميل',
        PersonType.supplier => 'مورّد',
      };

  String get code => switch (this) {
        PersonType.customer => 'customer',
        PersonType.supplier => 'supplier',
      };
}

enum TxType {
  saleCredit,
  purchaseCredit,
  paymentReceived,
  paymentPaid,
  discount,
}

TxType txTypeFromCode(String code) => switch (code) {
      'purchaseCredit' => TxType.purchaseCredit,
      'paymentReceived' => TxType.paymentReceived,
      'paymentPaid' => TxType.paymentPaid,
      'discount' => TxType.discount,
      _ => TxType.saleCredit,
    };

extension TxTypeLabel on TxType {
  String get label => switch (this) {
        TxType.saleCredit => 'بيع آجل',
        TxType.purchaseCredit => 'شراء آجل',
        TxType.paymentReceived => 'دفعة نقدية مستلمة',
        TxType.paymentPaid => 'دفعة نقدية مدفوعة',
        TxType.discount => 'خصم',
      };

  String get code => switch (this) {
        TxType.saleCredit => 'saleCredit',
        TxType.purchaseCredit => 'purchaseCredit',
        TxType.paymentReceived => 'paymentReceived',
        TxType.paymentPaid => 'paymentPaid',
        TxType.discount => 'discount',
      };

  /// Short label for one-line list rows that also carry a date
  /// («دفعة مستلمة • 24-11-2026»): the full label
  /// («دفعة نقدية مستلمة») is too long and truncates the date.
  /// Used in the recent-activity list and the person history only;
  /// the full label stays wherever it stands alone (dialogs, PDF).
  String get shortLabel => switch (this) {
        TxType.paymentReceived => 'دفعة مستلمة',
        TxType.paymentPaid => 'دفعة مدفوعة',
        _ => label,
      };
}

/// Transaction types allowed for each person type.
List<TxType> allowedTxTypes(PersonType person) =>
    person == PersonType.customer
        ? const [TxType.saleCredit, TxType.paymentReceived, TxType.discount]
        : const [TxType.purchaseCredit, TxType.paymentPaid, TxType.discount];

/// Signed effect of one transaction on the person's balance.
double signedDelta(TxType type, PersonType person, double amount) {
  switch (type) {
    case TxType.saleCredit:
      return amount;
    case TxType.purchaseCredit:
      return -amount;
    case TxType.paymentReceived:
      return -amount;
    case TxType.paymentPaid:
      return amount;
    case TxType.discount:
      return person == PersonType.customer ? -amount : amount;
  }
}

/// Running balance after each transaction, in order.
List<double> runningBalances(List<double> deltas) {
  final result = <double>[];
  var total = 0.0;
  for (final d in deltas) {
    total += d;
    result.add(total);
  }
  return result;
}

/// Final balance from a list of signed deltas.
double finalBalance(List<double> deltas) =>
    deltas.fold(0.0, (sum, d) => sum + d);

/// "عليه" when the person owes us, "له" when we owe them.
String balanceWord(double balance) {
  if (balance > 0) return 'عليه';
  if (balance < 0) return 'له';
  return 'متعادل';
}

/// Dashboard net-balance badge (NOT a person's balance):
/// the dashboard total is money in the market, so a positive net is
/// our customers' debt to us — «مديونية عملاء» — not a bare «عليه»
/// with no subject. Mirrored for a negative net («مديونية علينا»).
/// Per-person balances keep balanceWord («عليه» / «له») unchanged.
String netBalanceLabel(double net) {
  if (net > 0) return 'مديونية عملاء';
  if (net < 0) return 'مديونية علينا';
  return 'متعادل';
}

/// Date as one fixed line: 24-11-2026 (dd-MM-yyyy).
String formatDayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.year}';

/// Short clarification under a transaction amount, so the + / - sign
/// is never read alone: a credit sale puts debt «على العميل», a cash
/// payment received is «سداد», and so on for the other types.
String txClarification(TxType type, PersonType person) {
  switch (type) {
    case TxType.saleCredit:
      return 'على العميل';
    case TxType.purchaseCredit:
      return 'دين علينا';
    case TxType.paymentReceived:
      return 'سداد';
    case TxType.paymentPaid:
      return 'سداد للمورّد';
    case TxType.discount:
      return person == PersonType.customer ? 'خصم من الدين' : 'خصم من المستحق';
  }
}

/// People-tab filters (filter chips under the search bar).
/// «له رصيد» = signed balance < 0 (we owe them, balanceWord «له»).
/// «عليه رصيد» = signed balance > 0 (they owe us, «عليه»).
enum PersonFilter { all, customers, suppliers, owedToThem, owedToUs }

extension PersonFilterLabel on PersonFilter {
  String get label => switch (this) {
        PersonFilter.all => 'الكل',
        PersonFilter.customers => 'عملاء',
        PersonFilter.suppliers => 'موردين',
        PersonFilter.owedToThem => 'له رصيد',
        PersonFilter.owedToUs => 'عليه رصيد',
      };
}

/// Pure predicate for one person, used by the filter chips.
bool personMatchesFilter({
  required PersonType type,
  required double balance,
  required PersonFilter filter,
}) =>
    switch (filter) {
      PersonFilter.all => true,
      PersonFilter.customers => type == PersonType.customer,
      PersonFilter.suppliers => type == PersonType.supplier,
      PersonFilter.owedToThem => balance < 0,
      PersonFilter.owedToUs => balance > 0,
    };

/// Totals across all persons' final balances.
({double owedToUs, double weOwe, double net}) summarizeBalances(
  List<double> balances,
) {
  var owedToUs = 0.0;
  var weOwe = 0.0;
  for (final b in balances) {
    if (b > 0) {
      owedToUs += b;
    } else if (b < 0) {
      weOwe += -b;
    }
  }
  return (owedToUs: owedToUs, weOwe: weOwe, net: owedToUs - weOwe);
}

/// Format an amount in Egyptian pounds (no decimals for whole pounds).
String formatMoney(double amount) {
  final abs = amount.abs();
  final text = abs == abs.truncateToDouble()
      ? _withThousands(abs.truncate())
      : abs.toStringAsFixed(2);
  return '$text جنيه';
}

String _withThousands(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

// ---- Dashboard flows (pure, computed from real entries only) ----
//
// Cash-flow classification used by the dashboard charts:
//   inflow  = cash payment received ONLY. A sale on credit is NOT
//             cash in yet — it is a debt on the customer, and counting
//             it as inflow double-counts the same money once the
//             customer pays (e.g. sales 90 + payment 50 showed 140).
//   outflow = cash payment paid ONLY. A purchase on credit is NOT
//             cash out yet — it is a debt we owe the supplier.
//   saleCredit, purchaseCredit and discount are balance adjustments,
//   not flows, and are excluded.
// No demo or placeholder amounts are ever used: with no entries every
// total is zero.

/// Inflow / outflow contribution of one entry amount.
({double inflow, double outflow}) flowOf(TxType type, double amount) =>
    switch (type) {
      TxType.saleCredit => (inflow: 0, outflow: 0),
      TxType.paymentReceived => (inflow: amount, outflow: 0),
      TxType.purchaseCredit => (inflow: 0, outflow: 0),
      TxType.paymentPaid => (inflow: 0, outflow: amount),
      TxType.discount => (inflow: 0, outflow: 0),
    };

/// Total inflow / outflow across a list of entries.
/// Entries are passed as plain records to avoid a models import cycle.
({double inflow, double outflow}) totalFlow(
  List<({TxType type, double amount})> entries,
) {
  var inflow = 0.0;
  var outflow = 0.0;
  for (final e in entries) {
    final f = flowOf(e.type, e.amount);
    inflow += f.inflow;
    outflow += f.outflow;
  }
  return (inflow: inflow, outflow: outflow);
}

/// One day of dashboard flow.
class DayFlow {
  const DayFlow({
    required this.date,
    required this.inflow,
    required this.outflow,
  });

  final DateTime date;
  final double inflow;
  final double outflow;
}

/// Daily inflow / outflow for the last [days] days (oldest first),
/// ending today. Days without entries report zero.
List<DayFlow> lastDaysFlows(
  List<({TxType type, double amount, DateTime date})> entries,
  int days, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final base = DateTime(now.year, now.month, now.day);
  final result = <DayFlow>[];
  for (var i = days - 1; i >= 0; i--) {
    final day = base.subtract(Duration(days: i));
    var inflow = 0.0;
    var outflow = 0.0;
    for (final e in entries) {
      if (e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day) {
        final f = flowOf(e.type, e.amount);
        inflow += f.inflow;
        outflow += f.outflow;
      }
    }
    result.add(DayFlow(date: day, inflow: inflow, outflow: outflow));
  }
  return result;
}
