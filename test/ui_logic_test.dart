import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/app_info.dart';
import 'package:ledger/logic/balance.dart';
import 'package:ledger/services/cloud_backup_service.dart';

void main() {
  group('formatDayDate (dd-MM-yyyy, one fixed line)', () {
    test('24 November 2026', () {
      expect(formatDayDate(DateTime(2026, 11, 24)), '24-11-2026');
    });

    test('single digits are padded', () {
      expect(formatDayDate(DateTime(2026, 1, 5)), '05-01-2026');
    });
  });

  group('txClarification (word under the amount, not just + / -)', () {
    test('credit sale puts debt on the customer', () {
      expect(
        txClarification(TxType.saleCredit, PersonType.customer),
        'على العميل',
      );
    });

    test('received payment is a settlement', () {
      expect(
        txClarification(TxType.paymentReceived, PersonType.customer),
        'سداد',
      );
    });

    test('credit purchase is a debt we owe', () {
      expect(
        txClarification(TxType.purchaseCredit, PersonType.supplier),
        'دين علينا',
      );
    });

    test('paid payment is a settlement to the supplier', () {
      expect(
        txClarification(TxType.paymentPaid, PersonType.supplier),
        'سداد للمورّد',
      );
    });

    test('discount wording follows the person type', () {
      expect(
        txClarification(TxType.discount, PersonType.customer),
        'خصم من الدين',
      );
      expect(
        txClarification(TxType.discount, PersonType.supplier),
        'خصم من المستحق',
      );
    });
  });

  group('personMatchesFilter (people-tab filter chips)', () {
    test('all matches everyone', () {
      expect(
        personMatchesFilter(
          type: PersonType.customer,
          balance: 40,
          filter: PersonFilter.all,
        ),
        isTrue,
      );
    });

    test('customers / suppliers split by type only', () {
      expect(
        personMatchesFilter(
          type: PersonType.supplier,
          balance: 40,
          filter: PersonFilter.customers,
        ),
        isFalse,
      );
      expect(
        personMatchesFilter(
          type: PersonType.supplier,
          balance: -40,
          filter: PersonFilter.suppliers,
        ),
        isTrue,
      );
    });

    test('«عليه رصيد» is a positive balance (they owe us)', () {
      expect(
        personMatchesFilter(
          type: PersonType.customer,
          balance: 40,
          filter: PersonFilter.owedToUs,
        ),
        isTrue,
      );
      expect(
        personMatchesFilter(
          type: PersonType.customer,
          balance: -40,
          filter: PersonFilter.owedToUs,
        ),
        isFalse,
      );
    });

    test('«له رصيد» is a negative balance (we owe them)', () {
      expect(
        personMatchesFilter(
          type: PersonType.supplier,
          balance: -40,
          filter: PersonFilter.owedToThem,
        ),
        isTrue,
      );
      expect(
        personMatchesFilter(
          type: PersonType.supplier,
          balance: 40,
          filter: PersonFilter.owedToThem,
        ),
        isFalse,
      );
    });

    test('zero balance matches neither balance chip', () {
      expect(
        personMatchesFilter(
          type: PersonType.customer,
          balance: 0,
          filter: PersonFilter.owedToUs,
        ),
        isFalse,
      );
      expect(
        personMatchesFilter(
          type: PersonType.customer,
          balance: 0,
          filter: PersonFilter.owedToThem,
        ),
        isFalse,
      );
    });
  });

  group('netBalanceLabel (dashboard net badge, not a person)', () {
    test('positive net is customers’ debt to us', () {
      expect(netBalanceLabel(80), 'مديونية عملاء');
    });

    test('negative net mirrors to what we owe', () {
      expect(netBalanceLabel(-40), 'مديونية علينا');
    });

    test('zero net is balanced', () {
      expect(netBalanceLabel(0), 'متعادل');
    });

    test('per-person wording is untouched by the dashboard label', () {
      expect(balanceWord(80), 'عليه');
      expect(balanceWord(-80), 'له');
    });
  });

  group('shortLabel (one-line rows with a date)', () {
    test('cash payment labels shorten, full labels stay intact', () {
      expect(TxType.paymentReceived.shortLabel, 'دفعة مستلمة');
      expect(TxType.paymentPaid.shortLabel, 'دفعة مدفوعة');
      expect(TxType.paymentReceived.label, 'دفعة نقدية مستلمة');
      expect(TxType.paymentPaid.label, 'دفعة نقدية مدفوعة');
    });

    test('other types keep their label as the short label', () {
      expect(TxType.saleCredit.shortLabel, 'بيع آجل');
      expect(TxType.purchaseCredit.shortLabel, 'شراء آجل');
      expect(TxType.discount.shortLabel, 'خصم');
    });

    test('activity line shows the full date, never truncated', () {
      final line =
          '${TxType.paymentReceived.shortLabel} • '
          '${formatDayDate(DateTime(2026, 11, 24))}';
      expect(line, 'دفعة مستلمة • 24-11-2026');
      expect(line.contains('24-11-2026'), isTrue);
      expect(line.contains('...'), isFalse);
    });
  });

  group('BrandColors (approved identity guide)', () {
    test('exact hex values from the guide', () {
      expect(BrandColors.navy, const Color(0xFF0D1726));
      expect(BrandColors.gold, const Color(0xFFD4AF37));
      expect(BrandColors.background, const Color(0xFFF4F6F9));
      expect(BrandColors.success, const Color(0xFF16A34A));
      expect(BrandColors.successBg, const Color(0xFFDCFCE7));
      expect(BrandColors.danger, const Color(0xFFDC2626));
      expect(BrandColors.dangerBg, const Color(0xFFFEE2E2));
    });
  });

  group('brand logo assets (transparent PNG, user-provided)', () {
    test('logo header and symbol are bundled and non-empty', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final header = await rootBundle.load(logoHeaderAsset);
      final symbol = await rootBundle.load(logoSymbolAsset);
      expect(header.lengthInBytes, greaterThan(0));
      expect(symbol.lengthInBytes, greaterThan(0));
      expect(logoHeaderAsset, 'assets/logo_header.png');
      expect(logoSymbolAsset, 'assets/logo_symbol.png');
    });
  });

  group('friendlyCloudError (sign_in_failed code 10 → Arabic)', () {
    test('exact phone error becomes the setup message', () {
      final message = friendlyCloudError(
        'PlatformException(sign_in_failed, f1: 10: , null, null)',
      );
      expect(message, cloudSetupIncompleteMessage);
      expect(message.contains('PlatformException'), isFalse);
      expect(message.contains('sign_in_failed'), isFalse);
      expect(message.contains('f1: 10'), isFalse);
    });

    test('ApiException 10 / DEVELOPER_ERROR / web client id', () {
      const variants = [
        'ApiException: 10: ',
        'DEVELOPER_ERROR',
        'default_web_client_id is missing',
      ];
      for (final variant in variants) {
        expect(
          friendlyCloudError(variant),
          cloudSetupIncompleteMessage,
        );
      }
    });

    test('network failure keeps the network message', () {
      expect(
        friendlyCloudError('SocketException: Failed host lookup'),
        contains('لا يوجد اتصال'),
      );
    });

    test('any other raw exception never leaks technical text', () {
      final message = friendlyCloudError(
        'PlatformException(unknown, something broke, null, null)',
      );
      expect(message.contains('PlatformException'), isFalse);
      expect(message.contains('Exception'), isFalse);
      expect(message.isNotEmpty, isTrue);
    });

    test('Drive 400 Invalid Value becomes an Arabic message', () {
      final message = friendlyCloudError(
        'DetailedApiRequestError(status: 400, message: Invalid Value)',
      );
      expect(message.contains('DetailedApiRequestError'), isFalse);
      expect(message.contains('Invalid Value'), isFalse);
      expect(message.contains('400'), isFalse);
      expect(message, contains('جوجل درايف'));
    });

    test('cloud backup space is the valid Drive value', () {
      expect(cloudBackupSpace, 'appDataFolder');
    });
  });

  group('cloudBackupStatus (Kanash-style status screen)', () {
    test('not signed in', () {
      const status = CloudBackupStatus.notSignedIn;
      expect(
        cloudBackupStatus(signedIn: false, hasUpload: false),
        status,
      );
      expect(
        cloudBackupStatusLabel(status),
        'غير مسجل بحساب جوجل بعد',
      );
    });

    test('signed in without any upload yet', () {
      const status = CloudBackupStatus.signedInNotUploaded;
      expect(
        cloudBackupStatus(signedIn: true, hasUpload: false),
        status,
      );
      expect(cloudBackupStatusLabel(status), 'لم يتم النسخ بعد');
    });

    test('signed in with a successful upload', () {
      const status = CloudBackupStatus.uploaded;
      expect(
        cloudBackupStatus(signedIn: true, hasUpload: true),
        status,
      );
      expect(
        cloudBackupStatusLabel(status),
        'اكتمل النسخ الاحتياطي',
      );
    });
  });

  group('cloudDialogActions (1.0.8 regression: saved email is not a session)', () {
    test('saved email without a live session offers sign-in, not upload', () {
      // The exact 1.0.7 bug on the user phone: cloud_email was stored
      // but the Google session was gone after the data wipe, so the
      // dialog hid the sign-in button while every upload failed with
      // «لم يتم تسجيل الدخول بحساب جوجل بعد».
      final actions = cloudDialogActions(
        signedIn: false,
        lastKnownEmail: 'abofares62022@gmail.com',
      );
      expect(actions.showSignIn, isTrue);
      expect(actions.showUpload, isFalse);
      expect(actions.showRestore, isFalse);
      expect(actions.hintEmail, 'abofares62022@gmail.com');
    });

    test('no saved email and no session offers sign-in with no hint', () {
      final actions = cloudDialogActions(
        signedIn: false,
        lastKnownEmail: null,
      );
      expect(actions.showSignIn, isTrue);
      expect(actions.showUpload, isFalse);
      expect(actions.showRestore, isFalse);
      expect(actions.hintEmail, isNull);
    });

    test('live session offers upload and restore, never sign-in', () {
      final actions = cloudDialogActions(
        signedIn: true,
        lastKnownEmail: 'abofares62022@gmail.com',
      );
      expect(actions.showSignIn, isFalse);
      expect(actions.showUpload, isTrue);
      expect(actions.showRestore, isTrue);
      expect(actions.hintEmail, isNull);
    });

    test('past upload without a live session is not "uploaded"', () {
      // Status must stay honest: a 01:42 upload exists, but with no
      // live session the automatic backup is off.
      expect(
        cloudBackupStatus(signedIn: false, hasUpload: true),
        CloudBackupStatus.notSignedIn,
      );
      expect(
        cloudBackupStatusLabel(CloudBackupStatus.notSignedIn),
        'غير مسجل بحساب جوجل بعد',
      );
    });

    test('not-signed-in message is a single shared constant', () {
      expect(cloudNotSignedInMessage, 'لم يتم تسجيل الدخول بحساب جوجل بعد.');
    });
  });

  group('backupUploadMetadata (1.0.9 regression: update must not send parents)', () {
    test('update metadata carries the name only, no parents', () {
      // The exact 1.0.8 bug on the user phone: the upload went through
      // files.update (the backup exists on Drive since 01:42) with
      // `parents` in the body, and Drive answered `400 Invalid Value`
      // — the Drive API only accepts parents via the addParents /
      // removeParents parameters, never in the update body.
      final meta = backupUploadMetadata(isUpdate: true);
      expect(meta.name, CloudBackupService.fileName);
      expect(meta.parents, isNull);
    });

    test('create metadata still carries the appDataFolder parent', () {
      final meta = backupUploadMetadata(isUpdate: false);
      expect(meta.name, CloudBackupService.fileName);
      expect(meta.parents, <String>[cloudBackupSpace]);
    });
  });

  group('backupCopiedRows (counts from real local data)', () {
    test('user data shape: 1 person, 3 entries', () {
      final rows = backupCopiedRows(persons: 1, entries: 3);
      expect(rows.length, 2);
      expect(rows[0].label, 'الأشخاص');
      expect(rows[0].count, 1);
      expect(rows[1].label, 'المعاملات');
      expect(rows[1].count, 3);
    });

    test('empty ledger shows zeros, never demo numbers', () {
      final rows = backupCopiedRows(persons: 0, entries: 0);
      expect(rows[0].count, 0);
      expect(rows[1].count, 0);
    });
  });
}
