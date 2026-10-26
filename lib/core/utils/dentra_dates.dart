/// Date and time display helpers. Kept local because the app does not
/// depend on `intl`; all output is English, matching the rest of the UI.
abstract class DentraDates {
  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  static String monthShort(int month) => monthNames[month - 1].substring(0, 3);
  static String weekdayShort(int weekday) =>
      weekdayNames[weekday - 1].substring(0, 3);

  /// "Jan 15, 1990".
  static String medium(DateTime d) => '${monthShort(d.month)} ${d.day}, ${d.year}';

  /// "January 15, 1990".
  static String long(DateTime d) =>
      '${monthNames[d.month - 1]} ${d.day}, ${d.year}';

  /// "Monday, January 15, 1990".
  static String full(DateTime d) => '${weekdayNames[d.weekday - 1]}, ${long(d)}';

  /// "September 2026".
  static String monthYear(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';

  /// "3:42 PM".
  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "Just now", "5 minutes ago", "3 hours ago", "Yesterday, 3:42 PM",
  /// "Monday", then "Jan 15" (this year) or "Jan 15, 1990".
  static String relative(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(d);
    String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return plural(diff.inMinutes, 'minute');
    if (sameDay(d, ref)) return plural(diff.inHours, 'hour');
    final days = dateOnly(ref).difference(dateOnly(d)).inDays;
    if (days == 1) return 'Yesterday, ${time(d)}';
    if (days < 7) return weekdayNames[d.weekday - 1];
    if (d.year == ref.year) return '${monthShort(d.month)} ${d.day}';
    return medium(d);
  }

  /// "2026-10-21", e.g. for API date parameters.
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

  /// Monday of the week containing [d].
  static DateTime weekStart(DateTime d) =>
      dateOnly(d).subtract(Duration(days: d.weekday - 1));

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// Adds months, clamped to the first of the month (avoids Jan 31 + 1).
  static DateTime addMonths(DateTime month, int delta) =>
      DateTime(month.year, month.month + delta);
}
