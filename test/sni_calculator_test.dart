import 'package:flutter_test/flutter_test.dart';
import 'package:mutco/core/sni_calculator.dart';

void main() {
  test('SNI defect weights follow the supplied class IDs', () {
    expect(SniCalculator.defectValue({5: 2, 7: 1, 17: 30, 18: 1}), 7.5);
  });

  test('grades stop at 225', () {
    expect(SniCalculator.grade(11), 'Mutu 1');
    expect(SniCalculator.grade(11.5), 'Mutu 2');
    expect(SniCalculator.grade(225), 'Mutu 6');
    expect(SniCalculator.grade(225.1), 'Di luar mutu SNI');
  });
}
