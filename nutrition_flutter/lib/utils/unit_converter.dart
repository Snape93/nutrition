/// Utility class for unit conversions between metric and imperial systems
class UnitConverter {
  // Conversion constants
  static const double cmToInch = 0.393701;
  static const double inchToCm = 2.54;
  static const double footToCm = 30.48;
  static const double kgToLb = 2.20462;
  static const double lbToKg = 0.453592;

  /// Convert centimeters to feet and inches
  /// Returns a map with 'feet' (int) and 'inches' (double)
  static Map<String, double> cmToFeetInches(double cm) {
    final totalInches = cm * cmToInch;
    final feet = (totalInches / 12).floor();
    final inches = totalInches % 12;
    return {'feet': feet.toDouble(), 'inches': inches};
  }

  /// Convert feet and inches to centimeters
  static double feetInchesToCm(int feet, double inches) {
    final totalInches = (feet * 12) + inches;
    return totalInches * inchToCm;
  }

  /// Convert kilograms to pounds
  static double kgToLbs(double kg) {
    return kg * kgToLb;
  }

  /// Convert pounds to kilograms
  static double lbsToKg(double lbs) {
    return lbs * lbToKg;
  }

  /// Format feet and inches as a string (e.g., "5'10\"")
  static String formatFeetInches(int feet, double inches) {
    final inchesInt = inches.floor();
    final inchesDecimal = inches - inchesInt;
    if (inchesDecimal > 0.01) {
      return "$feet'${inches.toStringAsFixed(1)}\"";
    }
    return "$feet'$inchesInt\"";
  }

  /// Parse feet and inches from string (handles "5'10\"", "5 10", "5.10")
  static Map<String, double>? parseFeetInches(String input) {
    try {
      // Try format "5'10\""
      if (input.contains("'")) {
        final parts = input.split("'");
        final feet = int.parse(parts[0].trim());
        final inchesStr = parts[1].replaceAll('"', '').trim();
        final inches = double.parse(inchesStr);
        return {'feet': feet.toDouble(), 'inches': inches};
      }
      // Try format "5 10" or "5.10"
      final parts = input.split(RegExp(r'[\s.]+'));
      if (parts.length == 2) {
        final feet = int.parse(parts[0].trim());
        final inches = double.parse(parts[1].trim());
        return {'feet': feet.toDouble(), 'inches': inches};
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Round to specified decimal places
  static double roundToDecimals(double value, int decimals) {
    if (decimals < 0) {
      throw ArgumentError('Decimals must be non-negative');
    }
    if (decimals == 0) {
      return value.roundToDouble();
    }
    // Calculate 10^decimals (e.g., 10^2 = 100 for 2 decimal places)
    double factor = 1.0;
    for (int i = 0; i < decimals; i++) {
      factor *= 10.0;
    }
    return (value * factor).round() / factor;
  }
}



















