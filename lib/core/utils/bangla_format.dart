/// Formatting helpers so prices and counts read naturally to Bangla users.
abstract final class BanglaFormat {
  static const _digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  /// Converts ASCII digits to Bangla digits, leaving everything else as is.
  static String digits(Object value) => value.toString().replaceAllMapped(
    RegExp('[0-9]'),
    (m) => _digits[int.parse(m[0]!)],
  );

  /// Converts Bangla digits to ASCII, e.g. for a phone typed on a Bangla
  /// keyboard.
  static String asciiDigits(String value) => value.replaceAllMapped(
    RegExp('[০-৯]'),
    (m) => _digits.indexOf(m[0]!).toString(),
  );

  /// Whole-taka amount with South Asian grouping, e.g. 125000 → "৳১,২৫,০০০".
  static String taka(int amount) {
    final raw = amount.abs().toString();
    String grouped;
    if (raw.length <= 3) {
      grouped = raw;
    } else {
      final last3 = raw.substring(raw.length - 3);
      var rest = raw.substring(0, raw.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$last3';
    }
    return '${amount < 0 ? '-' : ''}৳${digits(grouped)}';
  }
}
