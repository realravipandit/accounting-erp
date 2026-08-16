import 'package:flutter/material.dart';
import '../../../models/common/record_sort.dart';

class RecordSortMenu extends StatelessWidget {
  final RecordSortOption selected;
  final List<RecordSortOption> options;
  final ValueChanged<RecordSortOption> onSelected;

  const RecordSortMenu({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RecordSortOption>(
      tooltip: 'Sort',
      icon: const Icon(
        Icons.sort,
        color: Color(0xFF011835),
      ),
      onSelected: onSelected,
      itemBuilder: (context) {
        return options.map((option) {
          final isSelected = option.value == selected.value;

          return PopupMenuItem<RecordSortOption>(
            value: option,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: Color(0xFF1E3A8A),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(option.label),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}