import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/app_info.dart';

void main() {
  group('quick action icons (3D gold/blue, user-provided)', () {
    test('wallet and chart icons are bundled and non-empty', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final wallet = await rootBundle.load(iconWalletAsset);
      final chart = await rootBundle.load(iconChartAsset);
      expect(wallet.lengthInBytes, greaterThan(0));
      expect(chart.lengthInBytes, greaterThan(0));
      expect(iconWalletAsset, 'assets/icon_wallet.png');
      expect(iconChartAsset, 'assets/icon_chart.png');
    });

    test('people icon is bundled and non-empty', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final people = await rootBundle.load(iconPeopleAsset);
      expect(people.lengthInBytes, greaterThan(0));
      expect(iconPeopleAsset, 'assets/icon_people.png');
    });
  });
}
