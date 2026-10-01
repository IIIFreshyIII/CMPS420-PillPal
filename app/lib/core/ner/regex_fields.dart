/// Port of `med7_pipeline.py`'s `_regex_fields()` -- dates and days-supply
/// are extracted with plain regex, never predicted by the model (spec rule).
///
/// The trickiest part: Python's `dateutil.parser.parse(s, dayfirst=False)`
/// has no Dart equivalent, so the 3 date shapes the regex can ever capture
/// are parsed explicitly here rather than reached for a general library:
///   1. `M/D/Y` (1-2 digit month, 1-2 digit day, 2-4 digit year) -- slash,
///      dash, or dot separators
///   2. `Y/M/D` (exactly 4-digit year first)
///   3. `Month D, YYYY` (month NAME, always a 4-digit year -- the regex has
///      no month-name alternative that accepts a 2-digit year at all)
/// A 2-digit year in shape 1 gets dateutil's exact century-pivot treatment
/// (verified against real `dateutil` output, e.g. `12/31/99` -> `1999-12-31`,
/// not `2099-12-31` -- see regex_fields_test.dart).
library;

final RegExp _dateRx = RegExp(
  r'(?:date\s*filled|fill(?:ed)?\s*date|filled|dispensed|date)\s*[:\-]?\s*'
  r'(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}|\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}'
  r'|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})',
  caseSensitive: false,
);

// Colon form ("Days supply: 30") is the common pharmacy-label layout -- try
// it first. The bare form allows at most one "-"/space so it can't reach
// across from "Qty: 60".
final RegExp _supplyRxColon = RegExp(r'day(?:s)?\s*supply\s*[:\-]?\s*(\d{1,3})', caseSensitive: false);
final RegExp _supplyRxBare = RegExp(r'(\d{1,3})[\- ]?day(?:s)?\s*supply', caseSensitive: false);

const _monthNames = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
  'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
  'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9, 'oct': 10,
  'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
};

class RegexFields {
  RegexFields({this.fillDate, this.daysSupply});
  final DateTime? fillDate;
  final int? daysSupply;
}

RegexFields extractRegexFields(String text) {
  DateTime? fillDate;
  final dateMatch = _dateRx.firstMatch(text);
  if (dateMatch != null) {
    fillDate = _parseDate(dateMatch.group(1)!);
  }

  int? daysSupply;
  final supplyMatch = _supplyRxColon.firstMatch(text) ?? _supplyRxBare.firstMatch(text);
  if (supplyMatch != null) {
    daysSupply = int.tryParse(supplyMatch.group(1)!);
  }

  return RegexFields(fillDate: fillDate, daysSupply: daysSupply);
}

DateTime? _parseDate(String s) {
  final monthName = RegExp(r'^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(s);
  if (monthName != null) {
    final month = _monthNames[monthName.group(1)!.toLowerCase()];
    if (month == null) return null;
    return _tryDate(int.parse(monthName.group(3)!), month, int.parse(monthName.group(2)!));
  }

  final numeric = RegExp(r'^(\d{1,4})[/\-.](\d{1,2})[/\-.](\d{1,4})$').firstMatch(s);
  if (numeric == null) return null;

  final g1 = numeric.group(1)!;
  final a = int.parse(g1);
  final b = int.parse(numeric.group(2)!);
  final c = int.parse(numeric.group(3)!);

  if (g1.length == 4) {
    // Y/M/D
    return _tryDate(a, b, c);
  }
  // M/D/Y -- dayfirst=False, so first number is the month.
  final year = c < 100 ? _pivotYear(c) : c;
  return _tryDate(year, a, b);
}

/// Replicates `dateutil.parser`'s `convertyear`: a 2-digit year is added to
/// the current century, then pulled back a century if that lands more than
/// 50 years from today (so `99` near 2026 resolves to 1999, not 2099).
int _pivotYear(int twoDigit) {
  final now = DateTime.now().year;
  final century = (now ~/ 100) * 100;
  var year = twoDigit + century;
  if ((year - now).abs() >= 50) {
    year += year < now ? 100 : -100;
  }
  return year;
}

/// Python's `datetime.date(y, m, d)` raises `ValueError` on an out-of-range
/// month/day and the reference just swallows that and moves on -- `DateTime`
/// in Dart silently rolls invalid values over instead, so validity is
/// checked explicitly here to match.
DateTime? _tryDate(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > daysInMonth) return null;
  return DateTime(year, month, day);
}
