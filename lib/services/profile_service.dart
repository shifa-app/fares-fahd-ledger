import '../app_info.dart';
import '../db/ledger_db.dart';

/// Profile fields (الملف الشخصي): the owner's name, the business
/// name and the work phone, stored in the local settings table with
/// the same pattern as cloud_email. The business name is used in
/// the WhatsApp reminder and in the PDF statement header; when it
/// is empty the app name is the fallback everywhere.
class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  static const String nameKey = 'profile_name';
  static const String businessNameKey = 'profile_business_name';
  static const String workPhoneKey = 'profile_work_phone';

  /// The business name to display: the saved value, or the app
  /// name when nothing was saved yet. Pure, so it is unit-tested.
  static String resolveBusinessName(String? saved) {
    final value = saved?.trim() ?? '';
    return value.isEmpty ? appName : value;
  }

  /// Loads the three saved profile fields (empty when never saved).
  Future<({String name, String businessName, String workPhone})>
      loadProfile() async {
    final db = LedgerDb.instance;
    final name = await db.getSetting(nameKey) ?? '';
    final businessName = await db.getSetting(businessNameKey) ?? '';
    final workPhone = await db.getSetting(workPhoneKey) ?? '';
    return (name: name, businessName: businessName, workPhone: workPhone);
  }

  /// Saves the three profile fields (trims whitespace).
  Future<void> saveProfile({
    required String name,
    required String businessName,
    required String workPhone,
  }) async {
    final db = LedgerDb.instance;
    await db.saveSetting(nameKey, name.trim());
    await db.saveSetting(businessNameKey, businessName.trim());
    await db.saveSetting(workPhoneKey, workPhone.trim());
  }

  /// The business name to use in messages and PDFs right now.
  Future<String> businessName() async {
    final saved = await LedgerDb.instance.getSetting(businessNameKey);
    return resolveBusinessName(saved);
  }
}
