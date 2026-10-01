/// Port of Python's `difflib.SequenceMatcher(None, a, b).ratio()` --
/// Ratcliff/Obershelp longest-matching-blocks, no autojunk (CPython's
/// autojunk only triggers when `len(b) >= 200`, never true for the short
/// drug-name strings this is used on in `drug_matcher.dart` -- verified
/// against real Python output for every case in this project, not assumed).
library;

double sequenceRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;

  // b2j: character -> sorted list of indices where it occurs in b.
  final b2j = <String, List<int>>{};
  for (var j = 0; j < b.length; j++) {
    b2j.putIfAbsent(b[j], () => []).add(j);
  }

  final blocks = _matchingBlocks(a, b, b2j);
  var matches = 0;
  for (final blk in blocks) {
    matches += blk.$3;
  }
  final total = a.length + b.length;
  return total == 0 ? 1.0 : (2.0 * matches) / total;
}

/// One matching block: (index into a, index into b, length).
typedef _Block = (int, int, int);

List<_Block> _matchingBlocks(String a, String b, Map<String, List<int>> b2j) {
  final queue = <(int, int, int, int)>[(0, a.length, 0, b.length)];
  final blocks = <_Block>[];

  while (queue.isNotEmpty) {
    final (alo, ahi, blo, bhi) = queue.removeLast();
    final match = _findLongestMatch(a, b, b2j, alo, ahi, blo, bhi);
    final (i, j, k) = match;
    if (k > 0) {
      blocks.add(match);
      if (alo < i && blo < j) queue.add((alo, i, blo, j));
      if (i + k < ahi && j + k < bhi) queue.add((i + k, ahi, j + k, bhi));
    }
  }

  blocks.sort((x, y) {
    if (x.$1 != y.$1) return x.$1.compareTo(y.$1);
    return x.$2.compareTo(y.$2);
  });
  return blocks;
}

_Block _findLongestMatch(
  String a,
  String b,
  Map<String, List<int>> b2j,
  int alo,
  int ahi,
  int blo,
  int bhi,
) {
  var besti = alo, bestj = blo, bestsize = 0;
  var j2len = <int, int>{};

  for (var i = alo; i < ahi; i++) {
    final newJ2Len = <int, int>{};
    final indices = b2j[a[i]];
    if (indices != null) {
      for (final j in indices) {
        if (j < blo) continue;
        if (j >= bhi) break;
        final k = (j2len[j - 1] ?? 0) + 1;
        newJ2Len[j] = k;
        if (k > bestsize) {
          besti = i - k + 1;
          bestj = j - k + 1;
          bestsize = k;
        }
      }
    }
    j2len = newJ2Len;
  }

  return (besti, bestj, bestsize);
}
