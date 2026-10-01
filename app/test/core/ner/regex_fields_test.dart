import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/ner/regex_fields.dart';

void main() {
  final fixtures = jsonDecode(File('test/fixtures/ner_fixtures.json').readAsStringSync())
      as Map<String, dynamic>;
  final cases = fixtures['regex_cases'] as List<dynamic>;

  for (final c in cases) {
    final text = (c as Map<String, dynamic>)['text'] as String;
    final expected = c['expected'] as Map<String, dynamic>;

    test('extractRegexFields matches real _regex_fields: ${text.replaceAll('\n', ' / ')}', () {
      final result = extractRegexFields(text);

      final expectedFillDate = expected['fill_date'] as String?;
      if (expectedFillDate == null) {
        expect(result.fillDate, isNull);
      } else {
        final expectedDate = DateTime.parse(expectedFillDate);
        expect(result.fillDate, isNotNull);
        expect(result.fillDate!.year, expectedDate.year);
        expect(result.fillDate!.month, expectedDate.month);
        expect(result.fillDate!.day, expectedDate.day);
      }

      expect(result.daysSupply, expected['days_supply']);
    });
  }

  test('month-name format with only a 2-digit year does not match at all '
      '(the regex has no such alternative -- matches the real "Dispensed: Aug 1, 26" case)', () {
    final result = extractRegexFields('Dispensed: Aug 1, 26\nDays Supply:30');
    expect(result.fillDate, isNull);
    expect(result.daysSupply, 30);
  });

  test('an out-of-range month/day is silently skipped, not thrown or rolled over', () {
    final result = extractRegexFields('Date filled: 13/45/2026');
    expect(result.fillDate, isNull);
  });
}
