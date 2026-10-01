import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/ner/drug_matcher.dart';

void main() {
  final names = File('assets/ner/drug_names.txt').readAsLinesSync();
  final matcher = DrugMatcher(names);

  test('loads the real bundled drug list (~10,500 names)', () {
    expect(matcher.names.length, greaterThan(10000));
  });

  final fixtures = jsonDecode(File('test/fixtures/ner_fixtures.json').readAsStringSync())
      as Map<String, dynamic>;
  final cases = fixtures['drug_cases'] as List<dynamic>;

  for (final c in cases) {
    final input = (c as Map<String, dynamic>)['input'] as String;
    final expected = c['expected'] as Map<String, dynamic>;

    test('match(${input.trim()}) matches the real Python DrugMatcher', () {
      final result = matcher.match(input);
      expect(result.canonical, expected['canonical']);
      expect(result.recognized, expected['recognized']);
      expect(result.corrected, expected['corrected']);
    });
  }
}
