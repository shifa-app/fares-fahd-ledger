import 'package:material_ui/material_ui.dart';

import '../logic/balance.dart';
import '../models.dart';

/// One-tap entry: type chips + built-in number pad + note + date,
/// so recording a transaction takes seconds.
class AmountSheet extends StatefulWidget {
  const AmountSheet({
    super.key,
    required this.person,
    required this.initialType,
    required this.onSave,
  });

  final Person person;
  final TxType initialType;
  final void Function(TxType type, double amount, String note, DateTime date)
      onSave;

  @override
  State<AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<AmountSheet> {
  late TxType _type;
  String _amount = '';
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
        return;
      }
      if (key == '.') {
        if (_amount.contains('.')) return;
        _amount = _amount.isEmpty ? '0.' : '$_amount.';
        return;
      }
      if (_amount.replaceAll('.', '').length >= 10) return;
      _amount += key;
    });
  }

  void _save() {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغاً صحيحاً أكبر من صفر')),
      );
      return;
    }
    widget.onSave(_type, amount, _noteController.text.trim(), _date);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final types = allowedTxTypes(widget.person.type);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تسجيل معاملة - ${widget.person.name}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: types
                  .map(
                    (t) => ChoiceChip(
                      label: Text(
                        t.label,
                        style: const TextStyle(fontSize: 18),
                      ),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _amount.isEmpty ? '0 جنيه' : '$_amount جنيه',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫']
                  .map(
                    (key) => ElevatedButton(
                      onPressed: () => _press(key),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        key,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'البيان (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('التاريخ: ', style: TextStyle(fontSize: 18)),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Text(
                    _date.toIso8601String().substring(0, 10),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('حفظ المعاملة', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}
