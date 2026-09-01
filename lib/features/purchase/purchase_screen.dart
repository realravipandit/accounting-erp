import 'package:flutter/material.dart';

// Adjust these imports to match your exact folder paths if needed
import 'package:sas_app/services/purchase/purchase_service.dart';
import 'package:sas_app/models/common/record_query.dart';
import 'package:sas_app/features/purchase/purchase_details_sheet.dart';

// --- PALETTE -------------------------------------------------------
const _kInk = Color(0xFF15171C);
const _kBg = Color(0xFFF6F7F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE7E9ED);
const _kMuted = Color(0xFF8A8F9A);
const _kText = Color(0xFF1E2025);

// Purchase-specific accent: slate blue for outflow. Treats "money out"
// as a plain ledger fact, not an alarm — reserved for the summary
// strip, amount figures, and active filter/selection state, never
// used decoratively elsewhere.
const _kPurchaseAccent = Color(0xFF0C447C);
const _kPurchaseAccentBg = Color(0xFFE6F1FB);

const _kPaid = Color(0xFF1E8E5A);
const _kPaidBg = Color(0xFFE6F5EE);
const _kPending = Color(0xFFB8860B);
const _kPendingBg = Color(0xFFFBF1DC);
const _kOverdue = Color(0xFFD64545);
const _kOverdueBg = Color(0xFFFBE8E8);

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  // Initialize standard parameters first
  final RecordQuery _currentQuery = RecordQuery(
    page: 1,
    limit: 25,
    sortField: 'VoucherDate',
    sortOrder: 'desc',
  );

  bool _isLoading = false;
  List<dynamic> _purchases = [];
  int _totalPages = 1;

  // Track the active filter label (Defaulting to Today)
  String _selectedFilterLabel = 'Today';

  @override
  void initState() {
    super.initState();
    // Explicitly set the date boundaries for "Today" after creating the
    // object so it doesn't conflict with your RecordQuery constructor.
    final now = DateTime.now();
    _currentQuery.startDate = DateTime(now.year, now.month, now.day);
    _currentQuery.endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await PurchaseService().fetchPurchases(_currentQuery);
      if (mounted) {
        setState(() {
          _purchases = response['data'] ?? [];
          _totalPages = (response['meta'] != null && response['meta']['totalPages'] != null)
              ? response['meta']['totalPages']
              : 1;
        });
      }
    } catch (e) {
      debugPrint("--- ERROR FETCHING PURCHASES: $e ---");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: _kOverdue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyQuickFilter(String label, DateTime? start, DateTime? end) {
    setState(() {
      _selectedFilterLabel = label;
      _currentQuery.startDate = start;
      _currentQuery.endDate = end;
      _currentQuery.page = 1;
    });
    Navigator.pop(context);
    _fetchData();
  }

  Widget _buildFilterChip(String label, DateTime? start, DateTime? end) {
    final isSelected = _selectedFilterLabel == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: _kPurchaseAccent,
      backgroundColor: _kCard,
      side: BorderSide(color: isSelected ? _kPurchaseAccent : _kBorder),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _kText,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (selected) {
        if (selected) {
          _applyQuickFilter(label, start, end);
        }
      },
    );
  }

  void _applyFilter() {
    setState(() {
      _currentQuery.page = 1;
    });
    _fetchData();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        // Week Calculations
        final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
        final thisWeekStart = today.subtract(Duration(days: currentWeekday - 1));
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
        final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));
        final thisMonthStart = DateTime(now.year, now.month, 1);
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        final thisYearStart = DateTime(now.year, 1, 1);

        DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('Filter & View Options', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kInk)),
              const SizedBox(height: 20),
              // --- QUICK FILTERS ---
              const Text('DATE RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _buildFilterChip('Today', today, endOfDay(today)),
                  _buildFilterChip('Yesterday', yesterday, endOfDay(yesterday)),
                  _buildFilterChip('Last 7 Days', today.subtract(const Duration(days: 6)), endOfDay(today)),
                  _buildFilterChip('This Week', thisWeekStart, endOfDay(today)),
                  _buildFilterChip('Last Week', lastWeekStart, endOfDay(lastWeekEnd)),
                  _buildFilterChip('This Month', thisMonthStart, endOfDay(DateTime(now.year, now.month + 1, 0))),
                  _buildFilterChip('Last Month', lastMonthStart, endOfDay(lastMonthEnd)),
                  _buildFilterChip('This Year', thisYearStart, endOfDay(DateTime(now.year, 12, 31))),
                  _buildFilterChip('All Time', null, null),
                ],
              ),
              const SizedBox(height: 24),
              // --- RECORDS PER PAGE ---
              const Text('RECORDS PER PAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [25, 50, 100, 200, 500].map((int val) {
                  final isSelected = _currentQuery.limit == val;
                  return ChoiceChip(
                    label: Text('$val'),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: _kPurchaseAccent,
                    backgroundColor: _kCard,
                    side: BorderSide(color: isSelected ? _kPurchaseAccent : _kBorder),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : _kText,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _currentQuery.limit = val;
                          _currentQuery.page = 1;
                        });
                        Navigator.pop(context);
                        _fetchData();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // --- CUSTOM DATE RANGE ---
              const Text('CUSTOM DATES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_rounded, color: _kPurchaseAccent, size: 21),
                title: const Text('Select Custom Range', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: _kMuted),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(DateTime.now().year - 10),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    _applyQuickFilter('Custom Dates', picked.start, endOfDay(picked.end));
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _currentQuery.extraFilters.clear();
                    _applyQuickFilter('All Time', null, null);
                  },
                  child: Text('Clear All Filters', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  List<MapEntry<String, List<dynamic>>> _groupedByDate() {
    final Map<String, List<dynamic>> groups = {};
    for (final item in _purchases) {
      String dateStr = DateUtil.formatDate(item['VoucherDate']?.toString() ?? item['voucherDate']?.toString());
      groups.putIfAbsent(dateStr, () => []).add(item);
    }
    return groups.entries.toList();
  }

  double _sumTotal() {
    double sum = 0;
    for (final item in _purchases) {
      final raw = item['totalAmount'] ?? item['GrandTotal'] ?? 0;
      sum += double.tryParse(raw.toString()) ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _groupedByDate();
    final total = _sumTotal();

    return Scaffold(
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
                    'Purchases',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.4),
                  ),
                  Row(
                    children: [
                      if (_selectedFilterLabel != 'All Time')
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kPurchaseAccentBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kPurchaseAccent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: _kPurchaseAccent),
                              const SizedBox(width: 6),
                              Text(
                                _selectedFilterLabel,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kPurchaseAccent),
                              ),
                            ],
                          ),
                        ),
                      InkWell(
                        onTap: _showFilterSheet,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _kCard,
                            border: Border.all(color: _kBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 19, color: _kInk),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- SUMMARY STRIP (slate blue) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _kPurchaseAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL PURCHASES', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600, letterSpacing: 0.8)),
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
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_purchases.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- SEARCH ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  style: const TextStyle(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Search bill no. or vendor',
                    hintStyle: TextStyle(color: _kMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onSubmitted: (value) {
                    _currentQuery.search = value;
                    _applyFilter();
                  },
                ),
              ),
            ),

            // --- LIST ---
            Expanded(
              child: _isLoading
                  ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: _kPurchaseAccent)))
                  : _purchases.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 42, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No purchase records found', style: TextStyle(fontSize: 14.5, color: _kMuted, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          itemCount: sections.length,
                          itemBuilder: (context, i) {
                            final entry = sections[i];
                            return _DateGroup(
                              dateLabel: entry.key,
                              items: entry.value,
                              onTapItem: (item) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => PurchaseDetailsSheet(purchaseData: item),
                                );
                              },
                            );
                          },
                        ),
            ),

            
            // --- PAGINATION ---
            Container(
              decoration: const BoxDecoration(
                color: _kBg,
                border: Border(top: BorderSide(color: _kBorder, width: 0.5)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                2,
                16,
                8 + (MediaQuery.of(context).padding.bottom * 0.7), // was: MediaQuery.of(context).padding.bottom > 0 ? 8 : 12
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _currentQuery.page > 1
                        ? () {
                            setState(() => _currentQuery.page--);
                            _fetchData();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Prev'),
                    style: TextButton.styleFrom(
                      foregroundColor: _kPurchaseAccent,
                      disabledForegroundColor: Colors.grey[300],
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Text('Page ${_currentQuery.page} of $_totalPages',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: _kMuted, fontSize: 13)),
                  TextButton.icon(
                    onPressed: _currentQuery.page < _totalPages
                        ? () {
                            setState(() => _currentQuery.page++);
                            _fetchData();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next'),
                    style: TextButton.styleFrom(
                      foregroundColor: _kPurchaseAccent,
                      disabledForegroundColor: Colors.grey[300],
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateGroup extends StatelessWidget {
  final String dateLabel;
  final List<dynamic> items;
  final void Function(dynamic item) onTapItem;

  const _DateGroup({required this.dateLabel, required this.items, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kMuted),
                  ),
                )
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _kCard,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final isLast = i == items.length - 1;
                return _PurchaseRow(
                  item: items[i],
                  showDivider: !isLast,
                  onTap: () => onTapItem(items[i]),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  final dynamic item;
  final bool showDivider;
  final VoidCallback onTap;

  const _PurchaseRow({required this.item, required this.showDivider, required this.onTap});

  _StatusStyle? _statusFor(dynamic item) {
    final raw = (item['paymentStatus'] ?? item['Status'] ?? '').toString().toLowerCase();
    if (raw.contains('overdue')) return _StatusStyle('Overdue', _kOverdue, _kOverdueBg);
    if (raw.contains('pending') || raw.contains('due')) return _StatusStyle('Pending', _kPending, _kPendingBg);
    if (raw.contains('paid')) return _StatusStyle('Paid', _kPaid, _kPaidBg);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String timeStr = DateUtil.formatTime(item['VoucherTime']?.toString() ?? item['voucherTime']?.toString());
    final String vendorName = item['supplierName']?.toString() ?? item['LedgerName']?.toString() ?? 'Unknown Vendor';
    final String totalStr = item['totalAmount']?.toString() ?? item['GrandTotal']?.toString() ?? '0.00';
    final String voucherNo = item['VoucherID']?.toString() ?? 'N/A';
    final List<dynamic> lineItems = item['items'] is List ? item['items'] : [];
    final int itemCount = lineItems.length;
    final _StatusStyle? status = _statusFor(item);

    return InkWell(
      onTap: onTap,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vendorName,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (status != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(6)),
                              child: Text(status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status.color)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$voucherNo${timeStr.isNotEmpty ? '  -  $timeStr' : ''}${itemCount > 0 ? '  -  $itemCount item${itemCount > 1 ? 's' : ''}' : ''}',
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Amount tinted slate blue — this is a purchase, i.e. money out.
                Text('Rs. $totalStr', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kPurchaseAccent)),
              ],
            ),
          ),
          if (showDivider) Container(height: 1, margin: const EdgeInsets.only(left: 14), color: _kBorder),
        ],
      ),
    );
  }
}

class _StatusStyle {
  final String label;
  final Color color;
  final Color bg;
  _StatusStyle(this.label, this.color, this.bg);
}

// ------------------------------------------------------------------
// DATE UTIL
// ------------------------------------------------------------------
class DateUtil {
  static String formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'No Date';
    try {
      DateTime dt = DateTime.parse(raw.trim());
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day}  ${months[dt.month]}  ${dt.year}';
    } catch (e) {
      return raw.trim().split('T')[0].split(' ')[0];
    }
  }

  static String formatRawDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'No Date';
    String d = raw.trim();
    if (d.contains('T')) return d.split('T')[0];
    if (d.contains(' ')) return d.split(' ')[0];
    return d;
  }

  static String formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(raw.trim());
      if (dt.hour == 0 && dt.minute == 0) return '';
      int h = dt.hour;
      String period = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}  $period';
    } catch (e) {
      String t = raw.trim();
      if (t.contains('T')) t = t.split('T').last;
      if (t.contains(' ')) t = t.split(' ').last;
      if (t.contains(':')) {
        final parts = t.split(':');
        if (parts.length >= 2) {
          if (parts[0] == '00' && parts[1] == '00') return '';
          int h = int.tryParse(parts[0]) ?? 0;
          String period = h >= 12 ? 'PM' : 'AM';
          h = h % 12;
          if (h == 0) h = 12;
          return '${h.toString().padLeft(2, '0')}:${parts[1].padLeft(2, '0')}  $period';
        }
      }
      return '';
    }
  }
}