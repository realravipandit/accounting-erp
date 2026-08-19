import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👉 REQUIRED FOR TRANSPARENT SYSTEM BAR
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shimmer/shimmer.dart';

import 'package:sas_akount_login/services/dashboard/dashboard_service.dart';
import 'package:sas_akount_login/features/sales/sale_screen.dart';
import 'package:sas_akount_login/shared/widgets/custom_drawer.dart';
import 'package:sas_akount_login/features/purchase/purchase_screen.dart';
import 'package:sas_akount_login/features/receivable/receivable_screen.dart';
import 'package:sas_akount_login/features/payable/payable_screen.dart';
import 'package:sas_akount_login/features/reports/outstanding_screen.dart';
import 'package:sas_akount_login/core/services/sync_service.dart';
import 'package:sas_akount_login/features/inventory/inventory_screen.dart';
import 'package:sas_akount_login/features/reports/ageing_screen.dart';

// ============================================================================
// HOME PAGE
// ============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _isSyncing = false;
  String _companyName = 'Dashboard';
  final _syncService = SyncService();

  final _pages = const [
    DashboardPage(),
    ReceivableScreen(),
    AddNewContentPage(),
    SaleScreen(),
    PayableScreen(),
  ];

  @override
  void initState() {
    super.initState();
    const FlutterSecureStorage().read(key: 'selected_company_name').then((val) {
      if (val != null && mounted) setState(() => _companyName = val);
    });
  }

  Future<void> _onSyncPressed() async {
    setState(() => _isSyncing = true);
    await _syncService.syncAll();
    if (!mounted) return;
    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    // 👉 FIX 1: AnnotatedRegion forces Android to drop the white system background
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

// ============================================================================
// DASHBOARD PAGE
// ============================================================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _dashboardService = DashboardService();

  bool _isLoading = true;
  String _selectedPeriod = 'Last 24 Hours';
  DateTimeRange? _customRange;

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
        decoration: BoxDecoration(color: c.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.15), width: 1.5)),
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
      color: const Color(0xFF4F46E5),
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110), // extra bottom space for floating glass nav
        child: _isLoading
            ? _buildSkeletonLoader()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonHideUnderline(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: DropdownButton<String>(
              value: _selectedPeriod, isExpanded: true, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
              items: ['Last 24 Hours', '1 Week', '1 Month', '1 Year', 'Custom Date'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) async {
                if (v == 'Custom Date') {
                  final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() { _customRange = picked; _selectedPeriod = 'Custom Date'; _fetchData(); });
                } else if (v != null) setState(() { _selectedPeriod = v; _customRange = null; _fetchData(); });
              },
            ),
          )),
          const SizedBox(height: 24),
          const Text('Overview', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
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
// FLOATING LIQUID-GLASS BOTTOM NAV
// ============================================================================
class _GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassBottomNav({required this.currentIndex, required this.onTap});

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
            _GlassAddButton(isSelected: currentIndex == 2, onTap: () => onTap(2)),
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
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
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
                          color: Colors.white.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
                          boxShadow: [
                            BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 14, spreadRadius: 1),
                          ],
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
                                  color: selected ? const Color(0xFF312E81) : const Color(0xFF1F2937).withOpacity(0.75),
                                  shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
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
                                  color: selected ? const Color(0xFF312E81) : const Color(0xFF1F2937).withOpacity(0.75),
                                  shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
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
                  const Color(0xFF4F46E5).withOpacity(isSelected ? 0.38 : 0.24),
                  const Color(0xFF9333EA).withOpacity(isSelected ? 0.38 : 0.24),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(isSelected ? 0.22 : 0.12),
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