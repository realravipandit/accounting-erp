import 'package:flutter/material.dart';

// Adjust these imports to match your exact folder paths
import 'package:sas_akount_login/services/sales/sales_service.dart';
import 'package:sas_akount_login/models/common/record_query.dart';
import 'package:sas_akount_login/features/sales/sale_details_sheet.dart'; // Adjust name if needed

// --- PALETTE -------------------------------------------------------
const _kInk = Color(0xFF15171C);
const _kBg = Color(0xFFF6F7F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE7E9ED);
const _kMuted = Color(0xFF8A8F9A);
const _kText = Color(0xFF1E2025);

// Sales-specific accent: emerald/green for income. Reserved for the
// summary strip, amount figures, and the active filter chip — never
// used decoratively elsewhere, so it stays meaningful.
const _kSalesAccent = Color(0xFF0F6E56);
const _kSalesAccentBg = Color(0xFFE1F5EE);

const _kPaid = Color(0xFF1E8E5A);
const _kPaidBg = Color(0xFFE6F5EE);
const _kPending = Color(0xFFB8860B);
const _kPendingBg = Color(0xFFFBF1DC);
const _kOverdue = Color(0xFFD64545);
const _kOverdueBg = Color(0xFFFBE8E8);

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  late RecordQuery _currentQuery;
  bool _isLoading = false;
  List<dynamic> _sales = [];
  int _totalPages = 1;

  // Track the active filter label (Defaulting to Today)
  String _selectedFilterLabel = 'Today';

  @override
  void initState() {
    super.initState();
    // Default to Today's dates
    final now = DateTime.now();
    _currentQuery = RecordQuery(
      page: 1,
      limit: 25,
      sortField: 'VoucherDate',
      sortOrder: 'desc',
    );
    _currentQuery.startDate = DateTime(now.year, now.month, now.day);
    _currentQuery.endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await SalesService().fetchSales(_currentQuery);
      if (mounted) {
        setState(() {
          _sales = response['data'] ?? [];
          _totalPages = (response['meta'] != null && response['meta']['totalPages'] != null)
              ? response['meta']['totalPages']
              : 1;
        });
      }
    } catch (e) {
      debugPrint("--- ERROR FETCHING SALES: $e ---");
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
      selectedColor: _kSalesAccent,
      backgroundColor: _kCard,
      side: BorderSide(color: isSelected ? _kSalesAccent : _kBorder),
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
        final currentWeekday = now.weekday;
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
                    selectedColor: _kSalesAccent,
                    backgroundColor: _kCard,
                    side: BorderSide(color: isSelected ? _kSalesAccent : _kBorder),
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
              const Text('CUSTOM DATES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_rounded, color: _kSalesAccent, size: 21),
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
    for (final item in _sales) {
      String dateStr = DateUtil.formatDate(item['VoucherDate']?.toString() ?? item['voucherDate']?.toString());
      groups.putIfAbsent(dateStr, () => []).add(item);
    }
    return groups.entries.toList();
  }

  String _formatCurrency(String amount) {
    double parsed = double.tryParse(amount) ?? 0.0;
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parsed.toStringAsFixed(2).replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  double _sumTotal() {
    double sum = 0;
    for (final item in _sales) {
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
                    'Sales',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.4),
                  ),
                  Row(
                    children: [
                      if (_selectedFilterLabel != 'All Time')
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kSalesAccentBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kSalesAccent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: _kSalesAccent),
                              const SizedBox(width: 6),
                              Text(
                                _selectedFilterLabel,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kSalesAccent),
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

            // --- SUMMARY STRIP (emerald — this is the one place accent fills a whole surface) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _kSalesAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL SALES', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                          const SizedBox(height: 5),
                          Text(
                            'Rs. ${_formatCurrency(total.toString())}',
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
                        '${_sales.length}',
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
                    hintText: 'Search invoice no. or customer',
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
                  ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: _kSalesAccent)))
                  : _sales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 42, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No sales records found', style: TextStyle(fontSize: 14.5, color: _kMuted, fontWeight: FontWeight.w500)),
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
                                  builder: (context) => SaleDetailsSheet(saleData: item),
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
              padding: EdgeInsets.fromLTRB(16, 2, 16, MediaQuery.of(context).padding.bottom > 0 ? 8 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _currentQuery.page > 1 ? () { setState(() => _currentQuery.page--); _fetchData(); } : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Prev'),
                    style: TextButton.styleFrom(
                      foregroundColor: _kSalesAccent,
                      disabledForegroundColor: Colors.grey[300],
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Text('Page ${_currentQuery.page} of $_totalPages', style: const TextStyle(fontWeight: FontWeight.w700, color: _kMuted, fontSize: 13)),
                  TextButton.icon(
                    onPressed: _currentQuery.page < _totalPages ? () { setState(() => _currentQuery.page++); _fetchData(); } : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next'),
                    style: TextButton.styleFrom(
                      foregroundColor: _kSalesAccent,
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
                return _SaleRow(
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

class _SaleRow extends StatelessWidget {
  final dynamic item;
  final bool showDivider;
  final VoidCallback onTap;

  const _SaleRow({required this.item, required this.showDivider, required this.onTap});

  String _formatCurrency(String amount) {
    double parsed = double.tryParse(amount) ?? 0.0;
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parsed.toStringAsFixed(2).replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

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
    final String customerName = (item['customerName'] ?? item['LedgerName'] ?? 'Unknown Customer').toString().replaceAll('\n', ' ').trim();
    final String totalStr = item['totalAmount']?.toString() ?? item['GrandTotal']?.toString() ?? '0.00';
    final String invoiceNo = item['invoiceNumber']?.toString() ?? item['VoucherID']?.toString() ?? 'N/A';
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              customerName,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kText, height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (status != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(6)),
                              child: Text(status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status.color)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$invoiceNo${timeStr.isNotEmpty ? '  -  $timeStr' : ''}${itemCount > 0 ? '  -  $itemCount item${itemCount > 1 ? 's' : ''}' : ''}',
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Amount tinted emerald here — this is a sale, i.e. money in.
                Text('Rs. ${_formatCurrency(totalStr)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kSalesAccent)),
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
// BULLETPROOF DATE & TIME UTILITY
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