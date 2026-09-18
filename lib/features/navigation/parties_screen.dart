import 'package:flutter/material.dart';
import 'package:sas_app/features/receivable/receivable_screen.dart';
import 'package:sas_app/features/payable/payable_screen.dart';

// ============================================================================
// PARTIES SCREEN — combined Customers / Vendors tabs
//
// Backs the "Parties" bottom-nav tab. Wraps the existing ReceivableScreen
// (customers) and PayableScreen (vendors) unchanged in a TabBarView.
// ============================================================================

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen>
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
              Tab(text: 'Customers'),
              Tab(text: 'Vendors'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              ReceivableScreen(),
              PayableScreen(),
            ],
          ),
        ),
      ],
    );
  }
}