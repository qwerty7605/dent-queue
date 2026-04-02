import 'package:flutter/material.dart';

class AuthPalette {
  static const Color pageBackground = Color(0xFFF1F6EC);
  static const Color panel = Color(0xFF2F6840);
  static const Color panelDark = Color(0xFF255234);
  static const Color panelMuted = Color(0xFF5E8E69);
  static const Color surface = Color(0xFFFFFCF7);
  static const Color surfaceMuted = Color(0xFFF4EEE4);
  static const Color textPrimary = Color(0xFF163321);
  static const Color textSecondary = Color(0xFF5C6F60);
  static const Color accent = Color(0xFFE0B24C);
  static const Color accentDark = Color(0xFFBE9135);
  static const Color border = Color(0xFFD7E2D2);
  static const Color error = Color(0xFFC0392B);
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.pageBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3E3), Color(0xFFF7FBF2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 1100;
              final isTablet = width >= 700;
              final horizontalPadding = isDesktop
                  ? 44.0
                  : (isTablet ? 28.0 : 18.0);
              final topPadding = isTablet ? 20.0 : 12.0;
              final content = isDesktop
                  ? Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              topPadding,
                              20,
                              24,
                            ),
                            child: const _AuthHeroPanel(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              topPadding,
                              horizontalPadding,
                              24,
                            ),
                            child: _AuthContentCard(
                              eyebrow: eyebrow,
                              title: title,
                              subtitle: subtitle,
                              footer: footer,
                              child: child,
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topPadding,
                        horizontalPadding,
                        24,
                      ),
                      child: Column(
                        children: [
                          const _AuthHeroPanel(compact: true),
                          const SizedBox(height: 18),
                          _AuthContentCard(
                            eyebrow: eyebrow,
                            title: title,
                            subtitle: subtitle,
                            footer: footer,
                            child: child,
                          ),
                        ],
                      ),
                    );

              return content;
            },
          ),
        ),
      ),
    );
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = compact ? screenHeight * 0.34 : double.infinity;

    return Container(
      height: compact ? panelHeight.clamp(240.0, 360.0) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AuthPalette.panel, AuthPalette.panelDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A163321),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1FEAF3E3),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1FD2E6C9),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 24 : 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) const Spacer(),
                Container(
                  width: compact ? 72 : 92,
                  height: compact ? 72 : 92,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: compact ? 18 : 24),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: compact ? 28 : 38,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                    children: const [
                      TextSpan(
                        text: 'SMART',
                        style: TextStyle(color: AuthPalette.accent),
                      ),
                      TextSpan(
                        text: 'DentQueue',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 12 : 18),
                Text(
                  'Smarter dental queueing for patients who need a clean, calm start.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: compact ? 14 : 17,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: compact ? 18 : 26),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFFDDE9D4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          compact
                              ? 'Secure access for appointments and queue updates.'
                              : 'Secure patient access for appointments, records, and queue updates.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: compact ? 13 : 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthContentCard extends StatelessWidget {
  const _AuthContentCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallPhone = width < 360;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: AuthPalette.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14163321),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallPhone ? 18 : 26,
              isSmallPhone ? 22 : 28,
              isSmallPhone ? 18 : 26,
              isSmallPhone ? 18 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AuthPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      color: AuthPalette.accentDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: AuthPalette.textPrimary,
                    fontSize: isSmallPhone ? 27 : 34,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AuthPalette.textSecondary,
                    fontSize: isSmallPhone ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 26),
                child,
                if (footer != null) ...[const SizedBox(height: 20), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.errorText,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExternalError = errorText != null && errorText!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AuthPalette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AuthPalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          decoration: _fieldDecoration(
            context,
            hint: hint,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
        if (hasExternalError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AuthPalette.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthDropdownField extends StatelessWidget {
  const AuthDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Select an option',
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AuthPalette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: _fieldDecoration(
            context,
            hint: hint,
            prefixIcon: const Icon(
              Icons.wc_rounded,
              color: AuthPalette.panelMuted,
            ),
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AuthPalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hint,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final theme = Theme.of(context);

  return InputDecoration(
    hintText: hint,
    errorText: null,
    hintStyle: theme.textTheme.bodyLarge?.copyWith(
      color: AuthPalette.textSecondary.withValues(alpha: 0.7),
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: errorText != null ? AuthPalette.error : AuthPalette.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: errorText != null ? AuthPalette.error : AuthPalette.panel,
        width: 1.6,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AuthPalette.error, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AuthPalette.error, width: 1.6),
    ),
    errorStyle: const TextStyle(
      color: AuthPalette.error,
      fontWeight: FontWeight.w700,
    ),
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthPalette.panel,
          disabledBackgroundColor: AuthPalette.panelMuted,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          prompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AuthPalette.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuthPalette.accentDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
