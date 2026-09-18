import 'package:flutter/material.dart';
import 'package:sas_app/features/sales/sale_screen.dart';
import 'package:sas_app/features/purchase/purchase_screen.dart';

// ============================================================================
// TRANSACTIONS SCREEN — combined Sales / Purchases tabs
//
// Backs the "Transactions" bottom-nav tab. Wraps the existing SaleScreen and
// PurchaseScreen unchanged in a TabBarView; no changes to either screen.
// ============================================================================

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const Color _kInk = Color(0xFF0F172A);
  static const Color _kMuted = Color(0xFF9CA3AF);
  static const Color _kBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
       Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
        ),
          child: TabBar(
            controller: _tabController,
            labelColor: _kInk,
            unselectedLabelColor: _kMuted,
            indicatorColor: _kInk,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Sales'),
              Tab(text: 'Purchases'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              SaleScreen(),
              PurchaseScreen(),
            ],
          ),
        ),
      ],
    );
  }
}