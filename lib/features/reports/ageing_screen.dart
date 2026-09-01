import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sas_app/services/receivable/receivable_service.dart';
import 'package:sas_app/models/receivable/ageing.dart';
import 'package:sas_app/core/services/pdf_service.dart';

class AgeingScreen extends StatefulWidget {
  const AgeingScreen({super.key});

  @override
  State<AgeingScreen> createState() => _AgeingScreenState();
}

class _AgeingScreenState extends State<AgeingScreen> {
  late Future<List<AgeingAccount>> _futureData;
  final _apiService = ReceivableService();
  final Color _themeColor = const Color(0xFFA855F7); // Purple Theme

  // ---- OLD-SOFTWARE-PARITY FILTER STATE ----
  // Mirrors @BillorDue from Sp_SMCustomerAgeing.
  String _dateBasis = 'bill'; // 'bill' | 'due'
  // Mirrors the SP's 3rd date param -- ageing "as of" a chosen date.
  DateTime _asOfDate = DateTime.now();
  // Mirrors @Slab -- old system's configurable bucket width (was hardcoded
  // to 30 in this screen before).
  int _slab = 30;

  static const List<int> _slabOptions = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      // NOTE: fetchAgeing needs to accept these params and forward them as
      // query params to GET /ageing -- see receivable_service_additions.dart
      _futureData = _apiService
          .fetchAgeing(
        dateBasis: _dateBasis,
        asOfDate: _asOfDate,
        slab: _slab,
      )
          .then((response) {
        final records = response['records'];
        if (records is! List) {
          return <AgeingAccount>[];
        }
        return records.map((item) {
          return AgeingAccount.fromMap(
            Map<String, dynamic>.from(item as Map),
          );
        }).toList();
      });
    });
  }

  Future<void> _pickAsOfDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOfDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _asOfDate = picked);
      _loadData();
    }
  }

  void _showDetails(BuildContext context, AgeingAccount item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AgeingDetailsSheet(item: item, themeColor: _themeColor, slab: _slab);
      },
    );
  }

  // ---- NEW: filter bar restoring old software's Bill/Due toggle, as-of
  // date and configurable slab ----
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE7E9ED)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(child: _basisChip('Bill Date', 'bill')),
                      Expanded(child: _basisChip('Due Date', 'due')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _pickAsOfDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE7E9ED)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 16, color: Color(0xFF8A8F9A)),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy').format(_asOfDate),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E2025)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Slab:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              const SizedBox(width: 8),
              ..._slabOptions.map((s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _slabChip(s),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _basisChip(String label, String value) {
    final selected = _dateBasis == value;
    return InkWell(
      onTap: () {
        if (_dateBasis != value) {
          setState(() => _dateBasis = value);
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF15171C) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF8A8F9A),
          ),
        ),
      ),
    );
  }

  Widget _slabChip(int value) {
    final selected = _slab == value;
    return InkWell(
      onTap: () {
        if (_slab != value) {
          setState(() => _slab = value);
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _themeColor.withValues(alpha: 0.15) : Colors.white,
          border: Border.all(color: selected ? _themeColor : const Color(0xFFE7E9ED)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${value}d',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? _themeColor : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AgeingAccount item) {
    final title = item.name ?? 'Unknown Account';
    final subtitle = 'ID: ${item.id ?? 'N/A'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _themeColor.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _themeColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.access_time_rounded, color: _themeColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TOTAL OVERDUE',
                          style: TextStyle(
                            color: Color(0xFFA855F7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${item.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bucketBadge('0-${_slab}d', item.bucket0_30 ?? 0),
                    _bucketBadge('${_slab + 1}-${_slab * 2}d', item.bucket31_60 ?? 0),
                    _bucketBadge('${_slab * 2 + 1}-${_slab * 3}d', item.bucket61_90 ?? 0),
                    _bucketBadge('${_slab * 3}+d', item.bucket90_plus ?? 0, isDanger: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bucketBadge(String label, double amount, {bool isDanger = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          'Rs. ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDanger && amount > 0 ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTabList(List<AgeingAccount> items, String typeLabel) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            const Text('All Clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('No ageing records found for $typeLabel.', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _themeColor,
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i]),
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
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: const Text(
            'Ageing Report',
            style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(icon: Icon(Icons.refresh_rounded, color: _themeColor), onPressed: _loadData),
          ],
          bottom: TabBar(
            indicatorColor: _themeColor,
            indicatorWeight: 3,
            labelColor: _themeColor,
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Customer Ageing'),
              Tab(text: 'Vendor Ageing'),
            ],
          ),
        ),
        body: Column(
          children: [
            // --- NEW: BILL/DUE DATE, AS-OF-DATE, SLAB FILTER BAR ---
            _buildFilterBar(),
            Expanded(
              child: FutureBuilder<List<AgeingAccount>>(
                future: _futureData,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _themeColor));
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('Error Loading Data: ${snap.error}', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final allItems = snap.data ?? [];
                  final customers = allItems.where((e) => e.type?.toLowerCase() == 'customer').toList();
                  final vendors = allItems.where((e) => e.type?.toLowerCase() == 'vendor').toList();
                  return TabBarView(
                    children: [
                      _buildTabList(customers, 'customers'),
                      _buildTabList(vendors, 'vendors'),
                    ],
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

class AgeingDetailsSheet extends StatelessWidget {
  final AgeingAccount item;
  final Color themeColor;
  final int slab;

  const AgeingDetailsSheet({
    super.key,
    required this.item,
    required this.themeColor,
    this.slab = 30,
  });

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
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ageing Invoice Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Account Name', item.name),
            _buildDetailRow('Total Overdue', 'Rs. ${item.totalAmount?.toStringAsFixed(2) ?? '0.00'}', isHighlight: true, color: themeColor),
            const SizedBox(height: 16),
            const Text('Overdue Invoices:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: item.invoices.isEmpty
                  ? const Center(child: Text('No invoice details available.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: item.invoices.length,
                      itemBuilder: (context, index) {
                        final inv = item.invoices[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Inv: ${inv.invoiceNumber ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${inv.daysOverdue ?? 0} days overdue', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              Text('Rs. ${inv.amount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
                label: const Text('Download & Share Ageing Report', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _shareAgeingReport(context, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAgeingReport(BuildContext context, AgeingAccount item) async {
    try {
      final reportData = item.invoices.map((inv) => {
        'Invoice': inv.invoiceNumber ?? 'N/A',
        'Days Overdue': '${inv.daysOverdue ?? 0}d',
        'Amount': 'Rs. ${inv.amount?.toStringAsFixed(2) ?? '0.00'}',
      }).toList();

      await PdfService.generateAndShareReport(
        title: 'Ageing Report: ${item.name}',
        headers: ['Invoice', 'Days Overdue', 'Amount'],
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
              color: isHighlight ? color : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}