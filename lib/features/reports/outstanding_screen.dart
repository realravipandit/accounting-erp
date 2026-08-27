import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sas_akount_login/services/receivable/receivable_service.dart';
import 'package:sas_akount_login/models/receivable/outstanding.dart';
import 'package:sas_akount_login/features/reports/outstanding_details_sheet.dart';

// --- PALETTE (shared with sale_screen.dart / purchase_screen.dart) --
const _kInk = Color(0xFF15171C);
const _kBg = Color(0xFFF6F7F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE7E9ED);
const _kMuted = Color(0xFF8A8F9A);
const _kText = Color(0xFF1E2025);
const _kOverdue = Color(0xFFD64545);

// Customers = receivable = money coming in → same family as Sales.
const _kCustAccent = Color(0xFF0F6E56);
// Vendors = payable = money going out → same family as Purchases.
const _kVendAccent = Color(0xFF0C447C);

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key});

  @override
  _OutstandingScreenState createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  late Future<List<Outstanding>> _futureData;
  final _apiService = ReceivableService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  // ---- OLD-SOFTWARE-PARITY FILTER STATE ----
  // Mirrors rdoBillDate.Checked from the old C# screen: report can be run
  // by invoice (bill) date or by due date.
  String _dateBasis = 'bill'; // 'bill' | 'due'
  // Mirrors the old SP's 3rd date param -- lets the user pull outstanding
  // "as of" any date, not just today.
  DateTime _asOfDate = DateTime.now();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchFocusNode.addListener(() => setState(() {}));
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      // NOTE: fetchOutstanding needs to accept these params and forward them
      // as query params to GET /outstanding -- see receivable_service_additions.dart
      _futureData = _apiService
          .fetchOutstanding(
        dateBasis: _dateBasis,
        asOfDate: _asOfDate,
        fromDate: _fromDate,
        toDate: _toDate ?? _asOfDate,
      )
          .then((response) {
        final records = response['records'];
        if (records is! List) {
          return <Outstanding>[];
        }
        return records.map((item) {
          return Outstanding.fromMap(Map<String, dynamic>.from(item as Map));
        }).toList();
      });
    });
  }

  Future<void> _pickAsOfDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOfDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _asOfDate = picked);
      _loadData();
    }
  }

  void _showOutstandingDetails(BuildContext context, Outstanding item, bool isCust) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OutstandingDetailsSheet(item: item, isCust: isCust),
    );
  }

  double _sumFor(List<Outstanding> items) {
    double sum = 0;
    for (final i in items) {
      sum += i.outstandingAmount ?? 0.0;
    }
    return sum;
  }

  List<Outstanding> _applySearch(List<Outstanding> items) {
    if (_query.isEmpty) return items;
    return items.where((i) {
      final name = (i.name ?? '').toLowerCase();
      final id = (i.id ?? '').toLowerCase();
      return name.contains(_query) || id.contains(_query);
    }).toList();
  }

  // ---- NEW: filter bar restoring old software's Bill/Due toggle + as-of date ----
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _basisChip('Bill Date', 'bill')),
                  Expanded(child: _basisChip('Due Date', 'due')),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _pickAsOfDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: _kCard,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 16, color: _kMuted),
                  const SizedBox(width: 6),
                  Text(
                    'As of ${DateFormat('dd MMM yyyy').format(_asOfDate)}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _basisChip(String label, String value) {
    final selected = _dateBasis == value;
    return InkWell(
      onTap: () {
        if (_dateBasis != value) {
          setState(() => _dateBasis = value);
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kInk : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(List<Outstanding> items, bool isCust) {
    final accent = isCust ? _kCustAccent : _kVendAccent;
    final total = _sumFor(items);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCust ? 'TOTAL RECEIVABLE' : 'TOTAL PAYABLE',
                    style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Rs. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('${items.length}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Outstanding item, bool isCust, bool showDivider) {
    final accent = isCust ? _kCustAccent : _kVendAccent;
    final title = item.name ?? 'Unknown Account';
    final idLabel = 'ID: ${item.id ?? 'N/A'}';
    final amount = item.outstandingAmount ?? 0.0;

    return InkWell(
      onTap: () => _showOutstandingDetails(context, item, isCust),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(idLabel, style: const TextStyle(fontSize: 12, color: _kMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('Rs. ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
          if (showDivider) Container(height: 1, margin: const EdgeInsets.only(left: 14), color: _kBorder),
        ],
      ),
    );
  }

  Widget _buildTabList(List<Outstanding> allItems, bool isCust) {
    final items = _applySearch(allItems);

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 44, color: Colors.grey[300]),
            const SizedBox(height: 14),
            const Text('All clear', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 6),
            Text(
              'No outstanding balances for ${isCust ? 'customers' : 'vendors'}',
              style: const TextStyle(color: _kMuted, fontSize: 13.5),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No matches found', style: TextStyle(fontSize: 14.5, color: _kMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: isCust ? _kCustAccent : _kVendAccent,
      onRefresh: () async => _loadData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          _buildSummaryStrip(items, isCust),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: List.generate(items.length, (i) {
                  final isLast = i == items.length - 1;
                  return _buildRow(items[i], isCust, !isLast);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearchActive = _searchFocusNode.hasFocus || _query.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // --- TITLE ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Outstanding',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.4),
                    ),
                    InkWell(
                      onTap: _loadData,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: _kCard, border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.refresh_rounded, size: 19, color: _kInk),
                      ),
                    ),
                  ],
                ),
              ),

              // --- NEW: BILL/DUE DATE + AS-OF-DATE FILTER BAR ---
              _buildFilterBar(),

              // --- ANIMATED SEARCH BAR ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSearchActive ? _kInk : _kBorder, width: isSearchActive ? 1.4 : 1),
                    boxShadow: isSearchActive
                        ? [BoxShadow(color: _kInk.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 6))]
                        : [],
                  ),
                  child: Row(
                    children: [
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 220),
                        padding: EdgeInsets.only(left: isSearchActive ? 14 : 12),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.search_rounded,
                            key: ValueKey(isSearchActive),
                            size: 20,
                            color: isSearchActive ? _kInk : _kMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: const TextStyle(fontSize: 14.5),
                          decoration: const InputDecoration(
                            hintText: 'Search customer or vendor',
                            hintStyle: TextStyle(color: _kMuted, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                        child: _query.isNotEmpty
                            ? IconButton(
                                key: const ValueKey('clear'),
                                icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchFocusNode.unfocus();
                                },
                              )
                            : const SizedBox(key: ValueKey('empty'), width: 4),
                      ),
                    ],
                  ),
                ),
              ),

              // --- TABS ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  decoration: BoxDecoration(color: _kCard, border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(4),
                  child: const TabBar(
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(color: _kInk, borderRadius: BorderRadius.all(Radius.circular(7))),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: _kMuted,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    tabs: [
                      Tab(height: 38, text: 'Customers'),
                      Tab(height: 38, text: 'Vendors'),
                    ],
                  ),
                ),
              ),

              // --- CONTENT ---
              Expanded(
                child: FutureBuilder<List<Outstanding>>(
                  future: _futureData,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: _kInk)));
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 42, color: _kOverdue.withValues(alpha: 0.6)),
                              const SizedBox(height: 14),
                              const Text('Error loading data', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _kInk)),
                              const SizedBox(height: 6),
                              Text(snap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: _kMuted, fontSize: 12.5)),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kInk,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final allItems = snap.data ?? [];
                    final customers = allItems.where((e) => e.type?.toLowerCase() == 'customer').toList();
                    final vendors = allItems.where((e) => e.type?.toLowerCase() == 'vendor').toList();
                    return TabBarView(
                      children: [
                        _buildTabList(customers, true),
                        _buildTabList(vendors, false),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}