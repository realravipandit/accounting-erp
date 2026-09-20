import 'package:flutter/material.dart';
import 'package:sas_app/models/purchase/purchase_order_model.dart';
import 'package:sas_app/services/purchase/purchase_order_service.dart';
import 'package:sas_app/services/sales/pos_sales_service.dart';
import 'package:sas_app/core/services/pdf_service.dart';
import 'package:sas_app/core/services/pdf/templates/purchase_order_pdf.dart';
import 'package:sas_app/shared/widgets/pdf_preview_screen.dart';

// ============================================================================
// PURCHASE ORDER DETAIL SCREEN
// Takes just the orderNumber and fetches GET /purchase-order/:orderId.
// ============================================================================

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String orderNumber;

  const PurchaseOrderDetailScreen({super.key, required this.orderNumber});

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  final _service = PurchaseOrderService();

  static const Color _kInk = Color(0xFF0F172A);
  static const Color _kMuted = Color(0xFF6B7280);
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kAccent = Color(0xFF3B82F6); // placeholder Purchase Blue
  static const Color _kApproved = Color(0xFF10B981);
  static const Color _kPending = Color(0xFFF59E0B);
  static const Color _kDeduct = Color(0xFFDC2626);
  static const Color _kDeductOnDark = Color(0xFFFCA5A5);

  bool _isLoading = true;
  PurchaseOrderDetail? _detail;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    PurchaseOrderDetail? detail;
    try {
      final data = await _service.fetchPurchaseOrderById(widget.orderNumber);
      if (data.isNotEmpty) detail = PurchaseOrderDetail.fromJson(data);
    } catch (e) {
      debugPrint('PO detail error: $e');
    }
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day}  ${months[d.month]}  ${d.year}';
  }

  // e.g. purchaseorder_PO-000004.pdf
  String get _pdfFileName {
    final safeOrder = widget.orderNumber.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return 'purchaseorder_$safeOrder.pdf';
  }

  String _qtyText(double q, {int decimals = 1}) {
    return q.toStringAsFixed(q.truncateToDouble() == q ? 0 : decimals);
  }

  String _signedMoney(PurchaseOrderTerm t) {
    return '${t.isDeduction ? '-' : '+'} Rs. ${t.amount.toStringAsFixed(2)}';
  }

  Future<Map<String, dynamic>> _buildOrderPdfData() async {
    final detail = _detail;
    if (detail == null) {
      throw Exception('Order data not loaded.');
    }
    final order = detail.order;

    Map<String, dynamic> companyInfo = {};
    try {
      companyInfo = await PosSalesService().fetchActiveCompanyProfile();
    } catch (_) {
      // Falls back to PurchaseOrderPdf's own placeholder if this fails.
    }

    final items = List.generate(detail.lineItems.length, (i) {
      final item = detail.lineItems[i];
      return {
        'sno': i + 1,
        'itemName': item.productName,
        'unit': item.unitCode,
        'qty': _qtyText(item.quantity, decimals: 2),
        'rate': item.unitPrice.toStringAsFixed(2),
        'termAmount': item.termTotal.toStringAsFixed(2),
        'amount': item.lineTotal.toStringAsFixed(2),
      };
    });

    final billTerms = detail.billTerms
        .map((t) => {
              'name': t.label,
              'amount': t.signedAmount.toStringAsFixed(2),
            })
        .toList();

    return {
      'companyInfo': companyInfo,
      'orderNumber': order.orderNumber,
      'orderDate': _formatDate(order.orderDate),
      'miti': order.miti,
      'vendorName': order.vendorName,
      'vendorAddress': order.vendorAddress,
      'vendorPan': order.vendorPan,
      'status': order.isApproved ? 'Approved' : 'Pending',
      'basicAmount': detail.basicAmount.toStringAsFixed(2),
      'netAmount': order.total.toStringAsFixed(2),
      'remarks': detail.remarks,
      'items': items,
      'billTerms': billTerms,
    };
  }

  void _previewPdf(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Preparing preview...'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    try {
      final orderData = await _buildOrderPdfData();
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              transactionData: const {},
              invoiceType: '',
              title: 'Purchase Order Preview',
              fileName: _pdfFileName,
              pdfBuilder: (format) => PurchaseOrderPdf.generate(orderData),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate preview: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _exportToPdf(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Generating PDF...'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    try {
      final orderData = await _buildOrderPdfData();
      final bytes = await PurchaseOrderPdf.generate(orderData);
      await PdfService.sharePdfBytes(bytes, fileName: _pdfFileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _summaryRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white70)),
          ),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  // One muted icon + text line under the vendor name (address / PAN).
  Widget _vendorInfoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: _kMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: _kMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _detail?.order;
    final statusColor = order != null ? (order.isApproved ? _kApproved : _kPending) : _kMuted;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.orderNumber,
          style: const TextStyle(color: _kInk, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? _ErrorState(onRetry: _fetchDetail)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // --- Header summary card ---
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorder, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  order!.vendorName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  order.isApproved ? 'Approved' : 'Pending',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          // Vendor details --- blank values are not shown.
                          if (order.vendorAddress.isNotEmpty)
                            _vendorInfoLine(Icons.location_on_outlined, order.vendorAddress),
                          if (order.vendorPan.isNotEmpty)
                            _vendorInfoLine(Icons.badge_outlined, 'PAN/VAT: ${order.vendorPan}'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 13, color: _kMuted),
                              const SizedBox(width: 6),
                              Text('Ordered ${_formatDate(order.orderDate)}', style: const TextStyle(fontSize: 13, color: _kMuted)),
                            ],
                          ),
                          if (_detail!.remarks.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(color: _kBorder, height: 1),
                            const SizedBox(height: 10),
                            Text(
                              _detail!.remarks,
                              style: const TextStyle(fontSize: 12.5, color: _kMuted, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text('Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.4)),
                    ),
                    // --- Line items (with item-wise terms) ---
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _kBorder, width: 1),
                      ),
                      child: Column(
                        children: List.generate(_detail!.lineItems.length, (i) {
                          final item = _detail!.lineItems[i];
                          final isLast = i == _detail!.lineItems.length - 1;
                          final qtyText = _qtyText(item.quantity);
                          final unitSuffix = item.unitCode.isNotEmpty ? ' ${item.unitCode}' : '';
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: isLast ? null : const Border(bottom: BorderSide(color: _kBorder, width: 1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _kAccent.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        qtyText,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kAccent),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kInk),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$qtyText$unitSuffix × Rs. ${item.unitPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 12.5, color: _kMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Rs. ${item.lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk),
                                    ),
                                  ],
                                ),
                                if (item.itemTerms.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 48),
                                    child: Column(
                                      children: item.itemTerms.map((t) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(t.label, style: const TextStyle(fontSize: 12, color: _kMuted)),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                _signedMoney(t),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: t.isDeduction ? _kDeduct : _kMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // --- Total summary ---
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _kInk,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          if (_detail!.billTerms.isNotEmpty) ...[
                            _summaryRow('Basic Amount', 'Rs. ${_detail!.basicAmount.toStringAsFixed(2)}'),
                            ..._detail!.billTerms.map(
                              (t) => _summaryRow(
                                t.label,
                                _signedMoney(t),
                                valueColor: t.isDeduction ? _kDeductOnDark : Colors.white,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Colors.white24, height: 1, thickness: 1),
                            ),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
                              Text(
                                'Rs. ${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _detail == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _previewPdf(context),
                          icon: const Icon(Icons.visibility_outlined, size: 19),
                          label: const Text('Preview', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kAccent,
                            side: const BorderSide(color: _kAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _exportToPdf(context),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                          label: const Text('Export PDF & Share', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("Couldn't load this order", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}