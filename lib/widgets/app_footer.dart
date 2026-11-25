import 'package:material_ui/material_ui.dart';

/// App footer: rights line + «برمجة وتصميم أبو فارس».
/// Shown at the bottom of the login screen and at the end of the
/// home screen content (dashboard + persons tab), above the bottom
/// navigation bar.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const String rightsLine =
      'جميع الحقوق محفوظة © فارس وفهد للحسابات';
  static const String creditLine = 'برمجة وتصميم أبو فارس';

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rightsLine,
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            creditLine,
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
