import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../db/ledger_db.dart';
import '../logic/balance.dart';
import '../models.dart';
import '../services/backup_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/profile_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/app_footer.dart';
import '../widgets/charts.dart';
import '../widgets/person_form.dart';
import 'person_detail_screen.dart';
import 'terms_screen.dart';

/// Dashboard (لوحة تحكم) + persons (الأشخاص) with a bottom bar.
/// Visual identity approved by the user (2026-11-24): navy #0D1726,
/// gold #D4AF37, background #F4F6F9, success #16A34A on #DCFCE7,
/// danger #DC2626 on #FEE2E2, Cairo font.
/// Every number, chart point and activity row is computed from the
/// real SQLite entries — with no data everything shows zero.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.email,
    required this.onLogout,
  });

  final String email;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<PersonWithBalance> _persons = [];
  List<LedgerEntry> _entries = [];
  List<({LedgerEntry entry, Person person})> _recent = [];
  bool _loading = true;
  int _tabIndex = 0;
  PersonFilter _filter = PersonFilter.all;
  bool _cloudChecked = false;
  String? _cloudLastUpload;

  @override
  void initState() {
    super.initState();
    _load();
    CloudBackupService.instance.loadStoredState().then((_) {
      if (mounted) _refreshCloudStatus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCloudStatus() async {
    final last = await CloudBackupService.instance.lastUploadText();
    if (!mounted) return;
    setState(() => _cloudLastUpload = last);
  }

  Future<void> _load() async {
    final persons = await LedgerDb.instance.personsWithBalances(
      query: _searchController.text,
    );
    final entries = await LedgerDb.instance.allEntries();
    final recent = await LedgerDb.instance.recentPersonsWithLatestEntry();
    if (!mounted) return;
    setState(() {
      _persons = persons;
      _entries = entries;
      _recent = recent;
      _loading = false;
    });
    if (!_cloudChecked && _persons.isEmpty && _entries.isEmpty) {
      _cloudChecked = true;
      await _maybeOfferCloudRestore();
    }
  }

  /// On a fresh install, a signed-in Google account with a cloud backup
  /// is offered for restore automatically.
  Future<void> _maybeOfferCloudRestore() async {
    // The startup silent re-attach may not have finished yet — check
    // the live session before deciding whether to offer a restore.
    await CloudBackupService.instance.refreshSession();
    if (!CloudBackupService.instance.isSignedIn) return;
    final info = await CloudBackupService.instance.checkForCloudBackup();
    if (info == null || !mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نسخة سحابية موجودة'),
        content: Text(
          'وجدنا نسخة احتياطية سحابية'
          '${info.modifiedTime != null ? ' بتاريخ ${formatDayDate(info.modifiedTime!)}' : ''}. '
          'هل تريد استرجاعها الآن؟',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لاحقاً', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.navy,
              foregroundColor: BrandColors.gold,
            ),
            child: const Text('استرجاع', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (restore == true) await _restoreFromCloud();
  }

  Future<void> _restoreFromCloud() async {
    final result =
        await CloudBackupService.instance.downloadAndRestore();
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CloudBackupService.instance.lastError ??
                'لا توجد نسخة سحابية بعد',
          ),
        ),
      );
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم الاسترجاع من السحابة: ${result.persons} شخص و${result.entries} حركة',
        ),
      ),
    );
  }

  Future<void> _triggerCloudUpload() async {
    await CloudBackupService.instance.maybeAutoUpload();
    await _refreshCloudStatus();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addPerson() async {
    final person = await showPersonForm(context);
    if (person == null) return;
    await LedgerDb.instance.insertPerson(person);
    await _load();
    await _triggerCloudUpload();
  }

  Future<void> _openPersonDetail(Person person) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonDetailScreen(person: person),
      ),
    );
    await _load();
    await _triggerCloudUpload();
  }

  /// Person picker reusing the existing person list (no new feature):
  /// used by "معاملة جديدة" and "التقارير".
  Future<Person?> _pickPerson(String title) async {
    if (_persons.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف عميلاً أو مورّداً أولاً')),
      );
      return null;
    }
    return showDialog<Person?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 20)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _persons.length,
            itemBuilder: (context, index) {
              final item = _persons[index];
              return ListTile(
                title: Text(
                  item.person.name,
                  style: const TextStyle(fontSize: 19),
                ),
                subtitle: Text(
                  '${item.person.type.label} • ${item.person.phone}',
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: Text(
                  item.balance == 0
                      ? 'متعادل'
                      : '${balanceWord(item.balance)} '
                          '${formatMoney(item.balance.abs())}',
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () =>
                    Navigator.of(dialogContext).pop(item.person),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Future<void> _newTransaction() async {
    final person = await _pickPerson('اختر شخصاً لإضافة معاملة');
    if (person == null) return;
    await _openPersonDetail(person);
  }

  Future<void> _openReports() async {
    final person = await _pickPerson('اختر شخصاً لعرض كشف حسابه');
    if (person == null) return;
    await _openPersonDetail(person);
  }

  Future<void> _doBackup() async {
    try {
      await BackupService.shareBackup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّرت النسخة الاحتياطية: $e')),
      );
    }
  }

  Future<void> _doRestore() async {
    final controller = TextEditingController();
    final pasted = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استرجاع من نسخة احتياطية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'افتح ملف النسخة من إيميلك، انسخ كل محتواه، والصقه هنا. '
              'سيتم استبدال كل البيانات الحالية بمحتوى النسخة.',
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'محتوى ملف JSON',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('استرجاع', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (pasted == null || pasted.trim().isEmpty) return;
    try {
      final result = await BackupService.restoreFromJson(pasted);
      await _load();
      await _triggerCloudUpload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الاسترجاع: ${result.persons} شخص و${result.entries} حركة',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الاسترجاع: $e')),
      );
    }
  }

  Future<void> _changeEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير الإيميل'),
        content: const Text(
          'سيتم الخروج من الإيميل الحالي وإدخال إيميل جديد. '
          'بياناتك المحفوظة على الهاتف لن تتأثر.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تغيير', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LedgerDb.instance.clearEmail();
      widget.onLogout();
    }
  }

  // ---------- Cloud backup dialog ----------

  String _lastUploadLabel() {
    final raw = _cloudLastUpload;
    if (raw == null || raw.isEmpty) return 'لم يتم الرفع بعد';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${formatDayDate(parsed)} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showCloudDialog() async {
    final cloud = CloudBackupService.instance;
    await _refreshCloudStatus();
    // Re-attach silently first: the dialog must show the LIVE session
    // state, not the startup race — a saved email alone is not a
    // session (1.0.7 bug: sign-in button hidden, uploads failing).
    await cloud.refreshSession();
    final signedIn = cloud.isSignedIn;
    final email = cloud.signedInEmail;
    final actions = cloudDialogActions(
      signedIn: signedIn,
      lastKnownEmail: cloud.lastKnownEmail,
    );
    final error = cloud.lastError;
    final hasUpload =
        _cloudLastUpload != null && _cloudLastUpload!.isNotEmpty;
    final status = cloudBackupStatus(
      signedIn: signedIn,
      hasUpload: hasUpload,
    );
    final statusColor = status == CloudBackupStatus.uploaded
        ? BrandColors.success
        : Colors.grey.shade700;
    // Real local counts for the «copied» rows — never demo numbers.
    // If the count query fails, fall back to the loaded lists.
    ({int persons, int entries}) counts;
    try {
      counts = await LedgerDb.instance.counts();
    } catch (_) {
      counts = (persons: _persons.length, entries: _entries.length);
    }
    final copiedRows = backupCopiedRows(
      persons: counts.persons,
      entries: counts.entries,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('النسخة الاحتياطية السحابية'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status (Kanash-style): unmistakable whether a backup exists.
            Text(
              'الحالة: ${cloudBackupStatusLabel(status)}',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              signedIn
                  ? 'مسجل بحساب: ${email ?? ''}'
                  : 'سجّل الدخول بحساب جوجل لبدء النسخ التلقائي.',
              style: const TextStyle(fontSize: 17),
            ),
            // The saved email is a hint only — it never means a live
            // session (1.0.8).
            if (actions.hintEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                'آخر حساب: ${actions.hintEmail}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
            if (hasUpload) ...[
              const SizedBox(height: 6),
              Text(
                'آخر رفع: ${_lastUploadLabel()}',
                style: const TextStyle(fontSize: 17),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'يتم النسخ الاحتياطي تلقائياً بعد كل تغيير متى كان الهاتف متصلاً بالإنترنت. وعند إعادة تثبيت التطبيق، سجّل الدخول بنفس حساب جوجل لاسترجاع بياناتك — إدخال الإيميل وحده لا يسترجع شيئاً بلا نسخة مرفوعة.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            if (error != null && error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 15,
                  color: BrandColors.danger,
                ),
              ),
            ],
            if (status == CloudBackupStatus.uploaded) ...[
              const SizedBox(height: 12),
              const Text(
                'جميع المعاملات منسوخة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ...copiedRows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: BrandColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.label,
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                      Text(
                        '${row.count}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (actions.showSignIn)
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final ok = await cloud.signIn();
                  await _refreshCloudStatus();
                  if (ok) {
                    _snack('تم تسجيل الدخول بحساب جوجل');
                    if (_persons.isEmpty && _entries.isEmpty) {
                      await _maybeOfferCloudRestore();
                    }
                  } else {
                    _snack(cloud.lastError ?? 'تعذّر تسجيل الدخول');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.navy,
                  foregroundColor: BrandColors.gold,
                ),
                child: const Text(
                  'تسجيل الدخول بحساب جوجل',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            if (actions.showUpload) ...[
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  // The live session can lapse between opening the
                  // dialog and tapping: sign in first (silently when
                  // possible) instead of failing with a dead-end
                  // «not signed in» error — then upload for real.
                  if (!cloud.isSignedIn) {
                    final signed = await cloud.ensureSignedIn();
                    await _refreshCloudStatus();
                    if (!signed) {
                      _snack(cloud.lastError ?? 'تعذّر تسجيل الدخول');
                      return;
                    }
                  }
                  final ok = await cloud.uploadNow();
                  await _refreshCloudStatus();
                  _snack(
                    ok
                        ? 'تم رفع النسخة السحابية'
                        : (cloud.lastError ?? 'تعذّر الرفع'),
                  );
                },
                child: const Text(
                  'رفع نسخة الآن',
                  style: TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  if (!cloud.isSignedIn) {
                    final signed = await cloud.ensureSignedIn();
                    if (!signed) {
                      _snack(cloud.lastError ?? 'تعذّر تسجيل الدخول');
                      return;
                    }
                  }
                  final info = await cloud.checkForCloudBackup();
                  if (info == null) {
                    _snack('لا توجد نسخة سحابية بعد');
                    return;
                  }
                  if (!mounted) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (confirmContext) => AlertDialog(
                      title: const Text('استرجاع من السحابة'),
                      content: Text(
                        'سيتم استبدال كل البيانات الحالية بالنسخة السحابية'
                        '${info.modifiedTime != null ? ' بتاريخ ${formatDayDate(info.modifiedTime!)}' : ''}.',
                        style: const TextStyle(fontSize: 17),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(true),
                          child: const Text('استرجاع'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await _restoreFromCloud();
                },
                child: const Text(
                  'استرجاع من السحابة',
                  style: TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await cloud.signOut();
                  await _refreshCloudStatus();
                  _snack('تم تسجيل الخروج من حساب جوجل');
                },
                child: const Text(
                  'تسجيل الخروج من جوجل',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _doBackup();
              },
              child: const Text(
                'نسخة يدوية (مشاركة ملف JSON)',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // ---------- Profile dialog: one integrated card ----------
  // Name, business name and work phone are editable here and saved
  // in the local settings table; the email stays read-only (it is
  // the backup identity) and the terms stay reachable from the card.

  Future<void> _showProfileDialog() async {
    final profile = await ProfileService.instance.loadProfile();
    final nameController = TextEditingController(text: profile.name);
    final businessController =
        TextEditingController(text: profile.businessName);
    final phoneController =
        TextEditingController(text: profile.workPhone);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الملف الشخصي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'الاسم الشخصي',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'اسم النشاط',
                  hintText: appName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(fontSize: 18),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'هاتف العمل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'الإيميل الشخصي:',
                style: TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 4),
              SelectableText(
                widget.email,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'يُحفظ الإيميل على هاتفك فقط، ويُستخدم كهوية للنسخة الاحتياطية.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text(
                  'شروط الاستخدام',
                  style: TextStyle(fontSize: 17),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await ProfileService.instance.saveProfile(
                name: nameController.text,
                businessName: businessController.text,
                workPhone: phoneController.text,
              );
              navigator.pop();
              _snack('تم حفظ الملف الشخصي');
            },
            child: const Text('حفظ', style: TextStyle(fontSize: 17)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _changeEmail();
            },
            child: const Text('تغيير الإيميل', style: TextStyle(fontSize: 17)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    nameController.dispose();
    businessController.dispose();
    phoneController.dispose();
  }

  // ---------- Phone actions (call / WhatsApp) ----------

  Future<void> _showPhoneActions(Person person) async {
    if (person.phone.trim().isEmpty) {
      _snack('لا يوجد رقم تليفون لهذا الشخص');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(person.name),
        content: Text(
          person.phone,
          style: const TextStyle(fontSize: 19),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final uri = Uri(
                scheme: 'tel',
                path: person.phone.trim(),
              );
              if (!await launchUrl(uri)) {
                _snack('تعذّر فتح الاتصال');
              }
            },
            icon: const Icon(Icons.call),
            label: const Text('اتصال', style: TextStyle(fontSize: 17)),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final opened = await WhatsappService.openWhatsApp(
                person.phone,
                '',
              );
              if (!opened) _snack('تعذّر فتح واتساب على هذا الهاتف');
            },
            icon: const Icon(Icons.message),
            label: const Text('واتساب', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = summarizeBalances(
      _persons.map((p) => p.balance).toList(),
    );
    final flow = totalFlow(
      _entries
          .map((e) => (type: e.type, amount: e.amount))
          .toList(),
    );
    final last7 = lastDaysFlows(
      _entries
          .map((e) => (type: e.type, amount: e.amount, date: e.date))
          .toList(),
      7,
    );
    final hasFlow = flow.inflow > 0 || flow.outflow > 0;
    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset(logoSymbolAsset, width: 36, height: 36),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'فارس وفهد',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded),
            tooltip: 'النسخة السحابية',
            onPressed: _showCloudDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'استرجاع نسخة',
            onPressed: _doRestore,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'الملف الشخصي',
            onPressed: _showProfileDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tabIndex == 0
              ? _buildDashboard(summary, flow, last7, hasFlow)
              : _buildPersonsTab(),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton.extended(
              backgroundColor: BrandColors.gold,
              foregroundColor: BrandColors.navy,
              onPressed: _addPerson,
              icon: const Icon(Icons.person_add),
              label: const Text(
                'إضافة شخص',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) =>
            setState(() => _tabIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: BrandColors.gold.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
              color: BrandColors.navy,
            ),
            label: 'لوحة تحكم',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_rounded),
            selectedIcon: Icon(
              Icons.people_rounded,
              color: BrandColors.navy,
            ),
            label: 'الأشخاص',
          ),
        ],
      ),
    );
  }

  // ---------- Dashboard ----------

  Widget _buildDashboard(
    ({double owedToUs, double weOwe, double net}) summary,
    ({double inflow, double outflow}) flow,
    List<DayFlow> last7,
    bool hasFlow,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header.
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
                  SizedBox(width: 12),
                  Expanded(
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
          // Three stat cards.
          // IntrinsicHeight bounds the Row's height to the tallest
          // card, so stretch works without asking for infinite height
          // inside the vertically unbounded SingleChildScrollView
          // (1.0.6 collapse: BoxConstraints forces an infinite height).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statCard(
                  'إجمالي الوارد',
                  flow.inflow,
                  BrandColors.success,
                  BrandColors.successBg,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'إجمالي الصادر',
                  flow.outflow,
                  BrandColors.danger,
                  BrandColors.dangerBg,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'صافي المستحقات',
                  summary.net.abs(),
                  summary.net > 0
                      ? BrandColors.success
                      : summary.net < 0
                          ? BrandColors.danger
                          : Colors.grey.shade700,
                  summary.net > 0
                      ? BrandColors.successBg
                      : summary.net < 0
                          ? BrandColors.dangerBg
                          : Colors.grey.shade200,
                  icon: Icons.account_balance_wallet_rounded,
                  badge: netBalanceLabel(summary.net),
                  badgeBg: summary.net > 0
                      ? BrandColors.successBg
                      : summary.net < 0
                          ? BrandColors.dangerBg
                          : Colors.grey.shade200,
                  badgeTextColor: summary.net > 0
                      ? BrandColors.success
                      : summary.net < 0
                          ? BrandColors.danger
                          : Colors.grey.shade700,
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
          // Quick actions.
          Row(
            children: [
              Expanded(
                child: _quickPrimary(
                  'معاملة جديدة',
                  iconWalletAsset,
                  _newTransaction,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickSecondary(
                  'الأشخاص',
                  iconPeopleAsset,
                  () => setState(() => _tabIndex = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickSecondary(
                  'التقارير',
                  iconChartAsset,
                  _openReports,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'قائمة النشاط الأخير',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_recent.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'لا توجد حركات بعد',
                    style: TextStyle(fontSize: 19),
                  ),
                ),
              ),
            )
          else
            ..._recent.map((item) {
              final entry = item.entry;
              final person = item.person;
              final delta = signedDelta(
                entry.type,
                person.type,
                entry.amount,
              );
              final deltaColor = delta > 0
                  ? BrandColors.success
                  : BrandColors.danger;
              final clarification =
                  txClarification(entry.type, person.type);
              final clarificationColor = entry.type == TxType.saleCredit
                  ? BrandColors.success
                  : entry.type == TxType.purchaseCredit
                      ? BrandColors.danger
                      : entry.type == TxType.discount
                          ? Colors.grey.shade700
                          : const Color(0xFF2563EB);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: BrandColors.navy,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  title: Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.type.shortLabel} • ${formatDayDate(entry.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${delta > 0 ? '+' : '-'}${formatMoney(entry.amount)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: deltaColor,
                        ),
                      ),
                      Text(
                        clarification,
                        style: TextStyle(
                          fontSize: 14,
                          color: clarificationColor,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _openPersonDetail(person),
                ),
              );
            }),
          const SizedBox(height: 12),
          // Charts card — below the recent activity list.
          _buildChartCard(last7, hasFlow),
          const SizedBox(height: 16),
          const AppFooter(),
        ],
      ),
    );
  }

  /// «حركة آخر 7 أيام» — unchanged logic, placed below the recent
  /// activity list (was above it).
  Widget _buildChartCard(List<DayFlow> last7, bool hasFlow) {
    return Card(
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _legendDot(BrandColors.success, 'الوارد'),
                const SizedBox(width: 16),
                _legendDot(BrandColors.danger, 'الصادر'),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasFlow)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'لا توجد بيانات بعد\nسجّل أول معاملة لعرض الرسوم هنا',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              LineFlowChart(days: last7),
              const SizedBox(height: 8),
              const Text(
                'الوارد والصادر يومياً',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              BarFlowChart(days: last7),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    double amount,
    Color color,
    Color bg, {
    required IconData icon,
    String? badge,
    Color? badgeBg,
    Color? badgeTextColor,
  }) {
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
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(amount),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeBg ?? color,
                  borderRadius: BorderRadius.circular(20),
                  border: badgeBg == null
                      ? null
                      : Border.all(color: color),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor ?? Colors.white,
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

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  /// 3D gold/blue icon inside a navy rounded tile (same #0D1726 as the
  /// AppBar). The icon PNGs sit on a flat navy background, so the tile
  /// blends with them and no transparency work is needed.
  Widget _quickIconTile(String imageAsset) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandColors.navy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(imageAsset, fit: BoxFit.contain),
    );
  }

  Widget _quickPrimary(
    String label,
    String imageAsset,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.gold,
        foregroundColor: BrandColors.navy,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quickIconTile(imageAsset),
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

  Widget _quickSecondary(
    String label,
    String imageAsset,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.navy,
        elevation: 0,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quickIconTile(imageAsset),
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

  // ---------- Persons tab ----------

  List<PersonWithBalance> get _visiblePersons => _persons
      .where(
        (item) => personMatchesFilter(
          type: item.person.type,
          balance: item.balance,
          filter: _filter,
        ),
      )
      .toList();

  Widget _buildPersonsTab() {
    final visible = _visiblePersons;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو التليفون',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _load();
              },
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: PersonFilter.values.map((filter) {
              final selected = _filter == filter;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(filter.label),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: BrandColors.navy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? BrandColors.navy
                        : Colors.grey.shade300,
                  ),
                  labelStyle: TextStyle(
                    color:
                        selected ? BrandColors.gold : BrandColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  onSelected: (_) => setState(() => _filter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Text(
                    'لا يوجد أشخاص بعد\nاضغط + لإضافة عميل أو مورّد',
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final person = item.person;
                    final balance = item.balance;
                    final balanceColor = balance > 0
                        ? BrandColors.danger
                        : balance < 0
                            ? BrandColors.success
                            : Colors.grey.shade700;
                    final balanceBg = balance > 0
                        ? BrandColors.dangerBg
                        : balance < 0
                            ? BrandColors.successBg
                            : Colors.grey.shade200;
                    final isCustomer =
                        person.type == PersonType.customer;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: BrandColors.navy,
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                person.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isCustomer
                                    ? BrandColors.successBg
                                    : const Color(0xFFFDF3D0),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                person.type.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isCustomer
                                      ? BrandColors.success
                                      : BrandColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Phone alone on the second line so the full
                        // number is always visible (it was truncated to
                        // «...01060» while sharing the line with the
                        // type badge). No ellipsis: the number must
                        // never be cut.
                        subtitle: person.phone.isEmpty
                            ? null
                            : GestureDetector(
                                onTap: () => _showPhoneActions(person),
                                child: Text(
                                  person.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: BrandColors.navy,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: balanceBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            balance == 0
                                ? 'متعادل'
                                : '${balanceWord(balance)} ${formatMoney(balance.abs())}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: balanceColor,
                            ),
                          ),
                        ),
                        onTap: () => _openPersonDetail(person),
                      ),
                    );
                  },
                ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: AppFooter(),
        ),
      ],
    );
  }
}
