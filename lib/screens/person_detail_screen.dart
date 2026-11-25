import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../db/ledger_db.dart';
import '../logic/balance.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../services/profile_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/amount_sheet.dart';
import '../widgets/person_form.dart';

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.person});

  final Person person;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late Person _person;
  List<LedgerEntry> _entries = [];
  List<double> _running = [];
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _load();
  }

  Future<void> _load() async {
    final entries = await LedgerDb.instance.entriesForPerson(_person.id ?? 0);
    final running =
        await LedgerDb.instance.runningBalancesForPerson(_person);
    final balance = await LedgerDb.instance.balanceForPerson(_person);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _running = running;
      _balance = balance;
    });
  }

  TxType get _debtType => _person.type == PersonType.customer
      ? TxType.saleCredit
      : TxType.purchaseCredit;

  TxType get _paymentType => _person.type == PersonType.customer
      ? TxType.paymentReceived
      : TxType.paymentPaid;

  Future<void> _openAmountSheet(TxType initialType) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AmountSheet(
        person: _person,
        initialType: initialType,
        onSave: (type, amount, note, date) async {
          await LedgerDb.instance.insertEntry(
            LedgerEntry(
              personId: _person.id ?? 0,
              type: type,
              amount: amount,
              note: note,
              date: date,
            ),
          );
          await _load();
        },
      ),
    );
  }

  Future<void> _sharePdf() async {
    try {
      await PdfService.shareStatement(
        person: _person,
        entries: _entries,
        running: _running,
        balance: _balance,
        shopName: await ProfileService.instance.businessName(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إنشاء كشف الحساب: $e')),
      );
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_person.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف رقم تليفون لهذا الشخص أولاً')),
      );
      return;
    }
    final businessName = await ProfileService.instance.businessName();
    final message = WhatsappService.reminderMessage(
      _person,
      _balance,
      businessName: businessName,
    );
    final opened = await WhatsappService.openWhatsApp(_person.phone, message);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح واتساب على هذا الهاتف')),
      );
    }
  }

  Future<void> _editPerson() async {
    final updated = await showPersonForm(context, existing: _person);
    if (updated == null) return;
    await LedgerDb.instance.updatePerson(updated);
    setState(() => _person = updated);
    await _load();
  }

  Future<void> _deletePerson() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الشخص'),
        content: Text(
          'سيتم حذف ${_person.name} وكل حركاته نهائياً. هل أنت متأكد؟',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'حذف',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LedgerDb.instance.deletePerson(_person.id ?? 0);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحركة'),
        content: Text(
          'هل أنت متأكد من حذف هذه المعاملة؟\n'
          '${entry.type.label} بمبلغ ${formatMoney(entry.amount)}',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'حذف',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LedgerDb.instance.deleteEntry(entry.id ?? 0);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceColor = _balance > 0
        ? BrandColors.danger
        : _balance < 0
            ? BrandColors.success
            : Colors.grey;
    final balanceBg = _balance > 0
        ? BrandColors.dangerBg
        : _balance < 0
            ? BrandColors.successBg
            : Colors.grey.shade100;
    return Scaffold(
      appBar: AppBar(
        title: Text(_person.name, style: const TextStyle(fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل البيانات',
            onPressed: _editPerson,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'حذف الشخص',
            onPressed: _deletePerson,
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            color: balanceBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_person.type.label} • ${_person.phone}',
                    style: const TextStyle(fontSize: 19),
                  ),
                  if (_person.address.isNotEmpty)
                    Text(
                      'العنوان: ${_person.address}',
                      style: const TextStyle(fontSize: 19),
                    ),
                  if (_person.notes.isNotEmpty)
                    Text(
                      'ملاحظات: ${_person.notes}',
                      style: const TextStyle(fontSize: 19),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _balance == 0
                        ? 'الرصيد: متعادل'
                        : 'الرصيد: ${balanceWord(_balance)} ${formatMoney(_balance.abs())}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openAmountSheet(_debtType),
                  icon: const Icon(Icons.add),
                  label: Text(
                    _person.type == PersonType.customer
                        ? 'دين جديد'
                        : 'شراء آجل',
                    style: const TextStyle(fontSize: 19),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openAmountSheet(_paymentType),
                  icon: const Icon(Icons.payments),
                  label: const Text(
                    '+ دفعة',
                    style: TextStyle(fontSize: 19),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text(
                    'كشف PDF',
                    style: TextStyle(fontSize: 19),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.message),
                  label: const Text(
                    'واتساب',
                    style: TextStyle(fontSize: 19),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.success,
                    side: const BorderSide(color: BrandColors.success),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'سجل النشاطات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد حركات بعد',
                      style: TextStyle(fontSize: 20),
                    ),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final delta = signedDelta(
                        entry.type,
                        _person.type,
                        entry.amount,
                      );
                      final deltaColor = delta > 0
                          ? BrandColors.success
                          : BrandColors.danger;
                      final clarification =
                          txClarification(entry.type, _person.type);
                      final clarificationColor =
                          entry.type == TxType.saleCredit
                              ? BrandColors.success
                              : entry.type == TxType.purchaseCredit
                                  ? BrandColors.danger
                                  : entry.type == TxType.discount
                                      ? Colors.grey.shade700
                                      : const Color(0xFF2563EB);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          // Safety margin around the delete icon so it
                          // cannot be hit by accident while scrolling.
                          contentPadding:
                              const EdgeInsetsDirectional.only(
                            start: 16,
                            end: 8,
                          ),
                          isThreeLine: true,
                          title: Text(
                            entry.type.shortLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${formatDayDate(entry.date)}'
                            '${entry.note.isEmpty ? '' : ' • ${entry.note}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
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
                                  Text(
                                    'الرصيد: ${formatMoney(_running[index].abs())} '
                                    '(${balanceWord(_running[index])})',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'حذف الحركة',
                                padding: const EdgeInsets.all(10),
                                onPressed: () => _deleteEntry(entry),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
