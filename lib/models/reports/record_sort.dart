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
}

class RecordSortOptions {
  static const newest = RecordSortOption(
    value: 'newest',
    label: 'Date: Newest First',
    sortBy: 'date',
    sortOrder: 'desc',
  );

  static const oldest = RecordSortOption(
    value: 'oldest',
    label: 'Date: Oldest First',
    sortBy: 'date',
    sortOrder: 'asc',
  );

  static const amountHighToLow = RecordSortOption(
    value: 'amount_desc',
    label: 'Amount: High to Low',
    sortBy: 'amount',
    sortOrder: 'desc',
  );

  static const amountLowToHigh = RecordSortOption(
    value: 'amount_asc',
    label: 'Amount: Low to High',
    sortBy: 'amount',
    sortOrder: 'asc',
  );

  static const partyAZ = RecordSortOption(
    value: 'party_asc',
    label: 'Party: A to Z',
    sortBy: 'party',
    sortOrder: 'asc',
  );

  static const partyZA = RecordSortOption(
    value: 'party_desc',
    label: 'Party: Z to A',
    sortBy: 'party',
    sortOrder: 'desc',
  );

  static const List<RecordSortOption> purchase = [
    newest,
    oldest,
    amountHighToLow,
    amountLowToHigh,
    partyAZ,
    partyZA,
  ];

  static const List<RecordSortOption> sales = [
    newest,
    oldest,
    amountHighToLow,
    amountLowToHigh,
    partyAZ,
    partyZA,
  ];

  static const List<RecordSortOption> receivables = [
    newest,
    oldest,
    amountHighToLow,
    amountLowToHigh,
    partyAZ,
    partyZA,
  ];

  static const List<RecordSortOption> payables = [
    newest,
    oldest,
    amountHighToLow,
    amountLowToHigh,
    partyAZ,
    partyZA,
  ];
}