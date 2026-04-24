import 'package:flutter/material.dart';

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondaryPressed,
    required this.onPrimaryPressed,
    this.primaryColor = const Color(0xFF223C7A),
    this.primaryForegroundColor = Colors.white,
    this.secondaryColor = const Color(0xFFF4F7FF),
    this.secondaryForegroundColor = const Color(0xFF223C7A),
  });

  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final String title;
  final String message;
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onPrimaryPressed;
  final Color primaryColor;
  final Color primaryForegroundColor;
  final Color secondaryColor;
  final Color secondaryForegroundColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF223C7A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5F6E86),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ConfirmationButton(
                    label: secondaryLabel,
                    backgroundColor: secondaryColor,
                    foregroundColor: secondaryForegroundColor,
                    onPressed: onSecondaryPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ConfirmationButton(
                    label: primaryLabel,
                    backgroundColor: primaryColor,
                    foregroundColor: primaryForegroundColor,
                    onPressed: onPrimaryPressed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationButton extends StatelessWidget {
  const _ConfirmationButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}
