import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/ner/drug_matcher.dart';
import 'package:pillpal/core/ner/postprocess.dart';

void main() {
  final names = File('assets/ner/drug_names.txt').readAsLinesSync();
  final matcher = DrugMatcher(names);

  final fixtures = jsonDecode(File('test/fixtures/ner_fixtures.json').readAsStringSync())
      as Map<String, dynamic>;
  final cases = fixtures['refine_cases'] as List<dynamic>;

  void expectMatchesDict(RefinedSpan actual, Map<String, dynamic> expected) {
    expect(actual.start, expected['start']);
    expect(actual.end, expected['end']);
    expect(actual.type, expected['type']);
    expect(actual.text, expected['text']);
    expect(actual.canonical, expected['canonical']);
    expect(actual.recognized, expected['recognized']);
  }

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i] as Map<String, dynamic>;
    final text = c['text'] as String;
    final rawSpans = (c['raw_spans'] as List<dynamic>)
        .map((s) => ((s as List<dynamic>)[0] as int, s[1] as int, s[2] as String))
        .toList();
    final expectedRefined = (c['expected_refined'] as List<dynamic>).cast<Map<String, dynamic>>();
    final expectedFirstPerType =
        (c['expected_first_per_type'] as Map<String, dynamic>).cast<String, dynamic>();

    final label = text.isEmpty ? 'empty' : text.substring(0, text.length.clamp(0, 30));

    test('refine() case $i matches real postprocess.py output: $label', () {
      final refined = refine(rawSpans, text, matcher);
      expect(refined.length, expectedRefined.length,
          reason: 'span count must match (drops must happen at the same points)');
      for (var j = 0; j < refined.length; j++) {
        expectMatchesDict(refined[j], expectedRefined[j]);
      }
    });

    test('firstPerType() case $i matches real output: $label', () {
      final refined = refine(rawSpans, text, matcher);
      final picked = firstPerType(refined);
      expect(picked.keys.toSet(), expectedFirstPerType.keys.toSet());
      for (final type in expectedFirstPerType.keys) {
        expectMatchesDict(picked[type]!, expectedFirstPerType[type] as Map<String, dynamic>);
      }
    });
  }

  test('a manufacturer-only DRUG span is dropped, not flagged', () {
    final refined = refine([(0, 9, 'DRUG')], 'aurobindo', matcher);
    expect(refined, isEmpty);
  });

  test('STRENGTH with no digit is flagged unrecognized, not dropped', () {
    final refined = refine([(0, 4, 'STRENGTH')], 'none', matcher);
    expect(refined, hasLength(1));
    expect(refined.first.recognized, isFalse);
    expect(refined.first.canonical, 'none'); // passthrough, never invented
  });
}
