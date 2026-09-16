import 'package:flutter/material.dart';

/// Single source of truth for turning a period label (as used in
/// RecordDateFilter.periods) into a concrete date range. Used by both
/// RecordDateFilter (when the user picks a chip) and DashboardPage
/// (to seed a real range for the default period before the first fetch).
class DatePeriodUtils {
  static DateTimeRange calculateDatesForPeriod(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case 'Today':
        return DateTimeRange(start: today, end: endOfToday);

      case 'Yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: yesterday,
          end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        );

      case 'Last 7 Days':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: endOfToday,
        );

      case 'This Week':
        final daysSinceMonday = today.weekday - 1;
        final startOfWeek = today.subtract(Duration(days: daysSinceMonday));
        return DateTimeRange(start: startOfWeek, end: endOfToday);

      case 'Last Week':
        final daysSinceMonday = today.weekday - 1;
        final startOfThisWeek = today.subtract(Duration(days: daysSinceMonday));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        final endOfLastWeek = startOfThisWeek.subtract(const Duration(seconds: 1));
        return DateTimeRange(start: startOfLastWeek, end: endOfLastWeek);

      case 'Last 30 Days':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: endOfToday,
        );

      case 'This Month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: endOfToday,
        );

      case 'Last Month':
        final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
        final startOfLastMonth = DateTime(lastDayOfLastMonth.year, lastDayOfLastMonth.month, 1);
        final endOfLastMonth = DateTime(
          lastDayOfLastMonth.year,
          lastDayOfLastMonth.month,
          lastDayOfLastMonth.day,
          23,
          59,
          59,
        );
        return DateTimeRange(start: startOfLastMonth, end: endOfLastMonth);

      case 'This Year':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: endOfToday);

      case 'All Time':
      default:
        // Wide-open bound. Swap for `null` start/end if your backend
        // is updated to treat missing dates as "no filter" explicitly
        // rather than relying on a magic 2000-2100 range.
        return DateTimeRange(start: DateTime(2000), end: DateTime(2100));
    }
  }
}