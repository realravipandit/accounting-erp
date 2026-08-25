class RecordQuery {
  final int page;
  final int limit;

  final String? search;
  final String? period;

  final DateTime? startDate;
  final DateTime? endDate;

  final String sortBy;
  final String sortOrder;

  const RecordQuery({
    this.page = 1,
    this.limit = 25,
    this.search,
    this.period,
    this.startDate,
    this.endDate,
    this.sortBy = 'date',
    this.sortOrder = 'desc',
  });

  RecordQuery copyWith({
    int? page,
    int? limit,
    String? search,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    String? sortOrder,
  }) {
    return RecordQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    final Map<String, dynamic> params = {
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    if (search != null && search!.trim().isNotEmpty) {
      params['search'] = search!.trim();
    }

    if (period != null && period!.trim().isNotEmpty) {
      params['period'] = period;
    }

    if (startDate != null) {
      params['startDate'] = _formatDate(startDate!);
    }

    if (endDate != null) {
      params['endDate'] = _formatDate(endDate!);
    }

    return params;
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  RecordQuery resetPage() {
    return copyWith(page: 1);
  }

  RecordQuery nextPage() {
    return copyWith(page: page + 1);
  }

  RecordQuery previousPage() {
    return copyWith(
      page: page > 1 ? page - 1 : 1,
    );
  }
}