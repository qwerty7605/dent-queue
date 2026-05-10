import 'package:flutter/material.dart';

class TermsAcceptanceFormField extends StatelessWidget {
  const TermsAcceptanceFormField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.checkboxKey,
    this.linkKey,
    this.prefixText = 'I agree to the ',
    this.suffixText = ' before creating this account.',
    this.textColor = Colors.white,
    this.linkColor = const Color(0xFF9CB5E8),
    this.errorColor = const Color(0xFFFFA0A0),
    this.activeColor = const Color(0xFF9CB5E8),
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;
  final Key? checkboxKey;
  final Key? linkKey;
  final String prefixText;
  final String suffixText;
  final Color textColor;
  final Color linkColor;
  final Color errorColor;
  final Color activeColor;

  static const String validationMessage =
      'You must accept the Terms and Conditions to continue.';

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: value,
      validator: (bool? accepted) {
        if (errorText != null) {
          return errorText;
        }
        return accepted == true ? null : validationMessage;
      },
      builder: (FormFieldState<bool> field) {
        final bool accepted = field.value ?? value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Checkbox(
                    key: checkboxKey,
                    value: accepted,
                    activeColor: activeColor,
                    side: BorderSide(color: textColor.withValues(alpha: 0.78)),
                    onChanged: (bool? checked) {
                      final bool nextValue = checked ?? false;
                      field.didChange(nextValue);
                      onChanged(nextValue);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          prefixText,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        InkWell(
                          key: linkKey,
                          onTap: () => showTermsAndConditionsDialog(context),
                          borderRadius: BorderRadius.circular(4),
                          child: Text(
                            'Terms and Conditions',
                            style: TextStyle(
                              color: linkColor,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                              decorationColor: linkColor,
                              height: 1.35,
                            ),
                          ),
                        ),
                        Text(
                          suffixText,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (field.hasError) ...<Widget>[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

Future<void> showTermsAndConditionsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'By creating an account, you agree to provide accurate information, '
            'keep your login credentials secure, use DentQueue only for lawful '
            'clinic-related purposes, and follow clinic policies for booking, '
            'queueing, and account access. The system may process account and '
            'appointment information needed to provide these services.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
