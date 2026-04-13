import 'package:flutter/material.dart';

class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
    this.titlePadding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool scrollable;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;
  final EdgeInsets actionsPadding;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      scrollable: scrollable,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: titlePadding,
      contentPadding: contentPadding,
      actionsPadding: actionsPadding,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF1E293B),
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF64748B),
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      title: title,
      content: content,
      actions: actions,
    );
  }
}
