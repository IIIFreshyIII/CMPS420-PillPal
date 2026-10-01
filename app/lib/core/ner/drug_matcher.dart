import 'sequence_ratio.dart';

class DrugMatchResult {
  DrugMatchResult({required this.canonical, required this.recognized, required this.corrected});
  final String canonical;
  final bool recognized;
  final bool corrected;
}

/// Port of `distill/drug_vocab.py`'s `DrugMatcher` -- matches a (possibly
/// OCR-mangled) span against the ~10,500-name RxNorm drug list bundled at
/// `assets/ner/drug_names.txt`. Exact match first, then a fuzzy shortlist
/// (bucketed by first char + rough length) scored with [sequenceRatio],
/// accepted at the same `>= 0.88` threshold as the Python reference.
class DrugMatcher {
  DrugMatcher(List<String> names) : names = names.where((n) => n.isNotEmpty).toList() {
    _exact = this.names.toSet();
    for (final n in this.names) {
      final bucket = (n[0], n.length ~/ 3);
      _buckets.putIfAbsent(bucket, () => []).add(n);
    }
  }

  final List<String> names;
  late final Set<String> _exact;
  final Map<(String, int), List<String>> _buckets = {};

  static final RegExp _strengthTail = RegExp(r'(?<=[a-z])\s*\d[\w.,%/\s-]*$', caseSensitive: false);
  static final RegExp _nonWordEdgesStart = RegExp(r'^[^0-9a-z]+');
  static final RegExp _nonWordEdgesEnd = RegExp(r'[^0-9a-z]+$');
  static final RegExp _split = RegExp(r'[\s:/\\|]+');

  static String _norm(String s) {
    var out = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    out = out.replaceAll(_strengthTail, ''); // "atomoxetine25m" -> "atomoxetine"
    out = out.replaceAll(_nonWordEdgesStart, '').replaceAll(_nonWordEdgesEnd, '');
    return out.trim();
  }

  /// Candidate strings to look up, roughly best-first: whole span, then each
  /// token (real spans can be "delroy\natomoxetine25m", "atomoxetine hcl",
  /// "mfr:aurobindo").
  List<String> _forms(String spanText) {
    final whole = _norm(spanText);
    final seen = <String>{if (whole.isNotEmpty) whole};
    final out = <String>[whole];
    for (final tok in spanText.trim().split(_split)) {
      final t = _norm(tok);
      if (t.isNotEmpty && !seen.contains(t)) {
        seen.add(t);
        out.add(t);
      }
    }
    return out;
  }

  DrugMatchResult match(String spanText) {
    final forms = _forms(spanText).where((f) => f.length >= 3).toList();
    if (forms.isEmpty) {
      return DrugMatchResult(canonical: spanText.trim().toLowerCase(), recognized: false, corrected: false);
    }

    for (final f in forms) {
      if (_exact.contains(f)) {
        return DrugMatchResult(canonical: f, recognized: true, corrected: f != forms.first);
      }
    }

    for (final f in forms) {
      if (f.length < 5) continue;
      String? best;
      var bestScore = 0.0;
      for (final cand in _candidates(f)) {
        final score = sequenceRatio(f, cand);
        if (score > bestScore) {
          best = cand;
          bestScore = score;
        }
      }
      if (best != null && bestScore >= 0.88) {
        return DrugMatchResult(canonical: best, recognized: true, corrected: true);
      }
    }

    return DrugMatchResult(canonical: forms.first, recognized: false, corrected: false);
  }

  Iterable<String> _candidates(String n) {
    final bucket = n.length ~/ 3;
    return [-1, 0, 1].expand((dl) => _buckets[(n[0], bucket + dl)] ?? const []);
  }
}
