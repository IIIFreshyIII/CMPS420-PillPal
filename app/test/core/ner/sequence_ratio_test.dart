import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/ner/sequence_ratio.dart';

/// Expected values are real output of Python's `difflib.SequenceMatcher`,
/// captured directly (`python3 -c "from difflib import SequenceMatcher; ..."`),
/// not hand-derived.
void main() {
  final cases = <(String, String, double)>[
    ('atorvastati', 'atorvastatin', 0.9565217391304348),
    ('atomoxetine', 'atomoxetine', 1.0),
    ('aurobindo', 'atomoxetine', 0.4),
    ('', '', 1.0),
    ('a', '', 0.0),
    ('metformin', 'metforminx', 0.9473684210526315),
    ('lisinopril', 'lisinoprol', 0.9),
    ('hydrochlorothiazide', 'hydrochlorthiazide', 0.972972972972973),
  ];

  for (final (a, b, expected) in cases) {
    test('ratio($a, $b) == $expected', () {
      expect(sequenceRatio(a, b), closeTo(expected, 1e-9));
    });
  }
}
