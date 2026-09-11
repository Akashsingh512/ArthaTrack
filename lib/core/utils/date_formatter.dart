import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dayMonthYear = DateFormat('dd MMM yyyy');
  static final DateFormat _dayMonthYearTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _shortDate = DateFormat('dd MMM');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  static String format(DateTime date) => _dayMonthYear.format(date);
  static String formatWithTime(DateTime date) => _dayMonthYearTime.format(date);
  static String formatShort(DateTime date) => _shortDate.format(date);
  static String formatMonthYear(DateTime date) => _monthYear.format(date);
  static String toIso(DateTime date) => _isoFormat.format(date);

  static DateTime parse(String isoString) {
    try {
      return DateTime.parse(isoString);
    } catch (_) {
      return DateTime.now();
    }
  }

  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min${mins > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hr${hours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return days == 1 ? 'Yesterday' : '$days days ago';
    } else {
      return format(dateTime);
    }
  }
}
