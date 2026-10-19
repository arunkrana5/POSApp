import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// Native print implementation for non-web platforms (Android / iOS / Windows / macOS / Linux)
Future<void> printHtmlWeb(String htmlContent) async {
  try {
    await Printing.layoutPdf(
      // ignore: deprecated_member_use
      onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
        format: format,
        html: htmlContent,
      ),
    );
  } catch (e) {
    debugPrint('Native print error: $e');
  }
}
