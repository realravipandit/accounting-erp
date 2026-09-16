import 'package:flutter/material.dart';
import '../../../models/common/record_filter.dart';
import '../../../utils/date_period_utils.dart'; // 👉 adjust path to match your project structure

class RecordDateFilter extends StatelessWidget {
  final RecordFilter filter;
  final ValueChanged<RecordFilter> onChanged;

  const RecordDateFilter({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  static const List<String> periods = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'This Week',
    'Last Week',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'This Year',
    'All Time',
  ];

  @override
  Widget build(BuildContext context) {
    final isCustomSelected = filter.period == null &&
        (filter.startDate != null || filter.endDate != null);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...periods.map(
          (period) => ChoiceChip(
            label: Text(period),
            selected: filter.period == period,
            onSelected: (_) {
              if (filter.period == period) {
                // Clear the filter if clicking the already selected chip
                onChanged(
                  filter.copyWith(
                    clearPeriod: true,
                    clearDates: true,
                    page: 1,
                  ),
                );
              } else {
                // Calculate the actual dates for the selected period
                // 👉 now delegated to the shared util so DashboardPage
                // and this widget can never disagree on what "Today" means
                final dates = DatePeriodUtils.calculateDatesForPeriod(period);

                onChanged(
                  filter.copyWith(
                    period: period,
                    startDate: dates.start,
                    endDate: dates.end,
                    page: 1,
                  ),
                );
              }
            },
          ),
        ),
        ChoiceChip(
          avatar: const Icon(
            Icons.date_range,
            size: 18,
          ),
          label: Text(
            isCustomSelected ? _getCustomDateLabel() : 'Custom',
          ),
          selected: isCustomSelected,
          onSelected: (_) => _selectCustomDateRange(context),
        ),
      ],
    );
  }

  String _getCustomDateLabel() {
    if (filter.startDate == null || filter.endDate == null) return 'Custom';

    final start = '${filter.startDate!.month}/${filter.startDate!.day}';
    final end = '${filter.endDate!.month}/${filter.endDate!.day}';

    return start == end ? start : '$start - $end';
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    DateTime start = filter.startDate ?? now;
    DateTime end = filter.endDate ?? now;

    if (start.isAfter(end)) {
      final temp = start;
      start = end;
      end = temp;
    }

    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100);

    if (start.isBefore(firstDate)) start = firstDate;
    if (end.isAfter(lastDate)) end = lastDate;

    final selected = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: start, end: end),
    );

    if (selected == null) return;

    onChanged(
      filter.copyWith(
        clearPeriod: true,
        startDate: selected.start,
        endDate: selected.end,
        page: 1,
      ),
    );
  }
}