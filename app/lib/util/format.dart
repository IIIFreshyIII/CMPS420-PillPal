/// ISO-ish date, no time. Kept trivial on purpose — swap for `intl` if the app
/// ever needs locale-aware formatting.
String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
