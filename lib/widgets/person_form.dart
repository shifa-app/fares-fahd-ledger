import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../logic/balance.dart';
import '../models.dart';

/// Add / edit person form (name, phone, address, type, notes).
/// Type is chosen with two equal-width (50% / 50%) segmented buttons
/// so the word «عميل» can never wrap to two lines. Fields carry icons,
/// the phone field offers importing from the device contacts, and the
/// save button uses the brand navy with gold text.
Future<Person?> showPersonForm(
  BuildContext context, {
  Person? existing,
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final phoneController = TextEditingController(text: existing?.phone ?? '');
  final addressController =
      TextEditingController(text: existing?.address ?? '');
  final notesController = TextEditingController(text: existing?.notes ?? '');
  var type = existing?.type ?? PersonType.customer;
  String? error;

  return showDialog<Person?>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> pickContact() async {
          try {
            final granted =
                await FlutterContacts.requestPermission(readonly: true);
            if (!granted) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'لم يُمنح إذن جهات الاتصال — يمكنك كتابة الرقم يدوياً',
                    ),
                  ),
                );
              }
              return;
            }
            final picked = await FlutterContacts.openExternalPick();
            if (picked == null) return;
            final full = await FlutterContacts.getContact(picked.id);
            final contact = full ?? picked;
            final phone = contact.phones.isNotEmpty
                ? contact.phones.first.number
                : '';
            setState(() {
              if (phone.isNotEmpty) phoneController.text = phone;
              if (nameController.text.trim().isEmpty &&
                  contact.displayName.isNotEmpty) {
                nameController.text = contact.displayName;
              }
            });
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تعذّر الوصول لجهات الاتصال'),
                ),
              );
            }
          }
        }

        return AlertDialog(
          title: Text(existing == null ? 'إضافة شخص جديد' : 'تعديل البيانات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'الاسم *',
                    errorText: error,
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'رقم التليفون',
                    prefixIcon: const Icon(Icons.phone),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts),
                      tooltip: 'استيراد من جهات الاتصال',
                      onPressed: pickContact,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Segmented type picker: two equal 50% buttons, one line.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: PersonType.values.map((t) {
                      final selected = type == t;
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => type = t),
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? BrandColors.navy
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              t.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? BrandColors.gold
                                    : BrandColors.navy,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  setState(() => error = 'الاسم مطلوب');
                  return;
                }
                Navigator.of(dialogContext).pop(
                  Person(
                    id: existing?.id,
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    address: addressController.text.trim(),
                    type: type,
                    notes: notesController.text.trim(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.navy,
                foregroundColor: BrandColors.gold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'حفظ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}
