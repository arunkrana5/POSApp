import 'package:flutter_test/flutter_test.dart';
import 'package:village_shop_mobile/utils/whatsapp_phone_normalizer.dart';

void main() {
  group('WhatsAppPhoneNormalizer Tests', () {
    test('Standard 10-digit Indian number prepends 91', () {
      final res = WhatsAppPhoneNormalizer.normalize('8581896270');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '918581896270');
      expect(res.chatId, '918581896270@c.us');
    });

    test('Formatted Indian number with spaces and +91', () {
      final res = WhatsAppPhoneNormalizer.normalize('+91 85818 96270');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '918581896270');
      expect(res.chatId, '918581896270@c.us');
    });

    test('Formatted Indian number with hyphens 91-8581896270', () {
      final res = WhatsAppPhoneNormalizer.normalize('91-8581896270');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '918581896270');
      expect(res.chatId, '918581896270@c.us');
    });

    test('11-digit number with leading 0 trunk prefix strips 0 and prepends 91', () {
      final res = WhatsAppPhoneNormalizer.normalize('08581896270');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '918581896270');
      expect(res.chatId, '918581896270@c.us');
    });

    test('10-digit subscriber number starting with 91 (e.g. 9162886117) prepends 91', () {
      // Critical bug fix: 9162886117 must become 919162886117, NOT left as 10 digits
      final res = WhatsAppPhoneNormalizer.normalize('9162886117');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '919162886117');
      expect(res.chatId, '919162886117@c.us');
    });

    test('10-digit subscriber starting with 91 with leading 0 (09162886117)', () {
      final res = WhatsAppPhoneNormalizer.normalize('09162886117');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '919162886117');
      expect(res.chatId, '919162886117@c.us');
    });

    test('12-digit number starting with +91 91... (+91 9162886117)', () {
      final res = WhatsAppPhoneNormalizer.normalize('+91 9162886117');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '919162886117');
      expect(res.chatId, '919162886117@c.us');
    });

    test('+91 with leading 0 before subscriber number (+91 08581896270)', () {
      final res = WhatsAppPhoneNormalizer.normalize('+91 08581896270');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '918581896270');
      expect(res.chatId, '918581896270@c.us');
    });

    test('14-digit duplicate country code (91918581896270) removes duplicate 91', () {
      final res = WhatsAppPhoneNormalizer.normalize('91918581896270');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '918581896270');
      expect(res.chatId, '918581896270@c.us');
    });

    test('International number with country code (+1 555 123 4567)', () {
      final res = WhatsAppPhoneNormalizer.normalize('+1 555 123 4567');
      expect(res.isValid, isTrue);
      expect(res.normalizedPhone, '15551234567');
      expect(res.chatId, '15551234567@c.us');
    });

    test('Invalid numbers return clear error message', () {
      expect(WhatsAppPhoneNormalizer.normalize('').isValid, isFalse);
      expect(WhatsAppPhoneNormalizer.normalize('   ').isValid, isFalse);
      expect(WhatsAppPhoneNormalizer.normalize('12345').isValid, isFalse);
      expect(WhatsAppPhoneNormalizer.normalize('0000000000').isValid, isFalse);
      expect(WhatsAppPhoneNormalizer.normalize('1111111111').isValid, isFalse);
      expect(WhatsAppPhoneNormalizer.normalize('3581896270').isValid, isFalse);
    });
  });
}
