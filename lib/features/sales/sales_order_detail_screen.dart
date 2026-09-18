import 'package:flutter/material.dart';
import 'package:sas_app/models/sales/sales_order_model.dart';
import 'package:sas_app/services/sales/sales_order_service.dart';
// ============================================================================
// SALES ORDER DETAIL SCREEN
//
// Takes just the orderNumber and fetches its own data from
// GET /sales-order/:orderId via SalesOrderService --- the list screen no
// longer needs to pass a fully-populated order across the navigation.
// ============================================================================

class SalesOrderDetailScreen extends StatefulWidget {
  final String orderNumber;

  const SalesOrderDetailScreen({super.key, required this.orderNumber});

  @override
  State<SalesOrderDetailScreen> createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  final _service = SalesOrderService();

  static const Color _kInk = Color(0xFF0F172A);
  static const Color _kMuted = Color(0xFF6B7280);
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kAccent = Color(0xFF10B981);
  static const Color _kApproved = Color(0xFF10B981);
  static const Color _kPending = Color(0xFFF59E0B);

  bool _isLoading = true;
  SalesOrderDetail? _detail;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final detail = await _service.fetchSalesOrderDetail(widget.orderNumber);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
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
                                  order!.customerName,
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

                    // --- Line items header ---
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text('Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.4)),
                    ),

                    // --- Line items list ---
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
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: isLast ? null : const Border(bottom: BorderSide(color: _kBorder, width: 1)),
                            ),
                            child: Row(
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
                                    item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1),
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
                                        '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} × Rs. ${item.unitPrice.toStringAsFixed(2)}',
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Order Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
                          Text(
                            'Rs. ${order.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
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