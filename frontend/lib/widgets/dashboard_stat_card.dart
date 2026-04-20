import 'package:flutter/material.dart';

import '../core/mobile_typography.dart';

enum DashboardCardContentAlignment { start, center }

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    this.onTap,
    this.isSelected = false,
    this.contentAlignment = DashboardCardContentAlignment.center,
    this.contentColor,
    this.iconColor,
    this.iconBackgroundColor,
    this.valueStyle,
    this.titleStyle,
    this.footerLabel,
    this.footerBackgroundColor,
    this.footerTextColor,
    this.footerIcon,
    this.borderColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final DashboardCardContentAlignment contentAlignment;
  final Color? contentColor;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final TextStyle? valueStyle;
  final TextStyle? titleStyle;
  final String? footerLabel;
  final Color? footerBackgroundColor;
  final Color? footerTextColor;
  final IconData? footerIcon;

  static final BorderRadius _cardRadius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final Color resolvedContentColor = contentColor ?? accentColor;
    final Color resolvedIconColor = iconColor ?? accentColor;
    final Color resolvedIconBackgroundColor =
        iconBackgroundColor ?? accentColor.withValues(alpha: 0.12);
    final EdgeInsets contentPadding =
        contentAlignment == DashboardCardContentAlignment.start
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final Widget child = Ink(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: _cardRadius,
        border: Border.all(
          color: borderColor ?? (isSelected
              ? accentColor.withValues(alpha: 0.34)
              : accentColor.withValues(alpha: 0.12)),
          width: borderColor != null ? 1.5 : (isSelected ? 1.6 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: contentPadding,
              child: contentAlignment == DashboardCardContentAlignment.start
                  ? _buildStartContent(
                      context,
                      resolvedContentColor,
                      resolvedIconColor,
                      resolvedIconBackgroundColor,
                    )
                  : _buildCenteredContent(
                      context,
                      resolvedContentColor,
                      resolvedIconColor,
                      resolvedIconBackgroundColor,
                    ),
            ),
          ),
          if (footerLabel != null)
            _buildFooter(
              footerLabel!,
              footerTextColor ?? Colors.white,
              footerBackgroundColor ?? accentColor,
              footerIcon ?? Icons.arrow_circle_right,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: _cardRadius, onTap: onTap, child: child),
    );
  }

  Widget _buildCenteredContent(
    BuildContext context,
    Color resolvedContentColor,
    Color resolvedIconColor,
    Color resolvedIconBackgroundColor,
  ) {
    final TextStyle resolvedValueStyle =
        valueStyle ??
        TextStyle(
          fontSize: MobileTypography.sectionTitle(context) + 4,
          fontWeight: FontWeight.w900,
          color: resolvedContentColor,
          height: 1,
        );
    final TextStyle resolvedTitleStyle =
        titleStyle ??
        TextStyle(
          fontSize: MobileTypography.caption(context),
          fontWeight: FontWeight.w900,
          color: resolvedContentColor,
          letterSpacing: 0.4,
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconBadge(
          resolvedIconColor,
          resolvedIconBackgroundColor,
          size: 42,
        ),
        if (value.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(value, style: resolvedValueStyle, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: resolvedTitleStyle,
        ),
      ],
    );
  }

  Widget _buildStartContent(
    BuildContext context,
    Color resolvedContentColor,
    Color resolvedIconColor,
    Color resolvedIconBackgroundColor,
  ) {
    final TextStyle resolvedValueStyle =
        valueStyle ??
        TextStyle(
          fontSize: MobileTypography.sectionTitle(context) + 8,
          fontWeight: FontWeight.w900,
          color: resolvedContentColor,
          height: 1,
        );
    final TextStyle resolvedTitleStyle =
        titleStyle ??
        TextStyle(
          fontSize: MobileTypography.cardTitle(context),
          fontWeight: FontWeight.w800,
          color: resolvedContentColor,
          height: 1.15,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value.trim().isNotEmpty) ...[
                Text(value, style: resolvedValueStyle),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: resolvedTitleStyle,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildIconBadge(
          resolvedIconColor,
          resolvedIconBackgroundColor,
          size: 48,
        ),
      ],
    );
  }

  Widget _buildIconBadge(
    Color resolvedIconColor,
    Color resolvedIconBackgroundColor, {
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolvedIconBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: size * 0.56, color: resolvedIconColor),
    );
  }

  Widget _buildFooter(
    String label,
    Color textColor,
    Color backgroundColor,
    IconData iconData,
  ) {
    return Ink(
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Icon(iconData, color: textColor, size: 20),
        ],
      ),
    );
  }
}
