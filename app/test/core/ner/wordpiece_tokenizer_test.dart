import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/ner/wordpiece_tokenizer.dart';

/// Every case here is real tokenizer output captured from the actual
/// HF BertTokenizerFast against the shipped vocab -- see
/// distill/_dart_port_fixtures.py. Not hand-written expected values.
void main() {
  final vocabLines = File('assets/ner/vocab.txt').readAsLinesSync();
  final tokenizer = WordpieceTokenizer.fromVocabLines(vocabLines);

  final fixtures = jsonDecode(File('test/fixtures/ner_fixtures.json').readAsStringSync())
      as Map<String, dynamic>;
  final cases = fixtures['tokenizer_cases'] as List<dynamic>;

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i] as Map<String, dynamic>;
    final text = c['text'] as String;
    final label = text.isEmpty
        ? 'empty string'
        : (text.trim().isEmpty ? 'whitespace-only' : text.substring(0, text.length.clamp(0, 30)));

    test('case $i: $label', () {
      final enc = tokenizer.encode(text);

      final expectedIds = (c['input_ids'] as List<dynamic>).cast<int>();
      final expectedOffsets = (c['offset_mapping'] as List<dynamic>)
          .map((o) => ((o as List<dynamic>)[0] as int, o[1] as int))
          .toList();
      final expectedTokens = (c['tokens'] as List<dynamic>).cast<String>();

      expect(enc.tokens, expectedTokens, reason: 'token strings must match exactly');
      expect(enc.inputIds, expectedIds, reason: 'vocab ids must match exactly');
      expect(enc.offsets, expectedOffsets, reason: 'char offsets must match exactly');
    });
  }

  test('truncates to model_max_length (256) including [CLS]/[SEP]', () {
    final longText = List.filled(400, 'word').join(' ');
    final enc = tokenizer.encode(longText);
    expect(enc.inputIds.length, lessThanOrEqualTo(256));
    expect(enc.tokens.first, '[CLS]');
    expect(enc.tokens.last, '[SEP]');
  });
}
