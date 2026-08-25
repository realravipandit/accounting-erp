import 'package:flutter/material.dart';

import '../../../models/common/record_filter.dart';
import 'record_date_filter.dart';

class RecordFilterSheet extends StatefulWidget {
  final RecordFilter initialFilter;
  final bool showStatus;
  final bool showParty;
  final List<String> statusOptions;
  final List<String> partyOptions;

  const RecordFilterSheet({
    super.key,
    required this.initialFilter,
    this.showStatus = false,
    this.showParty = false,
    this.statusOptions = const [
      'Paid',
      'Partial',
      'Unpaid',
    ],
    this.partyOptions = const [],
  });

  static Future<RecordFilter?> show({
    required BuildContext context,
    required RecordFilter filter,
    bool showStatus = false,
    bool showParty = false,
    List<String> statusOptions = const [
      'Paid',
      'Partial',
      'Unpaid',
    ],
    List<String> partyOptions = const [],
  }) {
    return showModalBottomSheet<RecordFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return RecordFilterSheet(
          initialFilter: filter,
          showStatus: showStatus,
          showParty: showParty,
          statusOptions: statusOptions,
          partyOptions: partyOptions,
        );
      },
    );
  }

  @override
  State<RecordFilterSheet> createState() =>
      _RecordFilterSheetState();
}

class _RecordFilterSheetState
    extends State<RecordFilterSheet> {
  late RecordFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 700,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filter = _filter.reset();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                'Date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              RecordDateFilter(
                filter: _filter,
                onChanged: (value) {
                  setState(() {
                    _filter = value;
                  });
                },
              ),

              if (_filter.startDate != null &&
                  _filter.endDate != null) ...[
                const SizedBox(height: 10),
                Text(
                  '${_formatDate(_filter.startDate!)} → '
                  '${_formatDate(_filter.endDate!)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],

              if (widget.showStatus) ...[
                const SizedBox(height: 24),

                const Text(
                  'Payment Status',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.statusOptions.map((status) {
                    return ChoiceChip(
                      label: Text(status),
                      selected: _filter.status == status,
                      onSelected: (_) {
                        setState(() {
                          if (_filter.status == status) {
                            _filter = _filter.copyWith(
                              clearStatus: true,
                              page: 1,
                            );
                          } else {
                            _filter = _filter.copyWith(
                              status: status,
                              page: 1,
                            );
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              if (widget.showParty &&
                  widget.partyOptions.isNotEmpty) ...[
                const SizedBox(height: 24),

                const Text(
                  'Party',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: _filter.party,
                  decoration: InputDecoration(
                    hintText: 'Select party',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: widget.partyOptions.map((party) {
                    return DropdownMenuItem<String>(
                      value: party,
                      child: Text(party),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filter = _filter.copyWith(
                        party: value,
                        page: 1,
                      );
                    });
                  },
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _filter);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}