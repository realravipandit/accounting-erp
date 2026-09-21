import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_app/features/sales/sales_order_entry_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sas_app/services/dashboard/dashboard_service.dart';
import 'package:sas_app/features/sales/sale_screen.dart';
import 'package:sas_app/shared/widgets/custom_drawer.dart';
import 'package:sas_app/features/purchase/purchase_screen.dart';
import 'package:sas_app/features/receivable/receivable_screen.dart';
import 'package:sas_app/features/payable/payable_screen.dart';
import 'package:sas_app/features/reports/outstanding_screen.dart';
import 'package:sas_app/core/services/sync_service.dart';
import 'package:sas_app/features/inventory/inventory_screen.dart';
import 'package:sas_app/features/reports/ageing_screen.dart';
import 'package:sas_app/features/sales/sales_entry_screen.dart';
import 'package:sas_app/features/purchase/purchase_entry_screen.dart';
import 'package:sas_app/features/banking/cash_bank_entry_screen.dart';
import 'package:sas_app/models/common/record_filter.dart';
import 'package:sas_app/shared/widgets/records/record_date_filter.dart';
import 'package:sas_app/utils/date_period_utils.dart';
// 👉 new combined tabbed screens backing the Transactions / Parties nav tabs
import 'package:sas_app/features/navigation/transactions_screen.dart';
import 'package:sas_app/features/navigation/parties_screen.dart';
// 👉 nav-chrome widgets extracted out of this file --- not dashboard-specific
import 'package:sas_app/shared/widgets/app_bottom_nav.dart';
import 'package:sas_app/shared/widgets/fade_indexed_stack.dart';
// 👉 offers biometric login right after the company is chosen
import 'package:sas_app/services/auth/biometric_enrollment.dart';

// ============================================================================
// HOME PAGE
// ============================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSyncing = false;
  String _companyName = 'Dashboard';
  bool _isOverviewFilterOpen = false;
  bool _isAddMenuOpen = false;
  bool _isDrawerOpen = false;
  late final AnimationController _addMenuController;
  final _syncService = SyncService();
  late final List<Widget> _pages;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // TODO: wire to real counts --- unpaid invoices (Transactions) and low-stock
  // items (Inventory). Deferred per the nav redesign spec; badges stay
  // hidden (count 0) until this is wired up.
  final int _transactionsBadgeCount = 0;
  final int _inventoryBadgeCount = 0;

  // Bottom-nav geometry, shared between the bar, the floating pill, and the
  // quick-add speed-dial menu so they stay aligned.
  static const double _kBarContentHeight = 68;
  static const double _kPillHeight = 48;
  static const double _kPillGap = 14;

  @override
  void initState() {
    super.initState();
    _addMenuController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));

    _pages = [
      DashboardPage(onFilterSheetOpenChanged: _setOverviewFilterOpen),
      const TransactionsScreen(),
      const PartiesScreen(),
      const InventoryScreen(),
    ];

    const FlutterSecureStorage().read(key: 'selected_company_name').then((val) {
      if (val != null && mounted) setState(() => _companyName = val);
    });

    // Offer biometric login right after the company is chosen (only if the
    // user just signed in with a password and hasn't enabled it yet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BiometricEnrollment.promptIfPending(context);
    });
  }

  @override
  void dispose() {
    _addMenuController.dispose();
    super.dispose();
  }

  void _setOverviewFilterOpen(bool open) {
    if (mounted) setState(() => _isOverviewFilterOpen = open);
  }

  void _onNavTap(int i) {
    // The floating pill (and its quick-add menu) only live on Dashboard ---
    // if the user switches away while the menu happens to be open, close it.
    if (i != 0) _closeAddMenu();
    setState(() => _currentIndex = i);
  }

  void _toggleAddMenu() {
    setState(() => _isAddMenuOpen = !_isAddMenuOpen);
    if (_isAddMenuOpen) {
      _addMenuController.forward();
    } else {
      _addMenuController.reverse();
    }
  }

  void _closeAddMenu() {
    if (!_isAddMenuOpen) return;
    setState(() => _isAddMenuOpen = false);
    _addMenuController.reverse();
  }

  void _runQuickAdd(VoidCallback action) {
    _closeAddMenu();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) action();
    });
  }

  List<_QuickAddOption> _quickAddOptions() {
    return [
      _QuickAddOption(
        label: 'Sales',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF10B981),
        onTap: () => _runQuickAdd(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesEntryScreen()))),
      ),
      _QuickAddOption(
        label: 'Purchase',
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => _runQuickAdd(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseEntryScreen()))),
      ),
      _QuickAddOption(
        label: 'Cash / Bank',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF6366F1),
        onTap: () => _runQuickAdd(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBankEntryScreen()))),
      ),
      _QuickAddOption(
        label: 'Sales Order',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => _runQuickAdd(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesOrderEntryScreen()))),
      ),
    ];
  }

  double _staggerValue(double t, int index) {
    final start = index * 0.12;
    final end = (start + 0.6).clamp(0.0, 1.0);
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    return (t - start) / (end - start);
  }

  Future<void> _onSyncPressed() async {
    setState(() => _isSyncing = true);
    await _syncService.syncAll();
    if (!mounted) return;
    setState(() => _isSyncing = false);
  }

  Widget _buildQuickAddMenu() {
    final options = _quickAddOptions();
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // Menu sits above the floating pill, which itself sits above the bar.
    final menuBottom = bottomSafe + _kBarContentHeight + _kPillGap + _kPillHeight + 14;

    return AnimatedBuilder(
      animation: _addMenuController,
      builder: (context, _) {
        final t = _addMenuController.value;
        return IgnorePointer(
          ignoring: t == 0,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeAddMenu,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2 * t, sigmaY: 2 * t),
                    child: Container(color: Colors.black.withValues(alpha: 0.35 * t)),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: menuBottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(options.length, (i) {
                    final progress = _staggerValue(t, i);
                    final scale = Curves.elasticOut.transform(progress);
                    final opacity = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomRight,
                        child: Opacity(
                          opacity: opacity,
                          child: _QuickAddButton(option: options[i]),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final pillBottom = bottomSafe + _kBarContentHeight + _kPillGap;

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          color: Colors.black,
          child: AnimatedScale(
            scale: _isOverviewFilterOpen ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_isOverviewFilterOpen ? 28 : 0),
              ),
              child: Stack(
                children: [
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: const SystemUiOverlayStyle(
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarDividerColor: Colors.transparent,
                      systemNavigationBarIconBrightness: Brightness.dark,
                      systemNavigationBarContrastEnforced: false,
                    ),
                    child: Scaffold(
                      key: _scaffoldKey,
                      backgroundColor: const Color(0xFFF9FAFB),
                      drawer: const CustomDrawer(),
                      onDrawerChanged: (isOpen) => setState(() => _isDrawerOpen = isOpen),
                      extendBody: true,
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        centerTitle: true,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(1),
                          child: Container(color: const Color(0xFFEEF0FE), height: 1),
                        ),
                        title: Text(
                          _companyName,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      body: SafeArea(
                        bottom: false,
                        child: FadeIndexedStack(index: _currentIndex, children: _pages),
                      ),
                      bottomNavigationBar: AppBottomNav(
                        currentIndex: _currentIndex,
                        onTap: _onNavTap,
                        onMoreTap: () => _scaffoldKey.currentState?.openDrawer(),
                        transactionsBadgeCount: _transactionsBadgeCount,
                        inventoryBadgeCount: _inventoryBadgeCount,
                        contentHeight: _kBarContentHeight,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        opacity: _isOverviewFilterOpen ? 0.28 : 0.0,
                        child: Container(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Floating "New transaction" pill --- separate from the bar, anchored
        // to the right edge, floating just above it. Dashboard-only.
        if (_currentIndex == 0 && !_isDrawerOpen)
          Positioned(
            right: 16,
            bottom: pillBottom,
            child: TransactionPill(isSelected: _isAddMenuOpen, onTap: _toggleAddMenu),
          ),

        _buildQuickAddMenu(),
      ],
    );
  }
}

// ============================================================================
// DASHBOARD PAGE
// ============================================================================

class DashboardPage extends StatefulWidget {
  final ValueChanged<bool>? onFilterSheetOpenChanged;

  const DashboardPage({super.key, this.onFilterSheetOpenChanged});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _dashboardService = DashboardService();
  bool _isLoading = true;
  String _selectedPeriod = 'Today';
  DateTimeRange? _customRange;

  static const Color _kDashAccent = Color(0xFF4F46E5);
  static const Color _kDashAccentBg = Color(0xFFEEF0FE);
  static const Color _kBorder = Color(0xFFE7E9ED);
  static const Color _kMuted = Color(0xFF8A8F9A);
  static const Color _kInk = Color(0xFF15171C);

  double _salesAmt = 0, _purchAmt = 0, _custOut = 0, _vendOut = 0, _payables = 0, _receivables = 0, _stockVal = 0;
  int _salesQty = 0, _purchQty = 0, _stockQty = 0;

  @override
  void initState() {
    super.initState();
    _customRange = DatePeriodUtils.calculateDatesForPeriod(_selectedPeriod);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dashboardService.fetchDashboardSummary(
        period: _selectedPeriod,
        startDate: _customRange?.start,
        endDate: _customRange?.end,
      );
      if (mounted) {
        setState(() {
          _salesAmt = (data['salesAmount'] as num?)?.toDouble() ?? 0.0;
          _salesQty = (data['salesQty'] as num?)?.toInt() ?? 0;
          _purchAmt = (data['purchaseAmount'] as num?)?.toDouble() ?? 0.0;
          _purchQty = (data['purchaseQty'] as num?)?.toInt() ?? 0;
          _custOut = (data['customerOutstanding'] as num?)?.toDouble() ?? 0.0;
          _vendOut = (data['vendorOutstanding'] as num?)?.toDouble() ?? 0.0;
          _payables = (data['payables'] as num?)?.toDouble() ?? 0.0;
          _receivables = (data['receivables'] as num?)?.toDouble() ?? 0.0;
          _stockQty = (data['stockQty'] as num?)?.toInt() ?? 0;
          _stockVal = (data['stockValue'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDisplayLabel() {
    if (_customRange != null && _selectedPeriod == 'Custom Date') {
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final start = _customRange!.start;
      final end = _customRange!.end;
      final startStr = '${start.day} ${months[start.month]}';
      final endStr = '${end.day} ${months[end.month]}';
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return startStr;
      }
      return '$startStr - $endStr';
    }
    return _selectedPeriod;
  }

  void _showPeriodFilterSheet() {
    widget.onFilterSheetOpenChanged?.call(true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4, margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('Filter Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kInk)),
              const SizedBox(height: 20),
              const Text('DATE RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              RecordDateFilter(
                filter: RecordFilter(
                  period: _selectedPeriod == 'Custom Date' ? null : _selectedPeriod,
                  startDate: _customRange?.start,
                  endDate: _customRange?.end,
                ),
                onChanged: (newFilter) {
                  setState(() {
                    if (newFilter.startDate != null && newFilter.endDate != null) {
                      _customRange = DateTimeRange(start: newFilter.startDate!, end: newFilter.endDate!);
                      _selectedPeriod = newFilter.period ?? 'Custom Date';
                    } else {
                      _customRange = null;
                      _selectedPeriod = newFilter.period ?? 'All Time';
                    }
                  });
                  Navigator.pop(context);
                  _fetchData();
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      widget.onFilterSheetOpenChanged?.call(false);
    });
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 50, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 24),
          Container(height: 20, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
            const SizedBox(width: 14),
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
          ]),
          const SizedBox(height: 14),
          Container(height: 90, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
            const SizedBox(width: 14),
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
          ]),
          const SizedBox(height: 14),
          Container(height: 90, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
        ],
      ),
    );
  }

  Widget _cardBox(Color c, VoidCallback? onTap, Widget child) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.15), width: 1.5)),
        child: child,
      ),
    );
  }

  Widget _gridItem(String title, IconData icon, Color c, double amt, int? qty, String? sub, Widget screen) {
    return Expanded(child: _cardBox(c, () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 22)),
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text("Rs. ${amt.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1),
        const SizedBox(height: 2),
        qty != null
            ? Text("Qty: $qty", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12))
            : Text(sub ?? "", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
      ])
    ));
  }

  Widget _listItem(String title, IconData icon, Color c, Widget screen, String t1, double v1, String t2, double v2, {bool isStatic = false}) {
    return _cardBox(c, () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)), Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 22)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))), const SizedBox(height: 8),
        Text("$t1${isStatic ? '' : v1.toInt()}", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        Text("$t2${isStatic ? '' : v2.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: Colors.grey)
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kDashAccent,
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        child: _isLoading
            ? _buildSkeletonLoader()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overview', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    InkWell(
                      onTap: _showPeriodFilterSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kDashAccentBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kDashAccent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: _kDashAccent),
                            const SizedBox(width: 6),
                            Text(
                              _getDisplayLabel(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kDashAccent),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _kDashAccent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _gridItem("Sales", Icons.trending_up, const Color(0xFF10B981), _salesAmt, _salesQty, null, const SaleScreen()),
                  const SizedBox(width: 14),
                  _gridItem("Purchases", Icons.shopping_bag, const Color(0xFF3B82F6), _purchAmt, _purchQty, null, const PurchaseScreen()),
                ]),
                const SizedBox(height: 14),
                _listItem("Outstanding Balance", Icons.account_balance_wallet, const Color(0xFFF59E0B), const OutstandingScreen(), "Customer: Rs. ", _custOut, "Vendor: Rs. ", _vendOut),
                const SizedBox(height: 14),
                Row(children: [
                  _gridItem("Payables", Icons.arrow_upward, const Color(0xFFF43F5E), _payables, null, "To pay", const PayableScreen()),
                  const SizedBox(width: 14),
                  _gridItem("Receivables", Icons.arrow_downward, const Color(0xFF0EA5E9), _receivables, null, "To receive", const ReceivableScreen()),
                ]),
                const SizedBox(height: 14),
                _listItem("Inventory Status", Icons.inventory_2, const Color(0xFF6366F1), const InventoryScreen(), "Items in Stock: ", _stockQty.toDouble(), "Total Value: Rs. ", _stockVal),
                const SizedBox(height: 14),
                _listItem('Ageing Report', Icons.access_time, const Color(0xFFA855F7), const AgeingScreen(), "Customer Ageing", 0, "Vendor Ageing", 0, isStatic: true),
              ]),
      ),
    );
  }
}

// ============================================================================
// QUICK-ADD SPEED-DIAL DATA + BUTTON (unchanged)
// ============================================================================

class _QuickAddOption {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAddOption({required this.label, required this.icon, required this.color, required this.onTap});
}

class _QuickAddButton extends StatelessWidget {
  final _QuickAddOption option;
  const _QuickAddButton({required this.option});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: option.onTap,
        child: Container(
          padding: const EdgeInsets.only(left: 16, right: 6, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(width: 10),
              Container(
                width: 40, height: 40, decoration: BoxDecoration(color: option.color, shape: BoxShape.circle),
                child: Icon(option.icon, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nav-chrome widgets (bottom bar, floating pill) now live in
// shared/widgets/app_bottom_nav.dart --- see the import above.