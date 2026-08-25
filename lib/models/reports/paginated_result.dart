class PaginatedResult<T> {
  final List<T> records;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const PaginatedResult({
    required this.records,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final recordsJson = json['records'];

    final List<T> records = recordsJson is List
        ? recordsJson
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList()
        : [];

    final pagination =
        json['pagination'] as Map<String, dynamic>? ?? {};

    return PaginatedResult<T>(
      records: records,
      page: _toInt(pagination['page'], 1),
      limit: _toInt(pagination['limit'], 25),
      total: _toInt(pagination['total'], records.length),
      totalPages: _toInt(pagination['totalPages'], 1),
      hasNextPage: pagination['hasNextPage'] == true,
      hasPreviousPage: pagination['hasPreviousPage'] == true,
    );
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}