import 'pagination.dart';

class PaginatedResponse<T> {
  final List<T> records;
  final Pagination pagination;

  const PaginatedResponse({
    required this.records,
    required this.pagination,
  });
}