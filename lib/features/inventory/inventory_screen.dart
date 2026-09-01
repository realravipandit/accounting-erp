import 'package:flutter/material.dart';
import 'package:sas_app/services/inventory/inventory_service.dart';
import 'package:sas_app/models/inventory/inventory.dart';
import 'package:sas_app/core/services/pdf_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<Inventory>> _futureData;
  final _apiService = InventoryService();
  final Color _themeColor = const Color(0xFF6366F1); // Indigo Theme

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() => setState(() {
    _futureData = _apiService.fetchInventory().then((data) => data.map((j) => Inventory.fromMap(j)).toList());
  });

  void _showInventoryDetails(BuildContext context, Inventory item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return InventoryDetailsSheet(item: item, themeColor: _themeColor);
      },
    );
  }

  Widget _buildCard(Inventory item) {
    final title = item.itemName ?? 'Unknown Item';
    final subtitle = 'ID: ${item.id ?? 'N/A'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: _themeColor.withValues(alpha: 0.15), width: 1.5), 
        boxShadow: [
          BoxShadow(color: _themeColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showInventoryDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _themeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.inventory_2_rounded, color: _themeColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: item.stockQty ?? 0.0),
                  duration: const Duration(milliseconds: 2000), curve: Curves.easeOutExpo,
                  builder: (_, v, __) => Text('Qty: ${v.toStringAsFixed(0)}', style: TextStyle(color: _themeColor, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: item.totalValue ?? 0.0),
                  duration: const Duration(milliseconds: 2000), curve: Curves.easeOutExpo,
                  builder: (_, v, __) => Text('Rs. ${v.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                ),
              ])
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStateInfo(IconData icon, Color color, String title, String subtitle) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 48, color: color)),
      const SizedBox(height: 20), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      const SizedBox(height: 24), ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh'), style: ElevatedButton.styleFrom(backgroundColor: _themeColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)))
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Inventory Status', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: _themeColor), onPressed: _loadData)],
      ),
      body: FutureBuilder<List<Inventory>>(
        future: _futureData,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _themeColor));
          if (snap.hasError) return _buildStateInfo(Icons.error_outline_rounded, const Color(0xFFEF4444), 'Error Loading Data', snap.error.toString());
          if (!snap.hasData || snap.data!.isEmpty) return _buildStateInfo(Icons.check_circle_outline_rounded, const Color(0xFF9CA3AF), 'All Clear!', 'No inventory items in stock.');

          return RefreshIndicator(
            color: _themeColor, onRefresh: () async => _loadData(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
              itemCount: snap.data!.length,
              itemBuilder: (_, i) => _buildCard(snap.data![i]),
            ),
          );
        },
      ),
    );
  }
}

class InventoryDetailsSheet extends StatelessWidget {
  final Inventory item;
  final Color themeColor;

  const InventoryDetailsSheet({super.key, required this.item, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Stock Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            _buildDetailRow('Item Name', item.itemName),
            _buildDetailRow('Item ID', item.id),
            _buildDetailRow('Total Stock Qty', '${item.stockQty?.toStringAsFixed(0) ?? '0'} units'),
            _buildDetailRow('Total Valuation', 'Rs. ${item.totalValue?.toStringAsFixed(2) ?? '0.00'}', isHighlight: true, color: themeColor),
            
            const SizedBox(height: 16),
            const Text('Stock Transactions Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: item.details.isEmpty 
                  ? const Center(child: Text('No transaction details available.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: item.details.length,
                      itemBuilder: (context, index) {
                        final det = item.details[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Voucher: ${det.voucherId ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Qty: ${det.qty?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('Rs. ${det.value?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download & Share Stock Report', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _shareInventoryReport(context, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareInventoryReport(BuildContext context, Inventory item) async {
    try {
      final reportData = item.details.map((det) => {
        'Voucher': det.voucherId ?? 'N/A',
        'Qty': det.qty?.toStringAsFixed(0) ?? '0',
        'Value': 'Rs. ${det.value?.toStringAsFixed(2) ?? '0.00'}',
      }).toList();

      await PdfService.generateAndShareReport(
        title: 'Stock Report: ${item.itemName}',
        headers: ['Voucher', 'Qty', 'Value'],
        data: reportData,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String? value, {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value ?? 'N/A', 
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600, 
              fontSize: isHighlight ? 15 : 13, 
              color: isHighlight ? color : Colors.black87
            )
          ),
        ],
      ),
    );
  }
}
