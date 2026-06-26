import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/services/blood_compatibility.dart';

void main() {
  group('BloodCompatibility', () {
    test('O- is the universal donor', () {
      for (final r in BloodCompatibility.allGroups) {
        expect(BloodCompatibility.canDonate(donor: 'O-', recipient: r), isTrue,
            reason: 'O- should donate to $r');
      }
    });

    test('AB+ is the universal recipient', () {
      for (final d in BloodCompatibility.allGroups) {
        expect(BloodCompatibility.canDonate(donor: d, recipient: 'AB+'), isTrue,
            reason: '$d should donate to AB+');
      }
    });

    test('A+ can donate only to A+ and AB+', () {
      expect(BloodCompatibility.canDonateTo('A+'), {'A+', 'AB+'});
    });

    test('incompatible pairs are rejected', () {
      expect(BloodCompatibility.canDonate(donor: 'A+', recipient: 'O+'),
          isFalse);
      expect(BloodCompatibility.canDonate(donor: 'B-', recipient: 'A-'),
          isFalse);
      expect(BloodCompatibility.canDonate(donor: 'AB+', recipient: 'O-'),
          isFalse);
    });

    test('O+ recipient accepts only O- and O+', () {
      expect(BloodCompatibility.canDonate(donor: 'O-', recipient: 'O+'), isTrue);
      expect(BloodCompatibility.canDonate(donor: 'O+', recipient: 'O+'), isTrue);
      expect(BloodCompatibility.canDonate(donor: 'A+', recipient: 'O+'),
          isFalse);
    });

    test('normalises case and whitespace', () {
      expect(BloodCompatibility.canDonate(donor: ' o- ', recipient: 'a+'),
          isTrue);
      expect(BloodCompatibility.isValidGroup('ab+'), isTrue);
      expect(BloodCompatibility.isValidGroup('XY'), isFalse);
    });
  });
}
