import 'package:flutter/material.dart';

class ToastHelper {
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.check_circle_rounded,
      bgColor: const Color(0xFF10B981),
    );
  }

  static void showError(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.error_rounded,
      bgColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 4),
    );
  }

  static void _showToast({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color bgColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    OverlayState? overlayState;
    try {
      overlayState = Overlay.of(context, rootOverlay: true);
    } catch (_) {
      try {
        overlayState = Overlay.of(context);
      } catch (_) {}
    }

    if (overlayState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
        ),
      );
      return;
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    try {
                      overlayEntry.remove();
                    } catch (_) {}
                  },
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    Future.delayed(duration, () {
      try {
        overlayEntry.remove();
      } catch (_) {}
    });
  }

  /// Returns an inline alert banner widget to render directly inside dialogs / modals
  static Widget buildInlineAlert(String message, {bool isError = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isError ? Colors.red.shade300 : Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? Colors.red.shade700 : Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red.shade900 : Colors.green.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
