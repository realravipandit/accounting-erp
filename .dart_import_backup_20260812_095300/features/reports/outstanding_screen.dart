import 'package:flutter/material.dart';
import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/models/outstanding.dart';
import 'package:sas_akount_login/utils/pdf_service.dart';

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key});
  @override
  _OutstandingScreenState createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  late Future<List<Outstanding>> _futureData;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() => setState(() {
    _futureData = _apiService.fetchOutstanding().then((data) => data.map((j) => Outstanding.fromMap(j)).toList());
  });

  void _showOutstandingDetails(BuildContext context, Outstanding item, bool isCust) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return OutstandingDetailsSheet(item: item, isCust: isCust);
      },
    );
  }

  Widget _buildCard(Outstanding item, bool isCust) {
    final c = isCust ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final title = item.name ?? 'Unknown Account';
    final subtitle = 'ID: ${item.id ?? 'N/A'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: c.withValues(alpha: 0.15), width: 1.5), 
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showOutstandingDetails(context, item, isCust),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(isCust ? Icons.person_outline : Icons.business_outlined, color: c, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(isCust ? 'CUSTOMER' : 'VENDOR', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: item.outstandingAmount ?? 0.0),
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

  Widget _buildTabList(List<Outstanding> items, bool isCust) {
    if (items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF9CA3AF).withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 20),
        const Text('All Clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text('No outstanding balances for ${isCust ? 'customers' : 'vendors'}.', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      ]));
    }

    return RefreshIndicator(
      color: const Color(0xFF4F46E5), onRefresh: () async => _loadData(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i], isCust),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0, centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: const Text('Outstanding Balances', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4F46E5)), onPressed: _loadData)],
          bottom: const TabBar(
            indicatorColor: Color(0xFF4F46E5), indicatorWeight: 3,
            labelColor: Color(0xFF4F46E5), unselectedLabelColor: Color(0xFF6B7280),
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: 'Customers'),
              Tab(text: 'Vendors'),
            ],
          ),
        ),
        body: FutureBuilder<List<Outstanding>>(
          future: _futureData,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
            
            if (snap.hasError) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444))),
                const SizedBox(height: 20), const Text('Error Loading Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8), Text(snap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 24), ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white))
              ]));
            }

            final allItems = snap.data ?? [];
            final customers = allItems.where((e) => e.type?.toLowerCase() == 'customer').toList();
            final vendors = allItems.where((e) => e.type?.toLowerCase() == 'vendor').toList();

            return TabBarView(
              children: [
                _buildTabList(customers, true),
                _buildTabList(vendors, false), 
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {}, backgroundColor: const Color(0xFF4F46E5), elevation: 4,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class OutstandingDetailsSheet extends StatelessWidget {
  final Outstanding item;
  final bool isCust;

  const OutstandingDetailsSheet({super.key, required this.item, required this.isCust});

  @override
  Widget build(BuildContext context) {
    final themeColor = isCust ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);

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
                  isCust ? 'Customer Statement' : 'Vendor Statement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            _buildDetailRow('Account Name', item.name),
            _buildDetailRow('Ledger ID', item.id),
            _buildDetailRow('Total Outstanding', 'Rs. ${item.outstandingAmount?.toStringAsFixed(2) ?? '0.00'}', isHighlight: true, color: themeColor),
            
            const SizedBox(height: 16),
            const Text('Unpaid Invoices Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: item.invoices.isEmpty 
                  ? const Center(child: Text('No details available.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: item.invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = item.invoices[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Inv: ${invoice.invoiceNumber ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(invoice.date?.split('T')[0] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                              Text('Rs. ${invoice.amount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
                label: const Text('Download & Share Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _shareOutstandingDetails(context, item, isCust),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareOutstandingDetails(BuildContext context, Outstanding item, bool isCust) async {
    try {
      final reportData = item.invoices.map((inv) => {
        'Invoice No': inv.invoiceNumber ?? 'N/A',
        'Date': inv.date?.split('T')[0] ?? 'N/A',
        'Amount': 'Rs. ${inv.amount?.toStringAsFixed(2) ?? '0.00'}',
      }).toList();

      await PdfService.generateAndShareReport(
        title: '${isCust ? "Customer" : "Vendor"} Outstanding: ${item.name}',
        headers: ['Invoice No', 'Date', 'Amount'],
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