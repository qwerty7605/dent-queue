import 'package:flutter/material.dart';

class AppDialogScaffold extends StatelessWidget {
  const AppDialogScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.headerContent,
    this.headerTrailing,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.onClose,
    required this.child,
    this.footer,
    this.maxWidth = 520,
    this.maxHeightFactor = 0.88,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 24,
    ),
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 20),
    this.bodyPadding = const EdgeInsets.only(top: 20),
    this.footerPadding = const EdgeInsets.only(top: 20),
    this.showFooterDivider = false,
    this.backgroundColor,
  });

  final String? title;
  final String? subtitle;
  final Widget? headerContent;
  final Widget? headerTrailing;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final VoidCallback? onClose;
  final Widget child;
  final Widget? footer;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsets insetPadding;
  final EdgeInsets padding;
  final EdgeInsets bodyPadding;
  final EdgeInsets footerPadding;
  final bool showFooterDivider;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;
    final bool hasHeader =
        headerContent != null || title != null || onClose != null;
    final ThemeData theme = Theme.of(context);

    return Dialog(
      insetPadding: insetPadding,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      surfaceTintColor: backgroundColor ?? theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasHeader) _buildHeader(context),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: hasHeader ? bodyPadding : EdgeInsets.zero,
                  child: child,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: footerPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (showFooterDivider) ...<Widget>[
                        Divider(height: 1, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                      ],
                      footer!,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Widget resolvedHeader =
        headerContent ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null)
              Text(
                title!,
                style:
                    titleTextStyle ??
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
              ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style:
                    subtitleTextStyle ??
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: resolvedHeader),
        if (headerTrailing != null) ...<Widget>[
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: headerTrailing!,
          ),
        ],
        if (onClose != null) ...<Widget>[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF1A253A)
                  : const Color(0xFFF8FAFC),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ],
    );
  }
}
