import 'package:flutter/material.dart';

import '../../../models/common/record_filter.dart';
import '../../../models/common/record_sort.dart';
import 'record_filter_sheet.dart';
import 'record_search_field.dart';
import 'record_sort_menu.dart';

class RecordFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final RecordFilter filter;
  final List<RecordSortOption> sortOptions;
  final RecordSortOption selectedSort;

  final String searchHint;
  final bool showStatus;
  final bool showParty;
  final List<String> partyOptions;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<RecordFilter> onFilterChanged;
  final ValueChanged<RecordSortOption> onSortChanged;

  const RecordFilterBar({
    super.key,
    required this.searchController,
    required this.filter,
    required this.sortOptions,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    this.searchHint = 'Search records...',
    this.showStatus = false,
    this.showParty = false,
    this.partyOptions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RecordSearchField(
                controller: searchController,
                hintText: searchHint,
                onChanged: onSearchChanged,
              ),
            ),

            const SizedBox(width: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: 'Filters',
                icon: Badge(
                  isLabelVisible: filter.hasFilters,
                  child: const Icon(
                    Icons.filter_list,
                  ),
                ),
                onPressed: () async {
                  final result =
                      await RecordFilterSheet.show(
                    context: context,
                    filter: filter,
                    showStatus: showStatus,
                    showParty: showParty,
                    partyOptions: partyOptions,
                  );

                  if (result != null) {
                    onFilterChanged(result);
                  }
                },
              ),
            ),

            const SizedBox(width: 4),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RecordSortMenu(
                selected: selectedSort,
                options: sortOptions,
                onSelected: onSortChanged,
              ),
            ),
          ],
        ),

        if (filter.hasFilters) ...[
          const SizedBox(height: 10),
          _ActiveFilters(
            filter: filter,
            onChanged: onFilterChanged,
          ),
        ],
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  final RecordFilter filter;
  final ValueChanged<RecordFilter> onChanged;

  const _ActiveFilters({
    required this.filter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filter.period != null) {
      chips.add(
        _chip(
          filter.period!,
          () {
            onChanged(
              filter.copyWith(
                clearPeriod: true,
                clearDates: true,
                page: 1,
              ),
            );
          },
        ),
      );
    }

    if (filter.startDate != null &&
        filter.endDate != null) {
      chips.add(
        _chip(
          'Custom Date',
          () {
            onChanged(
              filter.copyWith(
                clearDates: true,
                page: 1,
              ),
            );
          },
        ),
      );
    }

    if (filter.status != null) {
      chips.add(
        _chip(
          filter.status!,
          () {
            onChanged(
              filter.copyWith(
                clearStatus: true,
                page: 1,
              ),
            );
          },
        ),
      );
    }

    if (filter.party != null) {
      chips.add(
        _chip(
          filter.party!,
          () {
            onChanged(
              filter.copyWith(
                clearParty: true,
                page: 1,
              ),
            );
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: chip,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _chip(
    String label,
    VoidCallback onDeleted,
  ) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(
        Icons.close,
        size: 16,
      ),
      onDeleted: onDeleted,
    );
  }
}