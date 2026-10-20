class NormalizedPhoneResult {
  final bool isValid;
  final String normalizedPhone;
  final String chatId;
  final String errorMessage;

  NormalizedPhoneResult({
    required this.isValid,
    this.normalizedPhone = '',
    this.chatId = '',
    this.errorMessage = '',
  });
}

class WhatsAppPhoneNormalizer {
  /// Normalizes any input phone number (raw, formatted, with/without +91, with/without 0)
  /// into the exact format required by Green API and international WhatsApp URLs.
  /// Green API requires {countryCode}{subscriberNumber}@c.us without '+' or leading '0'.
  /// For India, that is 91XXXXXXXXXX (12 digits total).
  static NormalizedPhoneResult normalize(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return NormalizedPhoneResult(
        isValid: false,
        errorMessage: 'Phone number cannot be empty.',
      );
    }

    final trimmed = rawPhone.trim();
    final hasPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return NormalizedPhoneResult(
        isValid: false,
        errorMessage: 'Phone number contains no valid digits.',
      );
    }

    // Check for dummy repeating digits (e.g. 0000000000, 1111111111)
    if (RegExp(r'^(\d)\1{9,}$').hasMatch(digits)) {
      return NormalizedPhoneResult(
        isValid: false,
        errorMessage: 'Invalid phone number containing repeating digits.',
      );
    }

    // 1. Remove leading trunk prefix 0 if 11 digits (e.g. 08581896270 -> 8581896270)
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // 2. Remove leading 0 after country code 91 if 13 digits (e.g. +91 08581896270 -> 918581896270)
    if (digits.length == 13 && digits.startsWith('910')) {
      digits = '91${digits.substring(3)}';
    }

    // 3. Remove duplicate country code if 14 digits starting with 9191 (e.g. 91918581896270 -> 918581896270)
    if (digits.length == 14 && digits.startsWith('9191')) {
      digits = digits.substring(2);
    }

    // 4. Standard 10-digit Indian mobile number (starts with 6, 7, 8, 9, including 91xxxxxxxx)
    if (digits.length == 10) {
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
        final norm = '91$digits';
        return NormalizedPhoneResult(
          isValid: true,
          normalizedPhone: norm,
          chatId: '$norm@c.us',
        );
      } else {
        return NormalizedPhoneResult(
          isValid: false,
          errorMessage: 'Indian mobile numbers must be 10 digits starting with 6, 7, 8, or 9.',
        );
      }
    }

    // 5. 12-digit Indian mobile number with 91 prefix (91 + 10 digits starting with 6, 7, 8, or 9)
    if (digits.length == 12 && digits.startsWith('91')) {
      final national = digits.substring(2);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(national)) {
        return NormalizedPhoneResult(
          isValid: true,
          normalizedPhone: digits,
          chatId: '$digits@c.us',
        );
      } else {
        return NormalizedPhoneResult(
          isValid: false,
          errorMessage: 'Invalid 10-digit Indian subscriber number following country code 91.',
        );
      }
    }

    // 6. International numbers with explicit '+' prefix or valid ITU E.164 length (10 to 15 digits)
    if (hasPlus && digits.length >= 10 && digits.length <= 15) {
      return NormalizedPhoneResult(
        isValid: true,
        normalizedPhone: digits,
        chatId: '$digits@c.us',
      );
    }

    return NormalizedPhoneResult(
      isValid: false,
      errorMessage: 'Invalid phone number (${digits.length} digits). Please enter a valid 10-digit Indian mobile number (e.g. 9876543210).',
    );
  }
}
