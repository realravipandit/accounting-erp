import 'package:flutter/material.dart';

class RecordPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int pageSize;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int>? onPageSizeChanged;

  const RecordPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.pageSize,
    this.onPrevious,
    this.onNext,
    this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            totalRecords == 0
                ? 'No records'
                : 'Page $currentPage of $totalPages'
                ' • $totalRecords records',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),

        const Text(
          'Rows:',
          style: TextStyle(
            fontSize: 13,
          ),
        ),

        const SizedBox(width: 6),

        DropdownButton<int>(
          value: pageSize,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(
              value: 25,
              child: Text('25'),
            ),
            DropdownMenuItem(
              value: 50,
              child: Text('50'),
            ),
            DropdownMenuItem(
              value: 100,
              child: Text('100'),
            ),
            DropdownMenuItem(
              value: 250,
              child: Text('250'),
            ),
          ],
          onChanged: onPageSizeChanged,
        ),

        IconButton(
          tooltip: 'Previous',
          onPressed: currentPage > 1
              ? onPrevious
              : null,
          icon: const Icon(
            Icons.chevron_left,
          ),
        ),

        IconButton(
          tooltip: 'Next',
          onPressed: currentPage < totalPages
              ? onNext
              : null,
          icon: const Icon(
            Icons.chevron_right,
          ),
        ),
      ],
    );
  }
}