import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'drug_matcher.dart';
import 'wordpiece_tokenizer.dart';

/// Loads `assets/ner/*` (already declared under `flutter.assets` in
/// pubspec.yaml -- these are real, checked-in files produced by
/// `distill/export_onnx.py`, not something this loader generates) into the
/// pieces [NerEngine] needs. Call once and reuse the result -- the tokenizer
/// and drug matcher are both immutable and hold no per-call state.
class NerAssetBundle {
  NerAssetBundle({required this.tokenizer, required this.drugMatcher, required this.idToLabel});

  final WordpieceTokenizer tokenizer;
  final DrugMatcher drugMatcher;
  final Map<int, String> idToLabel;

  static Future<NerAssetBundle> load() async {
    final vocabText = await rootBundle.loadString('assets/ner/vocab.txt');
    final vocabLines = const LineSplitter().convert(vocabText);
    final tokenizer = WordpieceTokenizer.fromVocabLines(vocabLines);

    final drugNamesText = await rootBundle.loadString('assets/ner/drug_names.txt');
    final drugNames = const LineSplitter().convert(drugNamesText).where((l) => l.isNotEmpty).toList();
    final drugMatcher = DrugMatcher(drugNames);

    final labelsJson = jsonDecode(await rootBundle.loadString('assets/ner/labels.json')) as Map<String, dynamic>;
    final bio = (labelsJson['bio'] as List<dynamic>).cast<String>();
    final idToLabel = {for (var i = 0; i < bio.length; i++) i: bio[i]};

    return NerAssetBundle(tokenizer: tokenizer, drugMatcher: drugMatcher, idToLabel: idToLabel);
  }
}
