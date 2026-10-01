/// A decoded entity span in the ORIGINAL text.
typedef Span = (int start, int end, String type);

/// Replicates HF's `TokenClassificationPipeline` with
/// `aggregation_strategy="first"`, which is a two-step process -- both steps
/// matter and are verified separately against real model output in
/// bio_decoder_test.dart:
///
/// 1. **Word aggregation**: WordPiece subtokens sharing one source word
///    (marked by a `##` prefix in the tokenizer's output) collapse into one
///    word. The WHOLE word takes only its FIRST subtoken's predicted label --
///    every other subtoken's prediction is discarded. This is easy to miss:
///    a strength suffix glued onto a drug name ("ATOMOXETINE25M") can be
///    predicted as its own STRENGTH span at the subtoken level and still
///    vanish entirely in the final output, because it's part of the same
///    word as the drug name.
/// 2. **Entity grouping**: consecutive words merge into one span only when
///    the later word's tag has an `I-` prefix (not `B-`) AND its entity type
///    matches the running span. A `B-` tag always starts a new span, even
///    when its type matches the previous one. Words separated by whitespace
///    (even a newline) still merge under this rule -- adjacency in the
///    source text doesn't matter, only the tag sequence does.
///
/// Special/padding tokens (offset start == end, e.g. `[CLS]`/`[SEP]`) are
/// always skipped, regardless of what label the model predicted for them.
List<Span> decodeBioSpans({
  required List<String> tokens,
  required List<(int, int)> offsets,
  required List<String> labels, // one BIO tag per token, e.g. "B-DRUG", "O"
}) {
  assert(tokens.length == offsets.length && tokens.length == labels.length);

  // Step 1: collapse subtokens into words, each word taking its first
  // subtoken's label and spanning from its first subtoken's start to its
  // last subtoken's end.
  final words = <({int start, int end, String label})>[];
  for (var i = 0; i < tokens.length; i++) {
    final (start, end) = offsets[i];
    if (start == end) continue; // special/padding token

    final isContinuation = tokens[i].startsWith('##');
    if (!isContinuation || words.isEmpty) {
      words.add((start: start, end: end, label: labels[i]));
    } else {
      final w = words.removeLast();
      words.add((start: w.start, end: end, label: w.label));
    }
  }

  // Step 2: merge consecutive words into entities per the B-/I- rule above.
  final spans = <Span>[];
  int? curStart;
  int? curEnd;
  String? curType;

  void flush() {
    if (curStart != null && curEnd != null && curType != null) {
      spans.add((curStart!, curEnd!, curType!));
    }
    curStart = curEnd = null;
    curType = null;
  }

  for (final w in words) {
    if (w.label == 'O') {
      flush();
      continue;
    }
    final prefix = w.label.substring(0, 1); // 'B' or 'I'
    final type = w.label.substring(2); // after "B-" / "I-"

    if (prefix == 'I' && curType == type) {
      curEnd = w.end;
    } else {
      flush();
      curStart = w.start;
      curEnd = w.end;
      curType = type;
    }
  }
  flush();

  return spans;
}
