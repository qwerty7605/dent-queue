import 'package:flutter/material.dart';

import '../core/mobile_typography.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.iconColor = const Color(0xFF1A2F64),
    this.iconBackgroundColor = const Color(0xFFE2ECFA),
    this.maxWidth = 420,
    this.compact = false,
    this.framed = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final double maxWidth;
  final bool compact;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 72 : 88,
          height: compact ? 72 : 88,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: compact ? 34 : 40, color: iconColor),
        ),
        SizedBox(height: compact ? 18 : 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontSize: compact
                ? MobileTypography.cardTitle(context)
                : MobileTypography.sectionTitle(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF64748B),
            fontSize: MobileTypography.bodySmall(context),
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: compact ? 16 : 18),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.arrow_forward_rounded, size: 18),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A2F64),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 18,
                vertical: compact ? 12 : 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: TextStyle(
                fontSize: MobileTypography.bodySmall(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );

    final Widget decoratedContent = framed
        ? Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 24,
              vertical: compact ? 22 : 28,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 18 : 24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: content,
          )
        : content;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: decoratedContent,
      ),
    );
  }
}
