import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TenantThemeProvider with ChangeNotifier {
  Color primaryColor = const Color(0xFF0F172A); // Dark Slate Header
  Color secondaryColor = const Color(0xFFD97706); // Gold Accent
  Color accentColor = const Color(0xFF10B981); // Emerald

  Color textColor = const Color(0xFF0F172A);
  Color pageBgColor = const Color(0xFFF8FAFC);
  Color cardBgColor = const Color(0xFFFFFFFF);
  Color amountColor = const Color(0xFF16A34A);
  Color buttonBgColor = const Color(0xFF2563EB);
  Color buttonTextColor = const Color(0xFFFFFFFF);

  String fontFamily = 'Roboto';
  double fontSizeScale = 1.0;

  String tenantName = "Store Client";
  String appTitle = "STORE POS";
  String logoUrl = "";
  List<String> enabledModules = ["POS", "Products", "Customers", "Reports", "Sync", "Settings"];
  List<Map<String, dynamic>> dynamicMenuItems = [];

  // 360-Degree Feature & Control Flags
  bool enableUdhaar = true;
  bool enableBarcodeScanner = true;
  bool enableOnlinePayment = true;
  bool enableHindiLanguage = true;
  bool enableReceiptPrinting = true;
  bool enablePOSDiscount = true;
  bool enableTaxCalculation = true;
  double defaultTaxPercent = 5.0;
  bool allowNegativeStock = false;
  int lowStockThreshold = 5;

  String supportPhone = "";
  String supportEmail = "support@store.com";
  String supportWhatsapp = "+91 98765 43210";
  String supportHours = "9:00 AM - 9:00 PM";
  String currencySymbol = "₹";

  Future<void> fetchAndApplyConfig([String token = '', String? tenantCode, int? tenantId]) async {
    List<String> candidateUrls = [
      ...ApiConfig.candidateUrls,
      'http://192.168.0.208:5000/api',
      'http://192.168.137.1:5000/api',
      'http://192.168.1.34:5000/api',
      'http://127.0.0.1:5000/api',
    ];
    candidateUrls = candidateUrls.toSet().toList();

    for (String base in candidateUrls) {
      try {
        final queryParams = <String>[];
        if (tenantId != null && tenantId > 0) queryParams.add('tenantId=$tenantId');
        if (tenantCode != null && tenantCode.isNotEmpty) queryParams.add('tenantCode=$tenantCode');
        final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

        final response = await http.get(
          Uri.parse('$base/settings/mobile-config$queryString'),
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            if (tenantId != null && tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
            if (tenantCode != null && tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final outerJson = jsonDecode(response.body);
          if (outerJson['status'] == true && outerJson['additionalMessage'] != null) {
            final Map<String, dynamic> config = jsonDecode(outerJson['additionalMessage']);
            
            final primaryHex = _getValidHex(config, ['PrimaryColorHex', 'primaryColorHex', 'PrimaryColor', 'primaryColor']);
            final secondaryHex = _getValidHex(config, ['SecondaryColorHex', 'secondaryColorHex', 'SecondaryColor', 'secondaryColor']);
            final accentHex = _getValidHex(config, ['AccentColorHex', 'accentColorHex', 'AccentColor', 'accentColor']);

            final textHex = _getValidHex(config, ['TextColorHex', 'textColorHex', 'TextColor', 'textColor']);
            final pageBgHex = _getValidHex(config, ['PageBgColorHex', 'pageBgColorHex', 'PageBgColor', 'pageBgColor']);
            final cardBgHex = _getValidHex(config, ['CardBgColorHex', 'cardBgColorHex', 'CardBgColor', 'cardBgColor']);
            final amountHex = _getValidHex(config, ['AmountColorHex', 'amountColorHex', 'AmountColor', 'amountColor']);
            final buttonBgHex = _getValidHex(config, ['ButtonBgColorHex', 'buttonBgColorHex', 'ButtonBgColor', 'buttonBgColor']);
            final buttonTextHex = _getValidHex(config, ['ButtonTextColorHex', 'buttonTextColorHex', 'ButtonTextColor', 'buttonTextColor']);

            final fontFam = config['FontFamily'] ?? config['fontFamily'];
            final fontScale = config['FontSizeScale'] ?? config['fontSizeScale'];

            final name = config['TenantName'] ?? config['tenantName'] ?? config['AppName'] ?? config['appName'];
            final title = config['AppTitle'] ?? config['appTitle'] ?? config['AppName'] ?? config['appName'];
            final logo = config['LogoUrl'] ?? config['logoUrl'];
            final rawMenuItems = config['MenuItems'] ?? config['menuItems'];

            final enablePOSDisc = config['EnablePOSDiscount'] ?? config['enablePOSDiscount'];
            final enableTaxCalc = config['EnableTaxCalculation'] ?? config['enableTaxCalculation'];
            final defTax = config['DefaultTaxPercent'] ?? config['defaultTaxPercent'];
            final allowNeg = config['AllowNegativeStock'] ?? config['allowNegativeStock'];
            final lowStock = config['LowStockThreshold'] ?? config['lowStockThreshold'];
            final currSym = config['CurrencySymbol'] ?? config['currencySymbol'];

            final suppPhone = config['SupportPhone'] ?? config['supportPhone'];
            final suppEmail = config['SupportEmail'] ?? config['supportEmail'];
            final suppWhatsapp = config['SupportWhatsapp'] ?? config['supportWhatsapp'];
            final suppHoursVal = config['SupportHours'] ?? config['supportHours'];

            final enUdhaar = config['EnableUdhaar'] ?? config['enableUdhaar'];
            final enScanner = config['EnableBarcodeScanner'] ?? config['enableBarcodeScanner'];
            final enOnline = config['EnableOnlinePayment'] ?? config['enableOnlinePayment'];
            final enHindi = config['EnableHindiLanguage'] ?? config['enableHindiLanguage'];
            final enReceipt = config['EnableReceiptPrinting'] ?? config['enableReceiptPrinting'];

            if (primaryHex != null) primaryColor = _hexToColor(primaryHex, const Color(0xFF0F172A));
            if (secondaryHex != null) secondaryColor = _hexToColor(secondaryHex, const Color(0xFFD97706));
            if (accentHex != null) accentColor = _hexToColor(accentHex, const Color(0xFF10B981));

            if (textHex != null) textColor = _hexToColor(textHex, const Color(0xFF0F172A));
            if (pageBgHex != null) pageBgColor = _hexToColor(pageBgHex, const Color(0xFFF8FAFC));
            if (cardBgHex != null) cardBgColor = _hexToColor(cardBgHex, const Color(0xFFFFFFFF));
            if (amountHex != null) amountColor = _hexToColor(amountHex, const Color(0xFF16A34A));
            if (buttonBgHex != null) buttonBgColor = _hexToColor(buttonBgHex, const Color(0xFF2563EB));
            if (buttonTextHex != null) buttonTextColor = _hexToColor(buttonTextHex, const Color(0xFFFFFFFF));

            if (fontFam != null && fontFam.toString().isNotEmpty) fontFamily = fontFam.toString();
            if (fontScale != null) {
              try {
                fontSizeScale = double.parse(fontScale.toString());
              } catch (_) {}
            }

            if (name != null) tenantName = name.toString();
            if (title != null) appTitle = title.toString();
            if (logo != null) logoUrl = logo.toString();

            if (enablePOSDisc != null) enablePOSDiscount = enablePOSDisc == true || enablePOSDisc.toString().toLowerCase() == 'true';
            if (enableTaxCalc != null) enableTaxCalculation = enableTaxCalc == true || enableTaxCalc.toString().toLowerCase() == 'true';
            if (defTax != null) {
              try { defaultTaxPercent = double.parse(defTax.toString()); } catch (_) {}
            }
            if (allowNeg != null) allowNegativeStock = allowNeg == true || allowNeg.toString().toLowerCase() == 'true';
            if (lowStock != null) {
              try { lowStockThreshold = int.parse(lowStock.toString()); } catch (_) {}
            }
            if (currSym != null && currSym.toString().isNotEmpty) currencySymbol = currSym.toString();

            if (suppPhone != null) supportPhone = suppPhone.toString();
            if (suppEmail != null) supportEmail = suppEmail.toString();
            if (suppWhatsapp != null) supportWhatsapp = suppWhatsapp.toString();
            if (suppHoursVal != null) supportHours = suppHoursVal.toString();

            if (enUdhaar != null) enableUdhaar = enUdhaar == true || enUdhaar.toString().toLowerCase() == 'true';
            if (enScanner != null) enableBarcodeScanner = enScanner == true || enScanner.toString().toLowerCase() == 'true';
            if (enOnline != null) enableOnlinePayment = enOnline == true || enOnline.toString().toLowerCase() == 'true';
            if (enHindi != null) enableHindiLanguage = enHindi == true || enHindi.toString().toLowerCase() == 'true';
            if (enReceipt != null) enableReceiptPrinting = enReceipt == true || enReceipt.toString().toLowerCase() == 'true';

            if (rawMenuItems != null && rawMenuItems is List) {
              dynamicMenuItems = List<Map<String, dynamic>>.from(rawMenuItems.map((e) => Map<String, dynamic>.from(e)));
            }
            notifyListeners();
            break; // Successfully loaded config
          }
        }
      } catch (_) {
        // Fallback to next candidate IP
      }
    }
  }

  void updateColors(String primaryHex, String secondaryHex) {
    primaryColor = _hexToColor(primaryHex);
    secondaryColor = _hexToColor(secondaryHex);
    notifyListeners();
  }

  String? _getValidHex(Map<String, dynamic> config, List<String> keys) {
    for (final key in keys) {
      final val = config[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return null;
  }

  Color _hexToColor(String hex, [Color fallback = const Color(0xFF0F172A)]) {
    final clean = hex.replaceFirst('#', '').trim();
    if (clean.isEmpty) return fallback;
    final buffer = StringBuffer();
    if (clean.length == 6) buffer.write('ff');
    buffer.write(clean);
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  ThemeData get themeData {
    final baseTextTheme = Typography.material2021().black;
    final scaledTextTheme = baseTextTheme.copyWith(
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16 * fontSizeScale, color: textColor),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14 * fontSizeScale, color: textColor),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 12 * fontSizeScale, color: textColor.withOpacity(0.7)),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 20 * fontSizeScale, fontWeight: FontWeight.bold, color: textColor),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 16 * fontSizeScale, fontWeight: FontWeight.w600, color: textColor),
      titleSmall: TextStyle(fontFamily: fontFamily, fontSize: 14 * fontSizeScale, fontWeight: FontWeight.w600, color: textColor),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14 * fontSizeScale, fontWeight: FontWeight.bold, color: buttonTextColor),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: 12 * fontSizeScale, color: textColor),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 10 * fontSizeScale, color: textColor),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: pageBgColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: cardBgColor,
        background: pageBgColor,
        onBackground: textColor,
        onSurface: textColor,
      ),
      textTheme: scaledTextTheme,
      cardTheme: CardTheme(
        color: cardBgColor,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18 * fontSizeScale, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonBgColor,
        foregroundColor: buttonTextColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBgColor,
          foregroundColor: buttonTextColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 16 * fontSizeScale, fontWeight: FontWeight.bold, color: buttonTextColor),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBgColor,
          foregroundColor: buttonTextColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 16 * fontSizeScale, fontWeight: FontWeight.bold, color: buttonTextColor),
        ),
      ),
    );
  }
}

