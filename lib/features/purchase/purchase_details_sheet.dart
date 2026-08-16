import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sas_akount_login/core/services/pdf_service.dart';
import 'package:sas_akount_login/features/purchase/purchase_screen.dart' show DateUtil;

// --- PALETTE -------------------------------------------------------
const _kInk = Color(0xFF15171C);
const _kBg = Color(0xFFF6F7F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE7E9ED);
const _kMuted = Color(0xFF8A8F9A);
const _kText = Color(0xFF1E2025);

// Purchase accent — reserved for TOTAL, the export action, and copy
// affordances. Matches purchase_screen.dart so list → detail feels
// like one continuous screen.
const _kPurchaseAccent = Color(0xFF0C447C);

const _kPaid = Color(0xFF1E8E5A);
const _kPaidBg = Color(0xFFE6F5EE);
const _kPending = Color(0xFFB8860B);
const _kPendingBg = Color(0xFFFBF1DC);
const _kOverdue = Color(0xFFD64545);
const _kOverdueBg = Color(0xFFFBE8E8);

class PurchaseDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> purchaseData;

  const PurchaseDetailsSheet({super.key, required this.purchaseData});

  String _formatCurrency(String amount) {
    double parsed = double.tryParse(amount) ?? 0.0;
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parsed.toStringAsFixed(2).replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  Map<String, dynamic>? _getStatus(dynamic item) {
    final raw = (item['paymentStatus'] ?? item['Status'] ?? '').toString().toLowerCase();
    if (raw.contains('overdue')) return {'label': 'OVERDUE', 'color': _kOverdue, 'bg': _kOverdueBg};
    if (raw.contains('pending') || raw.contains('due')) return {'label': 'PENDING', 'color': _kPending, 'bg': _kPendingBg};
    if (raw.contains('paid')) return {'label': 'PAID', 'color': _kPaid, 'bg': _kPaidBg};
    return null;
  }

  void _exportToPdf(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Generating PDF...'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kPurchaseAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    try {
      final vendorName = (purchaseData['supplierName'] ?? purchaseData['LedgerName'] ?? 'Unknown Vendor').toString().replaceAll('\n', ' ').trim();
      final voucherNo = purchaseData['VoucherID']?.toString() ?? 'N/A';
      final dateStr = DateUtil.formatDate(purchaseData['VoucherDate']?.toString());
      final totalAmount = purchaseData['totalAmount']?.toString() ?? purchaseData['GrandTotal']?.toString() ?? '0.00';

      final List<dynamic> items = purchaseData['items'] is List ? purchaseData['items'] : [];
      final List<List<String>> tableData = items.map((item) {
        final itemName = item['productName']?.toString() ?? item['ItemName']?.toString() ?? 'N/A';
        final qty = item['Qty']?.toString() ?? '0';
        final rate = item['Rate']?.toString() ?? '0.00';
        final amt = item['amount']?.toString() ?? item['NetAmount']?.toString() ?? '0.00';
        return [itemName, qty, 'Rs. ${_formatCurrency(rate)}', 'Rs. ${_formatCurrency(amt)}'];
      }).toList();

      await PdfService.generateAndShareGenericDocument(
        documentTitle: 'Purchase Invoice',
        entityLabel: 'Supplier:',
        entityName: vendorName,
        referenceLabel: 'Voucher No:',
        referenceNumber: voucherNo,
        dateLabel: 'Date:',
        dateValue: dateStr,
        tableHeaders: const ['Product', 'Quantity', 'Rate', 'Amount'],
        tableData: tableData,
        totalAmount: _formatCurrency(totalAmount),
      );

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: _kOverdue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorName = (purchaseData['supplierName'] ?? purchaseData['LedgerName'] ?? 'Unknown Vendor').toString().replaceAll('\n', ' ').trim();
    final voucherNo = purchaseData['VoucherID']?.toString() ?? 'N/A';
    final billNo = purchaseData['invoiceNumber'] ?? purchaseData['billNo']?.toString() ?? 'N/A';
    final remarks = purchaseData['remarks']?.toString() ?? purchaseData['narration']?.toString();

    final dateStr = DateUtil.formatDate(purchaseData['VoucherDate']?.toString() ?? purchaseData['voucherDate']?.toString());
    final timeStr = DateUtil.formatTime(purchaseData['VoucherTime']?.toString() ?? purchaseData['voucherTime']?.toString());

    final totalAmount = purchaseData['totalAmount']?.toString() ?? purchaseData['GrandTotal']?.toString() ?? '0.00';

    final List<dynamic> items = purchaseData['items'] is List ? purchaseData['items'] : [];
    final List<dynamic> terms = purchaseData['terms'] is List ? purchaseData['terms'] : [];

    final status = _getStatus(purchaseData);

    double subtotal = 0;
    for (final item in items) {
      final raw = item['amount'] ?? item['NetAmount'] ?? 0;
      subtotal += double.tryParse(raw.toString()) ?? 0;
    }

    final double total = double.tryParse(totalAmount) ?? subtotal;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // --- DRAG HANDLE ---
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              // --- CLOSE BUTTON ROW ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, size: 18, color: _kInk),
                      ),
                    ),
                  ],
                ),
              ),

              // --- THE RECEIPT ---
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    ClipPath(
                      clipper: _ReceiptClipper(),
                      child: Container(
                        width: double.infinity,
                        color: _kCard,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- HEADER & STATUS ---
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                const Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'PURCHASE RECEIPT',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 2),
                                  ),
                                ),
                                if (status != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: status['bg'], borderRadius: BorderRadius.circular(4)),
                                      child: Text(status['label'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: status['color'], letterSpacing: 0.5)),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                vendorName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                  letterSpacing: -0.2,
                                  height: 1.25,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            const _DashedLine(),
                            const SizedBox(height: 14),

                            // --- BILL META ---
                            _CopyableMetaRow(label: 'Voucher No.', value: voucherNo),
                            const SizedBox(height: 6),
                            _CopyableMetaRow(label: 'Supplier Bill', value: billNo),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 80, child: Text('Date', style: TextStyle(fontSize: 12.5, color: _kMuted))),
                                Expanded(child: Text(timeStr.isNotEmpty ? '$dateStr $timeStr' : dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 80, child: Text('Items', style: TextStyle(fontSize: 12.5, color: _kMuted))),
                                Expanded(child: Text('${items.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText))),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const _DashedLine(),
                            const SizedBox(height: 14),

                            // --- ITEM TABLE HEADER ---
                            const Row(
                              children: [
                                Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.6))),
                                SizedBox(width: 30, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.6))),
                                Expanded(flex: 3, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.6))),
                                SizedBox(width: 10),
                                Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.6))),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // --- ITEM ROWS ---
                            if (items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: Text('No line items recorded', style: TextStyle(color: _kMuted, fontSize: 13))),
                              )
                            else
                              ...items.map((item) {
                                final itemName = item['productName']?.toString() ?? item['ItemName']?.toString() ?? 'Unknown Item';
                                final qty = item['Qty']?.toString() ?? '0';
                                final rate = item['Rate']?.toString() ?? '0.00';
                                final amount = item['amount']?.toString() ?? item['NetAmount']?.toString() ?? '0.00';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ),
                                      SizedBox(
                                        width: 30,
                                        child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(_formatCurrency(rate), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _formatCurrency(amount),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 8),
                            const _DashedLine(),
                            const SizedBox(height: 14),

                            // --- DYNAMIC TOTALS BREAKDOWN ---
                            _TotalsRow(label: 'Subtotal', value: 'Rs. ${_formatCurrency(subtotal.toString())}'),
                            const SizedBox(height: 6),

                            if (terms.isNotEmpty)
                              ...terms.map((t) {
                                final tName = t['TermName']?.toString() ?? t['termName']?.toString() ?? 'Adjustment';
                                final tRate = double.tryParse(t['Rate']?.toString() ?? t['rate']?.toString() ?? '0') ?? 0.0;
                                final tAmt = double.tryParse(t['Amount']?.toString() ?? t['amount']?.toString() ?? '0') ?? 0.0;
                                final sign = t['Sign']?.toString() ?? t['sign']?.toString() ?? '+';

                                if (tAmt == 0) return const SizedBox.shrink();

                                String displayLabel = tName;
                                if (tRate > 0) {
                                  String rateStr = tRate == tRate.truncateToDouble() ? tRate.toInt().toString() : tRate.toString();
                                  displayLabel = '$tName ($rateStr%)';
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _TotalsRow(
                                    label: displayLabel,
                                    value: '${sign == '-' ? '-' : '+'} Rs. ${_formatCurrency(tAmt.toString())}',
                                  ),
                                );
                              }),

                            const SizedBox(height: 10),
                            const _DashedLine(),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: 0.5)),
                                // TOTAL amount tinted slate blue — matches the summary strip on the list screen.
                                Text('Rs. ${_formatCurrency(total.toString())}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kPurchaseAccent)),
                              ],
                            ),

                            // --- OPTIONAL REMARKS ---
                            if (remarks != null && remarks.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('NOTES / REMARKS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _kMuted, letterSpacing: 0.5)),
                                    const SizedBox(height: 4),
                                    Text(remarks, style: const TextStyle(fontSize: 12.5, color: _kText, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            const _DashedLine(),
                            const SizedBox(height: 16),

                            // --- FOOTER MESSAGE ---
                            const Center(
                              child: Text('Thank you for your business', style: TextStyle(fontSize: 11, color: _kMuted, fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- STICKY EXPORT ACTION ---
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                decoration: const BoxDecoration(color: _kBg),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _exportToPdf(context),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                      label: const Text('Export PDF & Share', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPurchaseAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _CopyableMetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyableMetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12.5, color: _kMuted))),
        Expanded(
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied "$value" to clipboard'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.copy_rounded, size: 12, color: _kPurchaseAccent.withValues(alpha: 0.55)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final String value;
  const _TotalsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _kMuted)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(size: Size(constraints.maxWidth, 1), painter: _DashedLinePainter());
        },
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    final paint = Paint()..color = _kBorder..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReceiptClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double notch = 8;
    final path = Path();
    path.lineTo(0, size.height - notch);
    double x = 0;
    bool up = true;
    while (x < size.width) {
      final nextX = (x + notch).clamp(0, size.width).toDouble();
      path.lineTo(nextX, up ? size.height : size.height - notch);
      up = !up;
      x = nextX;
    }
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}