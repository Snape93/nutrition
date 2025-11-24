import 'package:flutter/services.dart';

/// Input formatter for decimal numbers (allows digits and one decimal point)
class DecimalInputFormatter extends TextInputFormatter {
  final int maxDecimalPlaces;

  DecimalInputFormatter({this.maxDecimalPlaces = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }

    // Only allow digits and one decimal point
    final regex = RegExp(r'^\d*\.?\d*$');
    if (!regex.hasMatch(text)) {
      return oldValue; // Reject invalid input
    }

    // Check decimal places
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2) {
        return oldValue; // Multiple decimal points
      }
      if (parts.length == 2 && parts[1].length > maxDecimalPlaces) {
        // Limit decimal places
        final limited = '${parts[0]}.${parts[1].substring(0, maxDecimalPlaces)}';
        return TextEditingValue(
          text: limited,
          selection: TextSelection.collapsed(offset: limited.length),
        );
      }
    }

    return newValue;
  }
}

/// Input formatter for integers only (no decimal point)
class IntegerInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }

    // Only allow digits
    final regex = RegExp(r'^\d+$');
    if (!regex.hasMatch(text)) {
      return oldValue; // Reject invalid input
    }

    return newValue;
  }
}

/// Input formatter for feet (1-8 range)
class FeetInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }

    // Only allow digits
    final regex = RegExp(r'^\d+$');
    if (!regex.hasMatch(text)) {
      return oldValue;
    }

    // Check range (1-8)
    final value = int.tryParse(text);
    if (value != null && value > 8) {
      return oldValue; // Reject values > 8
    }

    return newValue;
  }
}

/// Input formatter for inches (0-11.99 range with decimals)
class InchesInputFormatter extends TextInputFormatter {
  final int maxDecimalPlaces;

  InchesInputFormatter({this.maxDecimalPlaces = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }

    // Only allow digits and one decimal point
    final regex = RegExp(r'^\d*\.?\d*$');
    if (!regex.hasMatch(text)) {
      return oldValue;
    }

    // Check decimal places
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2) {
        return oldValue;
      }
      if (parts.length == 2 && parts[1].length > maxDecimalPlaces) {
        final limited = '${parts[0]}.${parts[1].substring(0, maxDecimalPlaces)}';
        return TextEditingValue(
          text: limited,
          selection: TextSelection.collapsed(offset: limited.length),
        );
      }
    }

    // Check range (0-11.99)
    final value = double.tryParse(text);
    if (value != null && value >= 12) {
      return oldValue; // Reject values >= 12
    }

    return newValue;
  }
}



















