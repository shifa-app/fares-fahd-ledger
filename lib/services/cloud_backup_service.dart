import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../db/ledger_db.dart';
import 'backup_service.dart';

/// Automatic cloud backup to the user's own Google Drive.
///
/// Flow (approved by the user): sign in once with the personal Google
/// account, then after every local change the JSON backup is uploaded
/// automatically to the Drive appDataFolder (a hidden folder only this
/// app can see). On a fresh install, signing in searches that folder
/// and offers to restore the backup. The manual email backup stays
/// available as a fallback (see BackupService).
///
/// SETUP STILL REQUIRED OUTSIDE THE CODE (see README § «النسخة
/// السحابية»): a Google Cloud project with the Drive API enabled, an
/// Android OAuth client for package com.faresfahd.ledger with this
/// build's SHA-1 fingerprint registered, google-services.json placed
/// in android/app/, and the google-services Gradle plugin applied.
/// Until that is done, sign-in fails at runtime with a clear Arabic
/// error stored in [lastError] — the code never pretends the upload
/// works. Nothing here needs a server or Firebase.
///
/// The exact failure seen on the user's phone (22:30) is
/// `PlatformException(sign_in_failed, f1: 10: , null, null)`
/// (code 10 = DEVELOPER_ERROR: the app is not registered in Google
/// Cloud). [friendlyCloudError] maps that exact string — and every
/// other sign-in failure — to an Arabic message, so the raw technical
/// text never reaches the user.
/// Drive space holding the hidden app data folder. The Drive API only
/// accepts 'drive' and 'appDataFolder' here — the shorter 'appData'
/// is invalid and the API answers `400 Invalid Value` (seen on the
/// user's phone in 1.0.3). Used by [_findBackup] and by the upload
/// parent folder so the value can never drift apart again.
const String cloudBackupSpace = 'appDataFolder';

/// Metadata for a Drive upload of the backup file.
///
/// 1.0.9: the Drive API rejects `parents` in the body of a
/// `files.update` call (parents change only via the `addParents` /
/// `removeParents` query parameters) with `400 Invalid Value` — the
/// exact error seen on the user's phone in 1.0.8 once the backup
/// already existed on Drive and every upload went through the update
/// path (`files.list` / `files.get` / `files.create` had all been
/// proven working before, so the update was the only untested path).
/// So the update metadata carries the name only, and `parents` stays
/// in the create metadata only. Pure, so the rule is pinned by a
/// unit test.
drive.File backupUploadMetadata({required bool isUpdate}) {
  final meta = drive.File()..name = CloudBackupService.fileName;
  if (!isUpdate) meta.parents = <String>[cloudBackupSpace];
  return meta;
}

class CloudBackupService {
  CloudBackupService._();

  static final CloudBackupService instance = CloudBackupService._();

  static const String fileName = 'fares-fahd-backup.json';

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveAppdataScope],
  );

  String? _cachedEmail;
  String? _lastError;

  /// Last sign-in/upload failure in Arabic, if any.
  String? get lastError => _lastError;

  /// Email of the Google account with a LIVE session, if any.
  ///
  /// 1.0.8: this used to fall back to the saved email, so a stored
  /// `cloud_email` counted as «signed in» even after the Google
  /// session itself was gone (phone data wipe) — the dialog then hid
  /// the sign-in button while every upload failed with a dead-end
  /// «not signed in» error. The saved email is now only a display
  /// hint ([lastKnownEmail]), never proof of a session.
  String? get signedInEmail => _signIn.currentUser?.email;

  /// True only when a live Google session exists right now.
  bool get isSignedIn => _signIn.currentUser != null;

  /// Email of the last Google account used, from local settings.
  /// Display hint only («آخر حساب») — never proof of a session.
  String? get lastKnownEmail => _cachedEmail;

  Future<String?> lastUploadText() =>
      LedgerDb.instance.getSetting('cloud_last_upload');

  Future<String?> _storedEmail() =>
      LedgerDb.instance.getSetting('cloud_email');

  Future<void> _saveError(String message) async {
    _lastError = message;
    await LedgerDb.instance.saveSetting('cloud_last_error', message);
  }

  Future<void> _clearError() async {
    _lastError = null;
    await LedgerDb.instance.saveSetting('cloud_last_error', '');
  }

  /// Loads the stored cloud state (call once at startup).
  Future<void> loadStoredState() async {
    _cachedEmail = await _storedEmail();
    final storedError = await LedgerDb.instance.getSetting(
      'cloud_last_error',
    );
    if (storedError != null && storedError.isNotEmpty) {
      _lastError = storedError;
    }
    // Re-attach a previous Google session without prompting.
    await refreshSession();
  }

  /// Silently re-attaches a previous Google session, if one exists.
  /// Returns true when a live session is available afterwards.
  /// Never throws and never prompts. Call before reading [isSignedIn]
  /// whenever the value must reflect the live session (dialog open,
  /// restore offer) — the startup re-attach may not have finished.
  Future<bool> refreshSession() async {
    try {
      if (_signIn.currentUser != null) return true;
      final account = await _signIn.signInSilently();
      if (account == null) return false;
      _cachedEmail = account.email;
      await LedgerDb.instance.saveSetting('cloud_email', account.email);
      return true;
    } catch (_) {
      // No previous session — the user signs in from the cloud dialog.
      return false;
    }
  }

  /// Interactive Google sign-in (opens the account picker once).
  /// Returns true on success.
  Future<bool> signIn() async {
    try {
      var account = await _signIn.signInSilently();
      account ??= await _signIn.signIn();
      if (account == null) return false;
      _cachedEmail = account.email;
      await LedgerDb.instance.saveSetting('cloud_email', account.email);
      await _clearError();
      return true;
    } catch (e) {
      await _saveError(friendlyCloudError(e));
      return false;
    }
  }

  /// Makes sure a live Google session exists: returns true at once
  /// when one is already live, otherwise signs in interactively
  /// (account picker). Use before an upload/restore when the session
  /// may have lapsed — it turns a dead-end «not signed in» error
  /// into a sign-in prompt followed by the retry.
  Future<bool> ensureSignedIn() async {
    if (_signIn.currentUser != null) return true;
    return signIn();
  }

  Future<void> signOut() async {
    try {
      await _signIn.signOut();
    } catch (_) {
      // Signing out locally is enough; a failed remote call is ignored.
    }
    _cachedEmail = null;
    await LedgerDb.instance.saveSetting('cloud_email', '');
  }

  /// Uploads the current JSON backup to appDataFolder now.
  /// Returns true when Drive accepted the file.
  Future<bool> uploadNow() async {
    try {
      final account = _signIn.currentUser ??
          await _signIn.signInSilently();
      if (account == null) {
        await _saveError(cloudNotSignedInMessage);
        return false;
      }
      final headers = await account.authHeaders;
      final api = drive.DriveApi(_GoogleAuthClient(headers));
      final json = await BackupService.exportJson();
      final bytes = utf8.encode(json);
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
      );
      final existing = await _findBackup(api);
      if (existing != null && existing.id != null) {
        // 1.0.9: update metadata must NOT carry `parents` — the Drive
        // API answers `400 Invalid Value` when it is in the update
        // body (see [backupUploadMetadata]).
        await api.files.update(
          backupUploadMetadata(isUpdate: true),
          existing.id!,
          uploadMedia: media,
        );
      } else {
        await api.files.create(
          backupUploadMetadata(isUpdate: false),
          uploadMedia: media,
        );
      }
      await LedgerDb.instance.saveSetting(
        'cloud_last_upload',
        DateTime.now().toIso8601String(),
      );
      await _clearError();
      return true;
    } catch (e) {
      await _saveError(friendlyCloudError(e));
      return false;
    }
  }

  /// Silent auto-upload after a local change. Never throws and never
  /// blocks the UI: when the user is not signed in yet it does nothing.
  Future<bool> maybeAutoUpload() async {
    try {
      if (_signIn.currentUser == null) {
        final account = await _signIn.signInSilently();
        if (account == null) return false;
        _cachedEmail = account.email;
        await LedgerDb.instance.saveSetting('cloud_email', account.email);
      }
      return await uploadNow();
    } catch (_) {
      return false;
    }
  }

  /// Metadata of the cloud backup, if one exists. Null when there is
  /// no backup or the user is not signed in.
  Future<({String name, DateTime? modifiedTime, int? size})?>
      checkForCloudBackup() async {
    try {
      final account = _signIn.currentUser ??
          await _signIn.signInSilently();
      if (account == null) return null;
      final headers = await account.authHeaders;
      final api = drive.DriveApi(_GoogleAuthClient(headers));
      final found = await _findBackup(api);
      if (found == null) return null;
      return (
        name: found.name ?? fileName,
        modifiedTime: found.modifiedTime,
        size: found.size == null
            ? null
            : int.tryParse(found.size!),
      );
    } catch (e) {
      await _saveError(friendlyCloudError(e));
      return null;
    }
  }

  /// Downloads the cloud backup and restores it over the local data.
  /// Returns the restored counts, or null when there is no backup.
  Future<({int persons, int entries})?> downloadAndRestore() async {
    try {
      final account = _signIn.currentUser ??
          await _signIn.signInSilently();
      if (account == null) {
        await _saveError(cloudNotSignedInMessage);
        return null;
      }
      final headers = await account.authHeaders;
      final api = drive.DriveApi(_GoogleAuthClient(headers));
      final found = await _findBackup(api);
      if (found == null || found.id == null) return null;
      final downloaded = await api.files.get(
        found.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (downloaded is! drive.Media) return null;
      final bytes = await downloaded.stream.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      return await BackupService.restoreFromJson(utf8.decode(bytes));
    } catch (e) {
      await _saveError(friendlyCloudError(e));
      return null;
    }
  }

  Future<drive.File?> _findBackup(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: cloudBackupSpace,
      q: "name = '$fileName'",
      orderBy: 'modifiedTime desc',
      pageSize: 1,
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

}

/// Saved in [CloudBackupService.lastError] when an upload/restore is
/// attempted without a live Google session. Single source of truth
/// so the message never drifts between call sites.
const String cloudNotSignedInMessage =
    'لم يتم تسجيل الدخول بحساب جوجل بعد.';

/// الرسالة العربية الموحدة عند فشل إعداد جوجل (كود 10 / DEVELOPER_ERROR).
const String cloudSetupIncompleteMessage =
    'إعداد جوجل غير مكتمل على هذا التطبيق بعد: يلزم تسجيل بصمة التطبيق (SHA-1) وملف google-services.json — راجع قسم «النسخة السحابية» في README.';

/// يحوّل أي خطأ من دخول جوجل/Drive إلى رسالة عربية صالحة للعرض.
/// يتعرف على صيغة خطأ الهاتف الفعلية
/// `PlatformException(sign_in_failed, f1: 10: , null, null)`
/// (يحتوي `sign_in_failed` و`f1: 10`) وعلى `ApiException: 10` و
/// `DEVELOPER_ERROR` و`default_web_client_id`، فيعرض دائماً رسالة
/// الإعداد غير المكتمل. وعلى خطأ Drive `400 Invalid Value`
/// (`DetailedApiRequestError`) فيعرض رسالة عربية عن مجلد النسخة.
/// وأي نص تقني خام آخر (PlatformException أو ApiException)
/// يُستبدل برسالة عربية عامة — لا يظهر نص الاستثناء
/// الخام للمستخدم أبداً.
String friendlyCloudError(Object e) {
  final text = e.toString();
  if (text.contains('sign_in_failed') ||
      text.contains('ApiException: 10') ||
      text.contains('DEVELOPER_ERROR') ||
      text.contains('default_web_client_id') ||
      text.contains('f1: 10')) {
    return cloudSetupIncompleteMessage;
  }
  if (text.contains('network') ||
      text.contains('SocketException') ||
      text.contains('Failed host lookup')) {
    return 'لا يوجد اتصال بالإنترنت الآن — ستُعاد المحاولة تلقائياً بعد أي تغيير قادم.';
  }
  if (text.contains('DetailedApiRequestError') ||
      text.contains('Invalid Value') ||
      text.contains('status: 400')) {
    return 'تعذّر الوصول إلى مجلد النسخة السحابية في جوجل درايف — تحقق من الاتصال وحاول مرة أخرى.';
  }
  if (text.contains('PlatformException') ||
      text.contains('ApiException') ||
      text.contains('Exception')) {
    return 'تعذّر إكمال العملية مع جوجل. تحقق من الاتصال وحاول مرة أخرى.';
  }
  if (text.length > 160) return text.substring(0, 160);
  return text;
}

/// حالة النسخ السحابي لشاشة الحالة (مثل تطبيق كناش المرجعي).
enum CloudBackupStatus { notSignedIn, signedInNotUploaded, uploaded }

/// الحالة الخالصة من الدخول ووجود رفع سابق — قابلة للاختبار.
CloudBackupStatus cloudBackupStatus({
  required bool signedIn,
  required bool hasUpload,
}) {
  if (!signedIn) return CloudBackupStatus.notSignedIn;
  if (!hasUpload) return CloudBackupStatus.signedInNotUploaded;
  return CloudBackupStatus.uploaded;
}

/// What the cloud dialog offers, from the LIVE session state only.
///
/// 1.0.8 regression rule: a saved email ([CloudBackupService.lastKnownEmail])
/// is a display hint, never a session. With a saved email but no live
/// session the dialog must offer sign-in — never upload/restore — so
/// the user is never stuck with a «not signed in» error and no way
/// back in (the 1.0.7 bug: the sign-in button was hidden while every
/// upload failed). Pure, so the rule is pinned by a unit test.
({bool showSignIn, bool showUpload, bool showRestore, String? hintEmail})
cloudDialogActions({
  required bool signedIn,
  required String? lastKnownEmail,
}) {
  if (signedIn) {
    return (
      showSignIn: false,
      showUpload: true,
      showRestore: true,
      hintEmail: null,
    );
  }
  return (
    showSignIn: true,
    showUpload: false,
    showRestore: false,
    hintEmail: lastKnownEmail,
  );
}

/// تسمية الحالة المعروضة في شاشة النسخ السحابية.
String cloudBackupStatusLabel(CloudBackupStatus status) =>
    switch (status) {
      CloudBackupStatus.notSignedIn => 'غير مسجل بحساب جوجل بعد',
      CloudBackupStatus.signedInNotUploaded => 'لم يتم النسخ بعد',
      CloudBackupStatus.uploaded => 'اكتمل النسخ الاحتياطي',
    };

/// صفا «جميع المعاملات منسوخة»: عدد الأشخاص وعدد المعاملات من
/// قاعدة البيانات المحلية الحقيقية — بلا أي رقم تجريبي.
List<({String label, int count})> backupCopiedRows({
  required int persons,
  required int entries,
}) => [
      (label: 'الأشخاص', count: persons),
      (label: 'المعاملات', count: entries),
    ];

/// Minimal authenticated HTTP client built from Google sign-in headers.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
