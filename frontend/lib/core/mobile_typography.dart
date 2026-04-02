import 'package:flutter/material.dart';

class MobileTypography {
  const MobileTypography._();

  static double _width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static bool isPhone(BuildContext context) => _width(context) < 600;

  static double _size(
    BuildContext context, {
    required double phone,
    double? compactPhone,
    double? tablet,
    double? desktop,
  }) {
    final width = _width(context);
    if (width < 380) {
      return compactPhone ?? phone;
    }
    if (width < 600) {
      return phone;
    }
    if (width < 1024) {
      return tablet ?? phone;
    }
    return desktop ?? tablet ?? phone;
  }

  static double pageTitle(BuildContext context) =>
      _size(context, compactPhone: 24, phone: 28, tablet: 30, desktop: 32);

  static double sectionTitle(BuildContext context) =>
      _size(context, compactPhone: 18, phone: 20, tablet: 22, desktop: 24);

  static double cardTitle(BuildContext context) =>
      _size(context, compactPhone: 16, phone: 18, tablet: 18, desktop: 20);

  static double body(BuildContext context) =>
      _size(context, compactPhone: 14, phone: 16, tablet: 16);

  static double bodySmall(BuildContext context) =>
      _size(context, compactPhone: 13, phone: 14, tablet: 14);

  static double label(BuildContext context) =>
      _size(context, compactPhone: 13, phone: 14, tablet: 13);

  static double caption(BuildContext context) =>
      _size(context, compactPhone: 12, phone: 13, tablet: 12);

  static double button(BuildContext context) =>
      _size(context, compactPhone: 15, phone: 16, tablet: 16);

  static double stat(BuildContext context) =>
      _size(context, compactPhone: 24, phone: 28, tablet: 34, desktop: 48);

  static EdgeInsets screenPadding(BuildContext context) {
    final width = _width(context);
    if (width < 600) {
      return const EdgeInsets.all(16);
    }
    if (width < 1024) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(40);
  }
}
