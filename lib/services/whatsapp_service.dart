import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../logic/balance.dart';
import '../models.dart';

/// Plain WhatsApp sharing through wa.me links (no Business API).
class WhatsappService {
  /// Builds the reminder text for a person.
  /// [businessName] comes from the saved profile (the app name when
  /// empty); the rights line is always «فارس وفهد للحسابات».
  static String reminderMessage(
    Person person,
    double balance, {
    String businessName = appName,
  }) {
    final word = balanceWord(balance);
    final amount = formatMoney(balance.abs());
    final String body;
    if (balance == 0) {
      body =
          'السلام عليكم ${person.name}، حسابك في $businessName متعادل، لا يوجد مبلغ مستحق. شكراً لك.';
    } else if (balance > 0) {
      body =
          'السلام عليكم ${person.name}، نذكّرك بأن المبلغ المستحق عليك في $businessName هو $amount ($word). شكراً لك.';
    } else {
      body =
          'السلام عليكم ${person.name}، نعلمك بأن المبلغ المستحق لك في $businessName هو $amount ($word). شكراً لك.';
    }
    return '$body\n$appRightsLine';
  }

  /// Normalizes an Egyptian phone number to international format for wa.me.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.startsWith('0')) return '20${digits.substring(1)}';
    return digits;
  }

  /// Opens plain WhatsApp with the message ready to send.
  /// Tries, in order: the WhatsApp app, the wa.me link in the browser,
  /// and finally the system share sheet (so the user can pick WhatsApp
  /// manually). Returns false only when nothing could be opened.
  static Future<bool> openWhatsApp(String phone, String message) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return false;
    final encoded = Uri.encodeComponent(message);
    try {
      final appUri =
          Uri.parse('whatsapp://send?phone=$normalized&text=$encoded');
      if (await canLaunchUrl(appUri)) {
        return await launchUrl(appUri, mode: LaunchMode.externalApplication);
      }
      final webUri = Uri.parse('https://wa.me/$normalized?text=$encoded');
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
      await SharePlus.instance.share(ShareParams(text: message));
      return true;
    } catch (_) {
      return false;
    }
  }
}
