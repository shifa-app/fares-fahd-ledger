import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/app_info.dart';
import 'package:ledger/logic/balance.dart';
import 'package:ledger/widgets/app_footer.dart';
import 'package:ledger/widgets/charts.dart';
import 'package:material_ui/material_ui.dart';

/// Regression test for the 1.0.6 dashboard collapse (user report
/// 2026-11-25: main interface "completely destroyed" — welcome card only,
/// chart painted over it or absent, stat cards / quick actions / activity
/// list / footer all missing, appearance varying between runs, with data
/// and without data).
///
/// Root cause (confirmed experimentally): `CrossAxisAlignment.stretch`
/// on the stat-cards Row (home_screen.dart:912, added in 1.0.6) inside
/// a vertically unbounded SingleChildScrollView gives the flex children
/// `BoxConstraints(minHeight: infinity)` (see RenderFlex
/// _constraintsForFlexChild / _constraintsForNonFlexChild in flex.dart),
/// which throws "BoxConstraints forces an infinite height." in debug
/// and leaves the tree partially laid out in release.
///
/// Fix (1.0.7): the stat Row is wrapped in `IntrinsicHeight`, which
/// bounds the Row's height to the tallest card, so stretch works and
/// the three cards stay equal in height — the 1.0.6 goal is preserved.
/// This file mirrors that fixed structure in `_DashboardCopy`.
///
/// NOTE: the two real-HomeScreen tests that used to live here were
/// removed in 1.0.7. They failed only because of a test-environment
/// limitation — `_load` uses sqflite_ffi async I/O, which never
/// completes inside testWidgets' FakeAsync zone, so the spinner never
/// leaves and the dashboard is never pumped (proven by the temporary
/// diagnostic test dashboard_diag_test.dart, deleted with them). That
/// is not an app bug: on a real device `_load` completes and the data
/// shows (the user restored his data from Google on 2026-11-25).
/// The structural copy below is the regression test instead.

void main() {
  /// The user's own data: inflow 220 on 25 Nov only, outflow 0,
  /// net balanced ("متعادل" badge — the tallest stat card).
  List<DayFlow> userDays() => List<DayFlow>.generate(7, (i) {
        final day = DateTime(2026, 11, 19 + i);
        return DayFlow(
          date: day,
          inflow: i == 6 ? 220 : 0,
          outflow: 0,
        );
      });

  /// The user's phone geometry: 1049x2048 physical, ~2.77 density
  /// => ~379x739 logical.
  void setPhoneGeometry(WidgetTester tester) {
    tester.view.physicalSize = const Size(1049, 2048);
    tester.view.devicePixelRatio = 2.77;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Rect? rectOf(WidgetTester tester, Finder finder) {
    if (finder.evaluate().isEmpty) return null;
    try {
      return tester.getRect(finder);
    } catch (_) {
      // RenderBox was not laid out (expected after a layout failure).
      return null;
    }
  }

  /// Drain every recorded test exception (a layout failure cascades
  /// into many). Returns them in order.
  List<Object?> drainExceptions(WidgetTester tester, String label) {
    final errors = <Object?>[];
    Object? e;
    while ((e = tester.takeException()) != null && errors.length < 30) {
      errors.add(e);
    }
    // ignore: avoid_print
    print('EXCEPTIONS ($label): count=${errors.length}');
    return errors;
  }

  group('fixed dashboard structure (1.0.7 regression)', () {
    testWidgets('IntrinsicHeight + stretch: no exception, all sections '
        'laid out, no overlaps', (tester) async {
      setPhoneGeometry(tester);
      final days = userDays();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: _DashboardCopy(days: days),
          ),
        ),
      );
      await tester.pump();
      final errors = drainExceptions(tester, 'fixed structure');
      expect(errors, isEmpty,
          reason: 'fixed dashboard threw: ${errors.firstOrNull}');

      // Every section present.
      expect(find.text('ملخص الحسابات العام'), findsOneWidget);
      expect(find.text('إجمالي الوارد'), findsOneWidget);
      expect(find.text('إجمالي الصادر'), findsOneWidget);
      expect(find.text('صافي المستحقات'), findsOneWidget);
      expect(find.text('معاملة جديدة'), findsOneWidget);
      expect(find.text('الأشخاص'), findsOneWidget);
      expect(find.text('التقارير'), findsOneWidget);
      expect(find.text('قائمة النشاط الأخير'), findsOneWidget);
      expect(find.text('حركة آخر 7 أيام'), findsOneWidget);
      expect(find.byType(LineFlowChart), findsOneWidget);
      expect(find.byType(BarFlowChart), findsOneWidget);
      expect(find.text(AppFooter.rightsLine), findsOneWidget);

      // Every section laid out (not null = has a real box).
      final welcome = rectOf(
        tester,
        find.ancestor(
          of: find.text('ملخص الحسابات العام'),
          matching: find.byType(Card),
        ),
      );
      final inflow = rectOf(
        tester,
        find.ancestor(
          of: find.text('إجمالي الوارد'),
          matching: find.byType(Card),
        ),
      );
      final outflow = rectOf(
        tester,
        find.ancestor(
          of: find.text('إجمالي الصادر'),
          matching: find.byType(Card),
        ),
      );
      final net = rectOf(
        tester,
        find.ancestor(
          of: find.text('صافي المستحقات'),
          matching: find.byType(Card),
        ),
      );
      final chartCard = rectOf(
        tester,
        find.ancestor(
          of: find.text('حركة آخر 7 أيام'),
          matching: find.byType(Card),
        ),
      );
      final line = rectOf(tester, find.byType(LineFlowChart));
      final bar = rectOf(tester, find.byType(BarFlowChart));
      final footer = rectOf(tester, find.text(AppFooter.rightsLine));
      expect(welcome, isNotNull);
      expect(inflow, isNotNull);
      expect(outflow, isNotNull);
      expect(net, isNotNull);
      expect(chartCard, isNotNull);
      expect(line, isNotNull);
      expect(bar, isNotNull);
      expect(footer, isNotNull);

      // 1.0.6 goal preserved: the three stat cards share one height
      // (the tallest — the "متعادل" card).
      expect((inflow!.height - net!.height).abs(), lessThan(0.5));
      expect((inflow.height - outflow!.height).abs(), lessThan(0.5));

      // No overlaps: chart below the welcome card, line chart above
      // the bar chart.
      expect(chartCard!.overlaps(welcome!), isFalse,
          reason: 'chart card overlaps the welcome card');
      expect(chartCard.top, greaterThanOrEqualTo(welcome.bottom));
      expect(line!.overlaps(bar!), isFalse,
          reason: 'line chart overlaps the bar chart');
      expect(bar.top, greaterThanOrEqualTo(line.bottom));

      // Sections in vertical order.
      expect(inflow.top, greaterThanOrEqualTo(welcome.bottom));
      expect(chartCard.top, greaterThan(inflow.bottom));
      expect(footer!.top, greaterThan(chartCard.bottom));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

/// Structural mirror of _buildDashboard (home_screen.dart:858+) with
/// the 1.0.7 fix applied — stat Row wrapped in IntrinsicHeight,
/// mirroring production code. Test-only.
class _DashboardCopy extends StatelessWidget {
  const _DashboardCopy({required this.days});

  final List<DayFlow> days;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: BrandColors.navy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: BrandColors.gold, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Image.asset(logoHeaderAsset, height: 96),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملخص الحسابات العام',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: BrandColors.gold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          appTagline,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCardCopy(
                    label: 'إجمالي الوارد',
                    amount: '220 جنيه',
                    color: BrandColors.success,
                    bg: BrandColors.successBg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCardCopy(
                    label: 'إجمالي الصادر',
                    amount: '0 جنيه',
                    color: BrandColors.danger,
                    bg: BrandColors.dangerBg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCardCopy(
                    label: 'صافي المستحقات',
                    amount: '0 جنيه',
                    color: Colors.grey.shade700,
                    bg: Colors.grey.shade200,
                    badge: 'متعادل',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'الوارد والصادر نقدي فقط — البيع والشراء الآجل دين وليس تدفقاً نقدياً.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child:
                    _QuickCopy(label: 'معاملة جديدة', asset: iconWalletAsset),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickCopy(label: 'الأشخاص', asset: iconPeopleAsset),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickCopy(label: 'التقارير', asset: iconChartAsset),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'قائمة النشاط الأخير',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child:
                    Text('لا توجد حركات بعد', style: TextStyle(fontSize: 19)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حركة آخر 7 أيام',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LineFlowChart(days: days),
                  const SizedBox(height: 8),
                  const Text(
                    'الوارد والصادر يومياً',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  BarFlowChart(days: days),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const AppFooter(),
        ],
      ),
    );
  }
}

class _StatCardCopy extends StatelessWidget {
  const _StatCardCopy({
    required this.label,
    required this.amount,
    required this.color,
    required this.bg,
    this.badge,
  });

  final String label;
  final String amount;
  final Color color;
  final Color bg;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            if (badge != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickCopy extends StatelessWidget {
  const _QuickCopy({required this.label, required this.asset});

  final String label;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.navy,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BrandColors.navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
