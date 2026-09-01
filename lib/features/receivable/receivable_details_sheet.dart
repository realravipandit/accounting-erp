import 'package:flutter/material.dart';
import 'package:sas_app/models/receivable/receivable.dart';
import 'package:sas_app/core/services/pdf_service.dart';

// ------------------------------------------------------------------
// MODULAR FILE — self-contained. Only depends on Receivable + PdfService,
// keeps its own copy of the palette. Edit freely without touching
// receivable_screen.dart, which only knows about
// ReceivableDetailsSheet(item).
// ------------------------------------------------------------------

const _kInk = Color(0xFF15171C);
const _kBg = Color(0xFFF6F7F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE7E9ED);
const _kMuted = Color(0xFF8A8F9A);
const _kText = Color(0xFF1E2025);
const _kOverdue = Color(0xFFD64545);
const _kAccent = Color(0xFF0F6E56); // Receivable / money in

class ReceivableDetailsSheet extends StatelessWidget {
  final Receivable item;

  const ReceivableDetailsSheet({super.key, required this.item});

  Future<void> _shareReceivableDetails(BuildContext context) async {
    try {
      final reportData = item.transactions.map((tx) => {
            'Voucher': tx.voucherId ?? 'N/A',
            'Amount': 'Rs. ${tx.amount?.toStringAsFixed(2) ?? '0.00'}',
          }).toList();

      await PdfService.generateAndShareReport(
        title: 'Receivables Statement: ${item.customerName}',
        headers: const ['Voucher', 'Amount'],
        data: reportData,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
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
    final title = item.customerName ?? 'Unknown Customer';
    final total = item.receivableAmount ?? 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(color: _kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              // DRAG HANDLE
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                child: Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(10)))),
              ),

              // CLOSE
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

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    // --- SUMMARY CARD ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                            child: const Text('CUSTOMER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                          ),
                          const SizedBox(height: 10),
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('ID: ${item.id ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
                          const SizedBox(height: 14),
                          Text('TOTAL RECEIVABLE', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text('Rs. ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- TRANSACTIONS BREAKDOWN ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 2),
                      child: Text('PENDING TRANSACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
                    ),
                    Container(
                      decoration: BoxDecoration(color: _kCard, border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(14)),
                      child: item.transactions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('No details available', style: TextStyle(color: _kMuted, fontSize: 13.5))),
                            )
                          : Column(
                              children: List.generate(item.transactions.length, (i) {
                                final tx = item.transactions[i];
                                final isLast = i == item.transactions.length - 1;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Voucher ${tx.voucherId ?? 'N/A'}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _kText)),
                                          Text('Rs. ${tx.amount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
                                        ],
                                      ),
                                    ),
                                    if (!isLast) Container(height: 1, margin: const EdgeInsets.only(left: 14), color: _kBorder),
                                  ],
                                );
                              }),
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
                      onPressed: () => _shareReceivableDetails(context),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                      label: const Text('Download & Share Details', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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