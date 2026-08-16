class RecordQuery {
  int page;
  int limit;
  String? search;
  String? period;
  DateTime? startDate;
  DateTime? endDate;
  String sortField; 
  String sortOrder;
  Map<String, dynamic> extraFilters;

  RecordQuery({
    this.page = 1,
    this.limit = 25,
    this.search,
    this.period,
    this.startDate,
    this.endDate,
    this.sortField = 'VoucherDate', // Matches backend SQL
    this.sortOrder = 'desc',
    this.extraFilters = const {},   // Used for Vendor ID filtering
  });

  Map<String, String> toQueryParameters() {
    final Map<String, String> params = {
      'page': page.toString(),
      'limit': limit.toString(),
      'sortField': sortField,
      'sortOrder': sortOrder,
    };

    if (search != null && search!.trim().isNotEmpty) {
      params['search'] = search!.trim();
    }

    if (period != null && period!.trim().isNotEmpty) {
      params['period'] = period!;
    }

    if (startDate != null) {
      params['startDate'] = _formatDate(startDate!);
    }
    if (endDate != null) {
      params['endDate'] = _formatDate(endDate!);
    }

    extraFilters.forEach((key, value) {
      if (value != null) params[key] = value.toString();
    });

    return params;
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
  
  void resetPage() {
    page = 1;
  }

  void nextPage() {
    page++;
  }

  void previousPage() {
    if (page > 1) page--;
  }
}