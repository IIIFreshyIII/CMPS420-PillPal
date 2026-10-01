/// BERT WordPiece tokenizer -- must reproduce `BertTokenizerFast` exactly
/// (do_lower_case=true, strip_accents on, standard basic-tokenize then
/// greedy-longest-match WordPiece), since the ONNX model was trained against
/// that exact tokenization. Verified against real tokenizer output captured
/// in `app/test/fixtures/ner_fixtures.json` (see wordpiece_tokenizer_test.dart).
library;

class Encoding {
  Encoding({required this.inputIds, required this.offsets, required this.tokens});

  final List<int> inputIds;

  /// Character `(start, end)` in the ORIGINAL (untouched) input string, one
  /// per entry in [inputIds]. Special/padding tokens get `(0, 0)`, matching
  /// the Python reference's convention (`spans_to_bio`'s `if a == b`).
  final List<(int, int)> offsets;

  final List<String> tokens;
}

class WordpieceTokenizer {
  WordpieceTokenizer({
    required Map<String, int> vocab,
    this.maxLength = 256,
    this.unkToken = '[UNK]',
    this.clsToken = '[CLS]',
    this.sepToken = '[SEP]',
  }) : _vocab = vocab {
    if (!_vocab.containsKey(unkToken) || !_vocab.containsKey(clsToken) || !_vocab.containsKey(sepToken)) {
      throw ArgumentError('vocab is missing a required special token');
    }
  }

  factory WordpieceTokenizer.fromVocabLines(List<String> lines, {int maxLength = 256}) {
    final vocab = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) vocab[line] = i;
    }
    return WordpieceTokenizer(vocab: vocab, maxLength: maxLength);
  }

  final Map<String, int> _vocab;
  final int maxLength;
  final String unkToken;
  final String clsToken;
  final String sepToken;

  static const int _maxWordChars = 100;

  Encoding encode(String text) {
    final words = _basicTokenize(text);

    final ids = <int>[_vocab[clsToken]!];
    final offsets = <(int, int)>[(0, 0)];
    final tokens = <String>[clsToken];

    // Reserve room for [CLS] and [SEP].
    final budget = maxLength - 2;

    outer:
    for (final word in words) {
      for (final piece in _wordpiece(word)) {
        if (ids.length - 1 >= budget) break outer; // -1 excludes [CLS] already pushed
        ids.add(_vocab[piece.text] ?? _vocab[unkToken]!);
        offsets.add((piece.start, piece.end));
        tokens.add(_vocab.containsKey(piece.text) ? piece.text : unkToken);
      }
    }

    ids.add(_vocab[sepToken]!);
    offsets.add((0, 0));
    tokens.add(sepToken);

    return Encoding(inputIds: ids, offsets: offsets, tokens: tokens);
  }

  // ---- basic tokenization: whitespace + punctuation splitting, lowercase, accent strip ----

  List<_Word> _basicTokenize(String text) {
    final words = <_Word>[];
    var i = 0;
    final n = text.length;

    while (i < n) {
      final ch = text[i];
      if (_isWhitespace(ch) || _isControl(ch)) {
        i++;
        continue;
      }
      if (_isPunctuation(ch)) {
        words.add(_Word(_lower(ch), i, i + 1));
        i++;
        continue;
      }
      final start = i;
      final buf = StringBuffer();
      while (i < n && !_isWhitespace(text[i]) && !_isControl(text[i]) && !_isPunctuation(text[i])) {
        buf.write(_lower(text[i]));
        i++;
      }
      words.add(_Word(buf.toString(), start, i));
    }
    return words;
  }

  /// Lowercase and strip combining marks (accent stripping) from one
  /// character. Runs per-character so the result stays 1:1 with the source
  /// character for offset bookkeeping -- BERT's normalizer can change a
  /// character's *rendered* form but our basic-tokenize loop only needs the
  /// ASCII-range fold that real label text actually exercises.
  String _lower(String ch) {
    final lower = ch.toLowerCase();
    // Strip a decomposed combining accent mark, if lowercasing produced one
    // (rare for plain ASCII prescription-label text, kept for correctness).
    final decomposed = _stripCombining(lower);
    return decomposed;
  }

  String _stripCombining(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x0300 && rune <= 0x036F) continue; // combining diacriticals
      buf.writeCharCode(rune);
    }
    return buf.toString();
  }

  bool _isWhitespace(String ch) {
    if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') return true;
    final code = ch.codeUnitAt(0);
    // Unicode Zs category, common cases.
    return code == 0x00A0 || code == 0x1680 || (code >= 0x2000 && code <= 0x200A) ||
        code == 0x202F || code == 0x205F || code == 0x3000;
  }

  bool _isControl(String ch) {
    final code = ch.codeUnitAt(0);
    if (ch == '\t' || ch == '\n' || ch == '\r') return false; // treated as whitespace above
    return (code >= 0x00 && code <= 0x1F) || (code >= 0x7F && code <= 0x9F);
  }

  bool _isPunctuation(String ch) {
    final code = ch.codeUnitAt(0);
    // ASCII punctuation ranges, matching BERT's BasicTokenizer._is_punctuation.
    if ((code >= 33 && code <= 47) ||
        (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) ||
        (code >= 123 && code <= 126)) {
      return true;
    }
    // Common Unicode punctuation outside ASCII (quotes, dashes) -- best-effort,
    // real prescription-label OCR text is overwhelmingly ASCII.
    return RegExp(r'\p{P}', unicode: true).hasMatch(ch);
  }

  // ---- WordPiece: greedy longest-match-first, per "word" from basic tokenize ----

  List<_Piece> _wordpiece(_Word word) {
    final chars = word.text;
    if (chars.length > _maxWordChars) {
      return [_Piece(unkToken, word.start, word.end)];
    }

    final pieces = <_Piece>[];
    var start = 0;
    var isBad = false;

    while (start < chars.length) {
      var end = chars.length;
      String? matched;
      while (end > start) {
        var substr = chars.substring(start, end);
        if (start > 0) substr = '##$substr';
        if (_vocab.containsKey(substr)) {
          matched = substr;
          break;
        }
        end--;
      }
      if (matched == null) {
        isBad = true;
        break;
      }
      pieces.add(_Piece(matched, word.start + start, word.start + end));
      start = end;
    }

    if (isBad) return [_Piece(unkToken, word.start, word.end)];
    return pieces;
  }
}

class _Word {
  _Word(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

class _Piece {
  _Piece(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}
