class RecordFilter {
  final int page;
  final String? period;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? party;

  const RecordFilter({
    this.page = 1,
    this.period,
    this.startDate,
    this.endDate,
    this.status,
    this.party,
  });

  bool get hasFilters {
    return period != null ||
        startDate != null ||
        endDate != null ||
        status != null ||
        party != null;
  }

  RecordFilter copyWith({
    int? page,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? party,
    bool clearPeriod = false,
    bool clearDates = false,
    bool clearStatus = false,
    bool clearParty = false,
  }) {
    return RecordFilter(
      page: page ?? this.page,

      period: clearPeriod
          ? null
          : period ?? this.period,

      startDate: clearDates
          ? null
          : startDate ?? this.startDate,

      endDate: clearDates
          ? null
          : endDate ?? this.endDate,

      status: clearStatus
          ? null
          : status ?? this.status,

      party: clearParty
          ? null
          : party ?? this.party,
    );
  }

  RecordFilter reset() {
    return const RecordFilter();
  }

  RecordFilter resetPage() {
    return copyWith(page: 1);
  }

  Map<String, dynamic> toQueryParameters() {
    final Map<String, dynamic> params = {
      'page': page,
    };

    if (period != null && period!.trim().isNotEmpty) {
      params['period'] = period;
    }

    if (startDate != null) {
      params['startDate'] = _formatDate(startDate!);
    }

    if (endDate != null) {
      params['endDate'] = _formatDate(endDate!);
    }

    if (status != null && status!.trim().isNotEmpty) {
      params['status'] = status;
    }

    if (party != null && party!.trim().isNotEmpty) {
      params['party'] = party;
    }

    return params;
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}