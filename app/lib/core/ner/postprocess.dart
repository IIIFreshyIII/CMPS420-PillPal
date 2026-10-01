import 'drug_matcher.dart';

/// One validated span, mirroring the Python reference's dict shape exactly
/// (`{start, end, type, text, canonical, recognized}`).
class RefinedSpan {
  RefinedSpan({
    required this.start,
    required this.end,
    required this.type,
    required this.text,
    required this.canonical,
    required this.recognized,
  });

  int start;
  int end;
  final String type;
  String text;
  String canonical;
  bool recognized;
}

/// Port of `distill/postprocess.py`. Validates/normalizes raw model spans
/// against controlled vocabularies -- `recognized: false` means "show it to
/// the user but flag: not in the vocabulary," never a silent invented value.
/// The one exception is a DRUG span that's clearly a manufacturer name or
/// non-word garble: those are dropped rather than shown at all, same as the
/// Python reference.
// generic-manufacturer tokens the model kept tagging as DRUG (from diagnose_real)
final Set<String> manufacturerStop = {
  'aurobindo', 'teva', 'mylan', 'sandoz', 'accord', 'camber', 'zydus', 'lupin',
  'amneal', 'apotex', 'torrent', 'granules', 'amber', 'tris', 'northstar',
  'ajanta', 'ascend', 'macleods', 'glenmark', 'alembic', 'rising', 'princeton',
  'reddy', 'reddys', 'laboratories', 'laboratory', 'labs', 'pharma',
  'pharmaceutical', 'pharmaceuticals', 'inc', 'llc', 'ltd', 'usa', 'co',
  'mfr', 'mfg', 'manufacturer', 'generic', 'brand', 'distributed',
};

final Map<String, String> _formCanon = {
  'tab': 'tablet', 'tabs': 'tablet', 'tablet': 'tablet', 'tablets': 'tablet',
  'cap': 'capsule', 'caps': 'capsule', 'capsule': 'capsule', 'capsules': 'capsule',
  'er tab': 'tablet', 'er tablet': 'tablet', 'dr tab': 'tablet', 'dr tablet': 'tablet',
  'sr tab': 'tablet', 'er cap': 'capsule', 'er capsule': 'capsule',
  'dr cap': 'capsule', 'sr cap': 'capsule',
  'cream': 'cream', 'ointment': 'ointment', 'oint': 'ointment', 'gel': 'gel',
  'lotion': 'lotion', 'foam': 'foam', 'solution': 'solution', 'soln': 'solution',
  'suspension': 'suspension', 'susp': 'suspension', 'syrup': 'syrup',
  'elixir': 'solution', 'inhaler': 'inhaler', 'hfa inhaler': 'inhaler',
  'nebulizer solution': 'solution', 'spray': 'spray', 'nasal spray': 'spray',
  'patch': 'patch', 'film': 'film', 'drops': 'drops', 'eye drops': 'drops',
  'suppository': 'suppository', 'shampoo': 'shampoo', 'powder': 'powder',
  'packet': 'packet', 'kit': 'kit', 'pen': 'pen', 'vial': 'vial',
};

/// The closed set of canonical FORM values, alphabetized -- the same set
/// `refine()` normalizes into, exposed for the Confirm screen's FORM
/// dropdown so it can never offer a value the validation layer wouldn't
/// itself produce.
final List<String> formOptions = _formCanon.values.toSet().toList()..sort();

final Map<String, String> _routeCanon = {
  'by mouth': 'by mouth', 'oral': 'by mouth', 'orally': 'by mouth', 'po': 'by mouth',
  'mouth': 'by mouth', 'swallow': 'by mouth',
  'topical': 'topically', 'topically': 'topically', 'externally': 'topically',
  'to the affected area': 'topically', 'affected area': 'topically',
  'affected areas': 'topically', 'to the affected skin': 'topically',
  'affected skin': 'topically', 'to affected areas': 'topically',
  'to the face': 'topically', 'to face': 'topically', 'to the scalp': 'topically',
  'in each eye': 'in each eye', 'into the affected eye': 'in each eye',
  'affected eye': 'in each eye', 'each eye': 'in each eye', 'both eyes': 'in each eye',
  'in each nostril': 'in each nostril', 'each nostril': 'in each nostril',
  'nasally': 'in each nostril',
  'by inhalation': 'by inhalation', 'inhalation': 'by inhalation',
  'inhaled': 'by inhalation', 'orally inhaled': 'by inhalation',
  'sublingually': 'sublingually', 'under the tongue': 'sublingually',
  'rectally': 'rectally', 'vaginally': 'vaginally',
  'subcutaneously': 'subcutaneously', 'subcutaneous': 'subcutaneously',
};

final RegExp _wordNum = RegExp(r'\b(one|two|three|four|half|thin|small)\b');
final RegExp _nonWord = RegExp(r'[^a-z]');

String normSpace(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Exact match, else the longest table key that appears at a word boundary
/// in [n] (catches glued/truncated OCR: "capsule3time" -> capsule). Ties in
/// length break the same way Python's `max()` on `(len, value)` tuples does:
/// by comparing the value strings.
String? _lookup(String n, Map<String, String> table) {
  final exact = table[n];
  if (exact != null) return exact;

  String? bestValue;
  var bestLen = -1;
  for (final entry in table.entries) {
    final k = entry.key;
    if (!RegExp(r'\b' + RegExp.escape(k)).hasMatch(n)) continue;
    final len = k.length;
    if (len > bestLen || (len == bestLen && bestValue != null && entry.value.compareTo(bestValue) > 0)) {
      bestLen = len;
      bestValue = entry.value;
    }
  }
  return bestValue;
}

/// If [canonical] (or its first word) sits literally inside [frag], shrink
/// the span to just that -- fixes the model's "grabbed the glued neighbour"
/// errors ("ATOMOXETINE25M" span -> "ATOMOXETINE").
(int, int)? _tighten(String frag, int start, String canonical) {
  final low = frag.toLowerCase();
  final needles = [
    canonical,
    canonical.split(' ').first,
    canonical.split('/').first.trim(),
  ];
  for (final needle in needles) {
    if (needle.length >= 4 && low.contains(needle)) {
      final p = low.indexOf(needle);
      return (start + p, start + p + needle.length);
    }
  }
  return null;
}

bool _isManufacturerOrJunk(String n) {
  final toks = n.split(RegExp(r'[\s:/\\|.,]+')).where((t) => t.isNotEmpty).toList();
  if (toks.isEmpty) return true;
  if (toks.every((t) => manufacturerStop.contains(t))) return true;
  if (toks.any((t) => manufacturerStop.contains(t)) && toks.length <= 3) return true;
  if (n.contains('generic for') || n.contains('mfr') || n.contains('mfg')) return true;
  final letters = n.replaceAll(_nonWord, '');
  return letters.length < 3;
}

/// `spans`: raw `(start, end, type)` triples from [decodeBioSpans].
List<RefinedSpan> refine(List<(int, int, String)> spans, String text, DrugMatcher matcher) {
  final out = <RefinedSpan>[];

  for (final (s, e, typ) in spans) {
    final frag = text.substring(s, e);
    final n = normSpace(frag);
    final rec = RefinedSpan(start: s, end: e, type: typ, text: frag, canonical: frag, recognized: true);

    switch (typ) {
      case 'DRUG':
        final m = matcher.match(frag);
        rec.canonical = m.canonical;
        rec.recognized = m.recognized;
        if (!m.recognized && _isManufacturerOrJunk(n)) {
          continue; // drop: manufacturer / garble
        }
        if (m.recognized) {
          final t = _tighten(frag, s, m.canonical);
          if (t != null) {
            rec.start = t.$1;
            rec.end = t.$2;
            rec.text = text.substring(t.$1, t.$2);
          }
        }
      case 'FORM':
        final c = _lookup(n, _formCanon);
        rec.canonical = c ?? frag;
        rec.recognized = c != null;
        if (c != null) {
          final t = _tighten(frag, s, c);
          if (t != null) {
            rec.start = t.$1;
            rec.end = t.$2;
            rec.text = text.substring(t.$1, t.$2);
          }
        }
      case 'ROUTE':
        final c = _lookup(n, _routeCanon);
        rec.canonical = c ?? frag;
        rec.recognized = c != null;
      case 'STRENGTH':
        rec.recognized = RegExp(r'\d').hasMatch(n);
      case 'DOSAGE':
        rec.recognized = RegExp(r'\d').hasMatch(n) || _wordNum.hasMatch(n);
      // FREQUENCY, DURATION: passthrough (recognized stays true).
    }

    out.add(rec);
  }

  return out;
}

/// The confirm screen shows one value per field -> take the first span of
/// each type (matches `evaluate.py` / the model pipeline order).
Map<String, RefinedSpan> firstPerType(List<RefinedSpan> refined) {
  final picked = <String, RefinedSpan>{};
  for (final r in refined) {
    picked.putIfAbsent(r.type, () => r);
  }
  return picked;
}
