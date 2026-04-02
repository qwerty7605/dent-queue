import 'package:flutter/services.dart';

class AppFormValidators {
  AppFormValidators._();

  static const int nameMaxLength = 100;
  static const int usernameMaxLength = 50;
  static const int emailMaxLength = 255;
  static const int addressMaxLength = 255;
  static const int passwordMinLength = 8;
  static const int contactNumberLength = 11;

  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9._-]+$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _contactNumberPattern = RegExp(r'^09\d{9}$');

  static List<TextInputFormatter> nameInputFormatters([int maxLength = nameMaxLength]) {
    return <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)];
  }

  static List<TextInputFormatter> usernameInputFormatters() {
    return <TextInputFormatter>[
      LengthLimitingTextInputFormatter(usernameMaxLength),
      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
    ];
  }

  static List<TextInputFormatter> contactNumberInputFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(contactNumberLength),
    ];
  }

  static List<TextInputFormatter> maxLengthInputFormatters(int maxLength) {
    return <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)];
  }

  static String? requiredName(String? value, {String fieldLabel = 'This field'}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$fieldLabel is required';
    }
    if (trimmed.length > nameMaxLength) {
      return '$fieldLabel must be at most $nameMaxLength characters';
    }
    return null;
  }

  static String? optionalName(String? value, {String fieldLabel = 'This field'}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > nameMaxLength) {
      return '$fieldLabel must be at most $nameMaxLength characters';
    }
    return null;
  }

  static String? username(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Username is required';
    }
    if (trimmed.length > usernameMaxLength) {
      return 'Username must be at most $usernameMaxLength characters';
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      return 'Use letters, numbers, dots, hyphens, or underscores only';
    }
    return null;
  }

  static String? email(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required';
    }
    if (trimmed.length > emailMaxLength) {
      return 'Email must be at most $emailMaxLength characters';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    final String text = value ?? '';
    if (text.isEmpty) {
      return 'Password is required';
    }
    if (text.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final String text = value ?? '';
    if (text.isEmpty) {
      return 'Please confirm your password';
    }
    if (text != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? contactNumber(String? value, {bool required = true}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Contact number is required' : null;
    }
    if (!_contactNumberPattern.hasMatch(trimmed)) {
      return 'Contact number must be a valid 11-digit mobile number starting with 09.';
    }
    return null;
  }

  static String? address(String? value, {String fieldLabel = 'Address', bool required = false}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? '$fieldLabel is required' : null;
    }
    if (trimmed.length > addressMaxLength) {
      return '$fieldLabel must be at most $addressMaxLength characters';
    }
    return null;
  }

  static String? gender(String? value, {bool required = false}) {
    final String trimmed = value?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Gender is required' : null;
    }
    if (!const <String>{'male', 'female', 'other'}.contains(trimmed)) {
      return 'Gender must be male, female, or other';
    }
    return null;
  }
}
