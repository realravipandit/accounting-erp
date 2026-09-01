import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👉 REQUIRED FOR TRANSPARENT SYSTEM BAR

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

  // Drives the iOS-style "push back" effect when the Overview filter sheet
  // is open. Lifted up here (rather than kept in DashboardPage) because the
  // animation needs to scale the WHOLE screen -- app bar and bottom nav
  // included -- not just the dashboard content sitting inside the IndexedStack.
  bool _isOverviewFilterOpen = false;

  // Drives the "quick add" speed-dial menu that pops out of the add button.
  bool _isAddMenuOpen = false;
  late final AnimationController _addMenuController;

  final _syncService = SyncService();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _addMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _pages = [
      DashboardPage(onFilterSheetOpenChanged: _setOverviewFilterOpen),
      const ReceivableScreen(),
      const AddNewContentPage(), // unused now -- add button no longer routes here
      const SaleScreen(),
      const PayableScreen(),
    ];

    const FlutterSecureStorage().read(key: 'selected_company_name').then((val) {
      if (val != null && mounted) setState(() => _companyName = val);
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

  // Closes the menu first, then runs the action a beat later so the
  // retract animation gets to play instead of being cut off by a push route.
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
        onTap: () => _runQuickAdd(
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesEntryScreen())),
        ),
      ),
      _QuickAddOption(
        label: 'Purchase',
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => _runQuickAdd(
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseEntryScreen())),
        ),
      ),
      _QuickAddOption(
        label: 'Cash / Bank',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF6366F1),
        onTap: () => _runQuickAdd(
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBankEntryScreen())),
          ),
        ),
      _QuickAddOption(
        label: 'Sales Order',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => _runQuickAdd(
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesOrderEntryScreen())),
          ),
        ),
    ];
  }

  // Maps the shared controller (0..1) to a per-item 0..1 progress value so
  // each option animates in with a slight delay after the one before it.
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

    return AnimatedBuilder(
      animation: _addMenuController,
      builder: (context, _) {
        final t = _addMenuController.value;
        return IgnorePointer(
          ignoring: t == 0,
          child: Stack(
            children: [
              // Tap-outside-to-close scrim.
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
              // Options springing out of the add button.
              Positioned(
                right: 16,
                bottom: bottomSafe + 12 + 64 + 16,
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
    return Stack(
      children: [
        // ---- iOS-style "push back" -- the whole screen scales down
        // slightly and gains rounded corners while the Overview filter
        // sheet is open, revealing the dark backdrop behind it. Applied
        // here (outermost) so the app bar and bottom nav scale together
        // with the page content, matching the native modal-presentation feel.
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
                  // 👉 FIX 1: AnnotatedRegion forces Android to drop the white system background
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: const SystemUiOverlayStyle(
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarDividerColor: Colors.transparent,
                      systemNavigationBarIconBrightness: Brightness.dark,
                      systemNavigationBarContrastEnforced: false,
                    ),
                    child: Scaffold(
                      backgroundColor: const Color(0xFFF9FAFB),
                      drawer: const CustomDrawer(),
                      // REQUIRED for the glass effect: lets page content scroll UNDER the nav bar
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
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // 👉 FIX 2: Set bottom: false so the content flows beautifully under the glass navbar
                      body: SafeArea(
                        bottom: false,
                        child: IndexedStack(index: _currentIndex, children: _pages),
                      ),
                      bottomNavigationBar: _GlassBottomNav(
                        currentIndex: _currentIndex,
                        isAddMenuOpen: _isAddMenuOpen,
                        onTap: (i) => setState(() => _currentIndex = i),
                        onAddTap: _toggleAddMenu,
                      ),
                    ),
                  ),
                  // Explicit scrim so the push-back is *guaranteed* visible,
                  // instead of relying on the bottom sheet's own barrier
                  // (which is drawn in a separate layer above this whole
                  // page and was masking the effect).
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
        _buildQuickAddMenu(),
      ],
    );
  }
}

// ============================================================================
// DASHBOARD PAGE
// ============================================================================
class DashboardPage extends StatefulWidget {
  // Notifies HomePage when the Overview filter sheet opens/closes, so the
  // whole screen (app bar + bottom nav included) can do the push-back
  // animation -- not just this page's own content.
  final ValueChanged<bool>? onFilterSheetOpenChanged;

  const DashboardPage({super.key, this.onFilterSheetOpenChanged});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _dashboardService = DashboardService();
  bool _isLoading = true;
  String _selectedPeriod = 'Last 24 Hours';
  DateTimeRange? _customRange;

  static const Color _kDashAccent = Color(0xFF4F46E5);
  static const Color _kDashAccentBg = Color(0xFFEEF0FE);
  static const Color _kBorder = Color(0xFFE7E9ED);
  static const Color _kMuted = Color(0xFF8A8F9A);
  static const Color _kInk = Color(0xFF15171C);

  static const List<String> _periodOptions = [
    'Last 24 Hours',
    '1 Week',
    '1 Month',
    '1 Year',
    'Custom Date',
  ];

  double _salesAmt = 0, _purchAmt = 0, _custOut = 0, _vendOut = 0, _payables = 0, _receivables = 0, _stockVal = 0;
  int _salesQty = 0, _purchQty = 0, _stockQty = 0;

  @override
  void initState() {
    super.initState();
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

  // ---- compact filter bottom sheet, styled after PurchaseScreen's
  // _showFilterSheet (ChoiceChips) instead of the old full-width dropdown ----
  void _showPeriodFilterSheet() {
    // Kick off the push-back animation on HomePage right away, before the
    // sheet finishes animating in, so it reads as one continuous motion.
    widget.onFilterSheetOpenChanged?.call(true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // HomePage now renders its own scrim synced to the push-back
      // animation, so the sheet's default barrier is turned off here to
      // avoid double-darkening (and to stop it from masking the effect).
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
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('Filter Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kInk)),
              const SizedBox(height: 20),
              const Text('DATE RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _periodOptions.map((label) {
                  final isSelected = _selectedPeriod == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: _kDashAccent,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? _kDashAccent : _kBorder),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : _kInk,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (selected) async {
                      if (!selected) return;
                      if (label == 'Custom Date') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _customRange = picked;
                            _selectedPeriod = 'Custom Date';
                          });
                          if (context.mounted) Navigator.pop(context);
                          _fetchData();
                        }
                      } else {
                        setState(() {
                          _selectedPeriod = label;
                          _customRange = null;
                        });
                        Navigator.pop(context);
                        _fetchData();
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Sheet closed (any way -- selection, custom-date picker, or swipe
      // dismiss) -- animate the screen back to its normal size.
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110), // extra bottom space for floating glass nav
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
                        _selectedPeriod,
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

class AddNewContentPage extends StatelessWidget {
  const AddNewContentPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: Text('Add New Content'));
}

// ============================================================================
// QUICK-ADD SPEED-DIAL DATA + BUTTON
// ============================================================================
class _QuickAddOption {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
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
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                option.label,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: option.color, shape: BoxShape.circle),
                child: Icon(option.icon, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FLOATING LIQUID-GLASS BOTTOM NAV
// ============================================================================
class _GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isAddMenuOpen;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const _GlassBottomNav({
    required this.currentIndex,
    required this.isAddMenuOpen,
    required this.onTap,
    required this.onAddTap,
  });

  static const List<_NavItemData> _items = [
    _NavItemData(index: 0, icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItemData(index: 1, icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Receivables'),
    _NavItemData(index: 3, icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Sales'),
    _NavItemData(index: 4, icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Payables'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _GlassPill(currentIndex: currentIndex, onTap: onTap, items: _items),
            ),
            const SizedBox(width: 12),
            _GlassAddButton(isSelected: isAddMenuOpen, onTap: onAddTap),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({required this.index, required this.icon, required this.activeIcon, required this.label});
}

class _GlassPill extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItemData> items;

  const _GlassPill({required this.currentIndex, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final selectedPos = items.indexWhere((e) => e.index == currentIndex);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF15171C).withValues(alpha: 0.85), // dark ink glass, not white
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: selectedPos >= 0 ? itemWidth * selectedPos + 6 : 0,
                    top: 6,
                    bottom: 6,
                    width: itemWidth - 12,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: selectedPos >= 0 ? 1 : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15), // frosted highlight pill on dark glass
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: items.map((item) {
                      final selected = item.index == currentIndex;
                      return SizedBox(
                        width: itemWidth,
                        height: 64,
                        child: InkWell(
                          onTap: () => onTap(item.index),
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  selected ? item.activeIcon : item.icon,
                                  key: ValueKey(selected),
                                  size: 22,
                                  // Light icons/text on dark glass -- inverted from the light variant
                                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlassAddButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassAddButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4F46E5).withValues(alpha: isSelected ? 0.38 : 0.24),
                  const Color(0xFF9333EA).withValues(alpha: isSelected ? 0.38 : 0.24),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1), // was alpha: 0.4
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: isSelected ? 0.22 : 0.12),
                  blurRadius: isSelected ? 16 : 10,
                  spreadRadius: isSelected ? 1 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 250),
              turns: isSelected ? 0.125 : 0,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}