import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sas_app/services/inventory/inventory_service.dart';
import 'package:sas_app/models/inventory/inventory.dart';
import 'package:sas_app/core/services/pdf_service.dart';

enum StockFilter { all, lowStock, critical }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<Inventory>> _futureData;
  final _apiService = InventoryService();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  StockFilter _activeFilter = StockFilter.all;

  // --- Design System: Executive Obsidian & Industrial Ochre ---
  static const Color _surface = Colors.white;
  static const Color _canvas = Color(0xFFF8FAFC);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _inkMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  // Status & Brand Tokens
  static const Color _brand = Color(0xFFEA580C);       // Warm Industrial Copper
  static const Color _brandLight = Color(0xFFF97316);  // Tangerine Glow
  static const Color _brandSoft = Color(0xFFFFF7ED);   // Warm Tint
  static const Color _success = Color(0xFF10B981);     // Emerald
  static const Color _warning = Color(0xFFF59E0B);     // Amber
  static const Color _danger = Color(0xFFEF4444);      // Crimson

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureData = _apiService
          .fetchInventory()
          .then((data) => data.map((j) => Inventory.fromMap(j)).toList());
    });
  }

  List<Inventory> _applyFilters(List<Inventory> items) {
    return items.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          (item.itemName ?? '').toLowerCase().contains(_searchQuery) ||
          (item.id?.toString() ?? '').contains(_searchQuery);

      final qty = item.stockQty ?? 0.0;
      bool matchesFilter = true;

      switch (_activeFilter) {
        case StockFilter.lowStock:
          matchesFilter = qty > 0 && qty <= 10;
          break;
        case StockFilter.critical:
          matchesFilter = qty <= 0;
          break;
        case StockFilter.all:
          matchesFilter = true;
          break;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showInventoryDetails(BuildContext context, Inventory item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InventoryDetailsSheet(item: item, brand: _brand),
    );
  }

  // ============================================================
  // EXECUTIVE METRIC HUB
  // ============================================================
  Widget _buildMetricsHub(List<Inventory> items) {
    final totalItems = items.length;
    final totalQty = items.fold<double>(0, (s, i) => s + (i.stockQty ?? 0));
    final totalValuation = items.fold<double>(0, (s, i) => s + (i.totalValue ?? 0));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _brandLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TOTAL ASSET VALUATION',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      '$totalItems SKU Units',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Rs. ',
                  style: TextStyle(
                    color: _brandLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatPreciseValuation(totalValuation),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 14),
          Row(
            children: [
              _metricSubTile(
                icon: Icons.inventory_2_outlined,
                label: 'Physical Stock',
                value: '${totalQty.toStringAsFixed(0)} units',
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              _metricSubTile(
                icon: Icons.shield_outlined,
                label: 'Stock Health',
                value: items.any((i) => (i.stockQty ?? 0) <= 5) ? 'Attention Req.' : 'Optimal',
                valueColor: items.any((i) => (i.stockQty ?? 0) <= 5) ? _warning : _success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricSubTile({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPreciseValuation(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(2)} Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(2)} Lakh';
    return value.toStringAsFixed(2);
  }

  // ============================================================
  // SEARCH & QUICK FILTER PILLS
  // ============================================================
  Widget _buildControlsBar(List<Inventory> allItems) {
    final lowStockCount = allItems.where((i) => (i.stockQty ?? 0) > 0 && (i.stockQty ?? 0) <= 10).length;
    final criticalCount = allItems.where((i) => (i.stockQty ?? 0) <= 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search SKU, item name, reference...',
                hintStyle: const TextStyle(color: _inkMuted, fontSize: 14, fontWeight: FontWeight.w400),
                prefixIcon: const Icon(Icons.search_rounded, color: _inkMuted, size: 21),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: _inkMuted, size: 18),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Filter Segmented Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Items', StockFilter.all, count: allItems.length),
                const SizedBox(width: 8),
                _filterChip(
                  'Low Stock',
                  StockFilter.lowStock,
                  count: lowStockCount,
                  accentOverride: _warning,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Out of Stock',
                  StockFilter.critical,
                  count: criticalCount,
                  accentOverride: _danger,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    StockFilter filter, {
    int? count,
    Color? accentOverride,
  }) {
    final isSelected = _activeFilter == filter;
    final baseColor = accentOverride ?? _brand;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? baseColor : _surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? baseColor : _border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _ink,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : _inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ITEM CARD
  // ============================================================
  Widget _buildCard(Inventory item) {
    final title = item.itemName ?? 'Unnamed Item';
    final id = item.id != null ? '#${item.id}' : 'N/A';
    final qty = item.stockQty ?? 0.0;
    final valuation = item.totalValue ?? 0.0;

    // Status logic
    final bool isZero = qty <= 0;
    final bool isLow = qty > 0 && qty <= 10;

    final Color statusColor = isZero ? _danger : (isLow ? _warning : _success);
    final String statusLabel = isZero ? 'OUT OF STOCK' : (isLow ? 'LOW STOCK' : 'IN STOCK');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showInventoryDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _brandSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _brand.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: _brand, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SKU reference $id',
                            style: const TextStyle(
                              color: _inkMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 16, color: _inkMuted),
                          const SizedBox(width: 6),
                          Text(
                            '${qty.toStringAsFixed(0)} units available',
                            style: TextStyle(
                              color: isZero ? _danger : _ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rs. ${valuation.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY & ERROR STATES
  // ============================================================
  Widget _buildStateScreen({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _inkMuted, fontSize: 13.5, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _border),
        ),
        iconTheme: const IconThemeData(color: _ink),
        title: const Text(
          'Warehouse Inventory',
          style: TextStyle(
            color: _ink,
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _brand),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadData();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Inventory>>(
        future: _futureData,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _brand, strokeWidth: 2.5),
            );
          }
          if (snap.hasError) {
            return _buildStateScreen(
              icon: Icons.cloud_off_rounded,
              color: _danger,
              title: 'Data Stream Interrupted',
              message: snap.error.toString(),
              onRetry: _loadData,
            );
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return _buildStateScreen(
              icon: Icons.inventory_2_outlined,
              color: _inkMuted,
              title: 'Empty Warehouse',
              message: 'No physical stock assets detected in the connected database.',
              onRetry: _loadData,
            );
          }

          final allItems = snap.data!;
          final displayList = _applyFilters(allItems);

          return RefreshIndicator(
            color: _brand,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              _loadData();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildMetricsHub(allItems)),
                SliverToBoxAdapter(child: _buildControlsBar(allItems)),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                displayList.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildStateScreen(
                          icon: Icons.search_off_rounded,
                          color: _inkMuted,
                          title: 'No Matching Stock',
                          message: 'No inventory items correspond with your active filter or search terms.',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildCard(displayList[i]),
                            childCount: displayList.length,
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// DETAILS & AUDIT BREAKDOWN MODAL SHEET
// ============================================================
class InventoryDetailsSheet extends StatelessWidget {
  final Inventory item;
  final Color brand;

  const InventoryDetailsSheet({
    super.key,
    required this.item,
    required this.brand,
  });

  static const Color _ink = Color(0xFF0F172A);
  static const Color _inkMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _canvas = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final qty = item.stockQty ?? 0.0;
    final valuation = item.totalValue ?? 0.0;
    final unitPrice = qty > 0 ? (valuation / qty) : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName ?? 'Unknown Item',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Item Reference ID: ${item.id ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: _inkMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: _inkMuted),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Metrics Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _canvas,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            _summaryBlock('Physical Stock', '${qty.toStringAsFixed(0)} units'),
                            Container(width: 1, height: 32, color: _border),
                            _summaryBlock('Avg Unit Rate', 'Rs. ${unitPrice.toStringAsFixed(2)}'),
                            Container(width: 1, height: 32, color: _border),
                            _summaryBlock(
                              'Valuation',
                              'Rs. ${valuation.toStringAsFixed(2)}',
                              isHighlight: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ledgers & Transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TRANSACTION & VOUCHER AUDIT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: _inkMuted,
                            ),
                          ),
                          Text(
                            '${item.details.length} Records',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (item.details.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          alignment: Alignment.center,
                          child: const Text(
                            'No recorded transactions for this specific line item.',
                            style: TextStyle(color: _inkMuted, fontSize: 13),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: List.generate(item.details.length, (index) {
                              final det = item.details[index];
                              final isLast = index == item.details.length - 1;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: isLast ? null : const Border(bottom: BorderSide(color: _border)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long_rounded,
                                            size: 16,
                                            color: _inkMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Voucher #${det.voucherId ?? 'N/A'}',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: _ink,
                                              ),
                                            ),
                                            Text(
                                              'Qty: ${det.qty?.toStringAsFixed(0) ?? '0'} units',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: _inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Rs. ${det.value?.toStringAsFixed(2) ?? '0.00'}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text(
                            'Generate & Share Stock Report',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _shareReport(context, item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryBlock(String label, String value, {bool isHighlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: _inkMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 13.5 : 13,
              fontWeight: FontWeight.w800,
              color: isHighlight ? brand : _ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReport(BuildContext context, Inventory item) async {
    try {
      final reportData = item.details
          .map((det) => {
                'Voucher': det.voucherId ?? 'N/A',
                'Qty': det.qty?.toStringAsFixed(0) ?? '0',
                'Value': 'Rs. ${det.value?.toStringAsFixed(2) ?? '0.00'}',
              })
          .toList();

      await PdfService.generateAndShareReport(
        title: 'Stock Ledger: ${item.itemName}',
        headers: ['Voucher', 'Qty', 'Value'],
        data: reportData,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF report: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}