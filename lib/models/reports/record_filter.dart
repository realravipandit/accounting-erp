class RecordFilter {
  final String search;
  final String? period;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? party;
  final String sortBy;
  final String sortOrder;
  final int page;
  final int limit;

  const RecordFilter({
    this.search = '',
    this.period,
    this.startDate,
    this.endDate,
    this.status,
    this.party,
    this.sortBy = 'date',
    this.sortOrder = 'desc',
    this.page = 1,
    this.limit = 25,
  });

  RecordFilter copyWith({
    String? search,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? party,
    String? sortBy,
    String? sortOrder,
    int? page,
    int? limit,
    bool clearPeriod = false,
    bool clearDates = false,
    bool clearStatus = false,
    bool clearParty = false,
  }) {
    return RecordFilter(
      search: search ?? this.search,
      period: clearPeriod ? null : (period ?? this.period),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      status: clearStatus ? null : (status ?? this.status),
      party: clearParty ? null : (party ?? this.party),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  RecordFilter reset() {
    return const RecordFilter();
  }

  bool get hasFilters {
    return search.trim().isNotEmpty ||
        period != null ||
        startDate != null ||
        endDate != null ||
        status != null ||
        party != null;
  }

  Map<String, dynamic> toQueryParameters() {
    final Map<String, dynamic> params = {};

    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    if (period != null && period!.isNotEmpty) {
      params['period'] = period;
    }

    if (startDate != null) {
      params['startDate'] = _formatDate(startDate!);
    }

    if (endDate != null) {
      params['endDate'] = _formatDate(endDate!);
    }

    if (status != null && status!.isNotEmpty) {
      params['status'] = status;
    }

    if (party != null && party!.isNotEmpty) {
      params['party'] = party;
    }

    params['sortBy'] = sortBy;
    params['sortOrder'] = sortOrder;
    params['page'] = page.toString();
    params['limit'] = limit.toString();

    return params;
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}