import 'package:intl/intl.dart';

class DateHelper {
  static final _dbDate = DateFormat('yyyy-MM-dd');
  static final _pretty = DateFormat('MMM d, yyyy');

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String toDb(DateTime d) => _dbDate.format(d);
  static String pretty(DateTime d) => _pretty.format(d);

  static DateTime? parse(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

  /// Whole days from [a] to [b] (UTC math avoids daylight-saving errors).
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// Same month/day in [year]; Feb 29 falls back to Feb 28 in non-leap years.
  static DateTime inYear(DateTime original, int year) {
    if (original.month == 2 && original.day == 29 && !_isLeap(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, original.month, original.day);
  }

  /// Next occurrence (today counts) of an annually recurring date.
  static DateTime nextOccurrence(DateTime original, DateTime today) {
    final t = dateOnly(today);
    var c = inYear(original, t.year);
    if (c.isBefore(t)) c = inYear(original, t.year + 1);
    return c;
  }
}
