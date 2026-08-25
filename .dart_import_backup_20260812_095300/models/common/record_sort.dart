class RecordSortOption {
  final String value;
  final String label;
  final String sortBy;
  final String sortOrder;

  const RecordSortOption({
    required this.value,
    required this.label,
    required this.sortBy,
    required this.sortOrder,
  });

  Map<String, dynamic> toQueryParameters() {
    return {
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RecordSortOption &&
        other.value == value &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    return Object.hash(
      value,
      sortBy,
      sortOrder,
    );
  }
}