import 'package:flutter/material.dart';
import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/models/receivable.dart';
import 'package:sas_akount_login/utils/pdf_service.dart';

class ReceivableScreen extends StatefulWidget {
  const ReceivableScreen({super.key});
  @override
  _ReceivableScreenState createState() => _ReceivableScreenState();
}

class _ReceivableScreenState extends State<ReceivableScreen> {
  late Future<List<Receivable>> _futureData;
  final _apiService = ApiService();
  final Color _themeColor = const Color(0xFF10B981); // Emerald Green

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() => setState(() {
    _futureData = _apiService.fetchReceivables().then((data) => data.map((j) => Receivable.fromMap(j)).toList());
  });

  void _showReceivableDetails(BuildContext context, Receivable item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ReceivableDetailsSheet(item: item, themeColor: _themeColor);
      },
    );
  }

  Widget _buildCard(Receivable item) {
    final title = item.customerName ?? 'Unknown Customer';
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
          onTap: () => _showReceivableDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _themeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.arrow_downward_rounded, color: _themeColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('TO RECEIVE', style: TextStyle(color: _themeColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: item.receivableAmount ?? 0.0),
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
        title: const Text('Account Receivables', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: _themeColor), onPressed: _loadData)],
      ),
      body: FutureBuilder<List<Receivable>>(
        future: _futureData,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _themeColor));
          if (snap.hasError) return _buildStateInfo(Icons.error_outline_rounded, const Color(0xFFEF4444), 'Error Loading Data', snap.error.toString());
          if (!snap.hasData || snap.data!.isEmpty) return _buildStateInfo(Icons.check_circle_outline_rounded, const Color(0xFF9CA3AF), 'All Clear!', 'No outstanding receivables.');

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

class ReceivableDetailsSheet extends StatelessWidget {
  final Receivable item;
  final Color themeColor;

  const ReceivableDetailsSheet({super.key, required this.item, required this.themeColor});

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
                  'Receivables Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            _buildDetailRow('Customer Name', item.customerName),
            _buildDetailRow('Ledger ID', item.id),
            _buildDetailRow('Total Receivable', 'Rs. ${item.receivableAmount?.toStringAsFixed(2) ?? '0.00'}', isHighlight: true, color: themeColor),
            
            const SizedBox(height: 16),
            const Text('Pending Transactions Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: item.transactions.isEmpty 
                  ? const Center(child: Text('No details available.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: item.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = item.transactions[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Voucher: ${tx.voucherId ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('Rs. ${tx.amount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
                label: const Text('Download & Share Details', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _shareReceivableDetails(context, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReceivableDetails(BuildContext context, Receivable item) async {
    try {
      final reportData = item.transactions.map((tx) => {
        'Voucher': tx.voucherId ?? 'N/A',
        'Amount': 'Rs. ${tx.amount?.toStringAsFixed(2) ?? '0.00'}',
      }).toList();

      await PdfService.generateAndShareReport(
        title: 'Receivables Statement: ${item.customerName}',
        headers: ['Voucher', 'Amount'],
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