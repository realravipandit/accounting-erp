import 'package:flutter/material.dart';
import 'package:sas_akount_login/services/payable/payable_service.dart';
import 'package:sas_akount_login/models/payable/payable.dart';
import 'package:sas_akount_login/features/payable/payable_details_sheet.dart';

// --- PALETTE (shared with purchase_screen.dart / outstanding_screen.dart) --
const _kInk = Color(0xFF15171C);
const _kBg = Color(0xFFF6F7F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE7E9ED);
const _kMuted = Color(0xFF8A8F9A);
const _kText = Color(0xFF1E2025);
const _kOverdue = Color(0xFFD64545);

// Payable = money going out → same family as Purchases / Outstanding-Vendors.
const _kAccent = Color(0xFF0C447C);

class PayableScreen extends StatefulWidget {
  const PayableScreen({super.key});
  @override
  _PayableScreenState createState() => _PayableScreenState();
}

class _PayableScreenState extends State<PayableScreen> {
  late Future<List<Payable>> _futureData;
  final _apiService = PayableService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _futureData = _apiService.fetchPayables().then((response) {
        final records = response['records'];
        if (records is! List) {
          return <Payable>[];
        }
        return records.map((item) {
          return Payable.fromMap(Map<String, dynamic>.from(item as Map));
        }).toList();
      });
    });
  }

  void _showPayableDetails(BuildContext context, Payable item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PayableDetailsSheet(item: item),
    );
  }

  double _sumTotal(List<Payable> items) {
    double sum = 0;
    for (final i in items) {
      sum += i.payableAmount ?? 0.0;
    }
    return sum;
  }

  Widget _buildSummaryStrip(List<Payable> items) {
    final total = _sumTotal(items);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL PAYABLE', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600, letterSpacing: 0.8)),
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

  Widget _buildRow(Payable item, bool showDivider) {
    final title = item.vendorName ?? 'Unknown Vendor';
    final subtitle = 'ID: ${item.id ?? 'N/A'}';
    final amount = item.payableAmount ?? 0.0;

    return InkWell(
      onTap: () => _showPayableDetails(context, item),
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
                      Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: _kMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('Rs. ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kAccent)),
              ],
            ),
          ),
          if (showDivider) Container(height: 1, margin: const EdgeInsets.only(left: 14), color: _kBorder),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('Payables', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.4)),
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

            // --- CONTENT ---
            Expanded(
              child: FutureBuilder<List<Payable>>(
                future: _futureData,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: _kAccent)));
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
                                style: ElevatedButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 44, color: Colors.grey[300]),
                          const SizedBox(height: 14),
                          const Text('All clear', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
                          const SizedBox(height: 6),
                          const Text('No outstanding payables', style: TextStyle(color: _kMuted, fontSize: 13.5)),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: _kAccent,
                    onRefresh: () async => _loadData(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                      children: [
                        _buildSummaryStrip(items),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(color: _kCard, border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              children: List.generate(items.length, (i) {
                                final isLast = i == items.length - 1;
                                return _buildRow(items[i], !isLast);
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}