import 'package:flutter/material.dart';

import 'app_dialog_scaffold.dart';

Future<void> showAppointmentSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'Close',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AppointmentSuccessDialog(
        title: title,
        message: message,
        buttonLabel: buttonLabel,
        onClose: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

class AppointmentSuccessDialog extends StatelessWidget {
  const AppointmentSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
    this.buttonLabel = 'Close',
  });

  final String title;
  final String message;
  final VoidCallback onClose;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return AppDialogScaffold(
      maxWidth: 390,
      backgroundColor: isDark ? const Color(0xFF101A2C) : Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 26),
      bodyPadding: EdgeInsets.zero,
      footerPadding: const EdgeInsets.only(top: 28),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF233D78),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            buttonLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FBF1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF27C38F),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: Color(0xFF27C38F),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1F3763),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFAAB7CD) : const Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF17243A) : const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text(
                  'QUEUE STATUS',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFAAB7CD)
                        : const Color(0xFF9AA3B2),
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF22314D) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Waiting Approval',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF3A4B68),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
