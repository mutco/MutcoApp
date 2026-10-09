import 'coffee_classes.dart';

class SniCalculator {
  static double defectValue(Map<int, int> counts) => counts.entries.fold(
    0.0, (sum, entry) => sum + defectWeights[entry.key] * entry.value,
  );

  static String grade(double value) {
    if (value <= 11) return 'Mutu 1';
    if (value <= 25) return 'Mutu 2';
    if (value <= 44) return 'Mutu 3';
    if (value <= 60) return 'Mutu 4a';
    if (value <= 80) return 'Mutu 4b';
    if (value <= 150) return 'Mutu 5';
    if (value <= 225) return 'Mutu 6';
    return 'Di luar mutu SNI';
  }
}
