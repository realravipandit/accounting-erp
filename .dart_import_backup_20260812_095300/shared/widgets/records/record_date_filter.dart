import 'package:flutter/material.dart';
import '../../../models/common/record_filter.dart';

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
    'Last 30 Days',
    'This Month',
    'Last Month',
  ];

  @override
  Widget build(BuildContext context) {
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
                onChanged(
                  filter.copyWith(
                    clearPeriod: true,
                    clearDates: true,
                    page: 1,
                  ),
                );
              } else {
                onChanged(
                  filter.copyWith(
                    period: period,
                    clearDates: true,
                    page: 1,
                  ),
                );
              }
            },
          ),
        ),
        ActionChip(
          avatar: const Icon(
            Icons.date_range,
            size: 18,
          ),
          label: const Text('Custom'),
          onPressed: () => _selectCustomDateRange(context),
        ),
      ],
    );
  }

  Future<void> _selectCustomDateRange(
    BuildContext context,
  ) async {
    final initialStart = filter.startDate ?? DateTime.now();
    final initialEnd = filter.endDate ?? DateTime.now();

    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: initialStart.isBefore(initialEnd)
            ? initialStart
            : initialEnd,
        end: initialEnd.isAfter(initialStart)
            ? initialEnd
            : initialStart,
      ),
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