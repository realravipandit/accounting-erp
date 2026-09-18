import 'package:flutter/material.dart';
import 'package:sas_app/models/sales/sales_order_model.dart';
import 'package:sas_app/services/sales/sales_order_service.dart';
import 'sales_order_detail_screen.dart';

// ============================================================================
// SALES ORDER LIST SCREEN
//
// Fetches from GET /sales-order via SalesOrderService. Card-based list,
// styled to match the existing dashboard card language.
// ============================================================================

class SalesOrderListScreen extends StatefulWidget {
  const SalesOrderListScreen({super.key});

  @override
  State<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends State<SalesOrderListScreen> {
  final _service = SalesOrderService();

  static const Color _kInk = Color(0xFF0F172A);
  static const Color _kMuted = Color(0xFF6B7280);
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kAccent = Color(0xFF10B981);
  static const Color _kApproved = Color(0xFF10B981);
  static const Color _kPending = Color(0xFFF59E0B);

  bool _isLoading = true;
  List<SalesOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // Note: fetchSalesOrders() returns [] both when there are genuinely no
  // orders and when the request failed (matching DashboardService's
  // fail-soft pattern). The empty state below covers both cases with a
  // retry action --- if you want to distinguish "no orders" from "request
  // failed" later, have the service return a success flag alongside the
  // list and branch on that here instead.
  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    final orders = await _service.fetchSalesOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Sales Orders',
          style: TextStyle(color: _kInk, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: RefreshIndicator(
        color: _kAccent,
        onRefresh: _fetchOrders,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? _EmptyState(onRetry: _fetchOrders)
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final order = _orders[i];
                      final statusColor = order.isApproved ? _kApproved : _kPending;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalesOrderDetailScreen(orderNumber: order.orderNumber),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _kBorder, width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: _kAccent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: const Icon(Icons.receipt_long_rounded, color: _kAccent, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        order.orderNumber,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _kInk),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      order.isApproved ? 'Approved' : 'Pending',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                order.customerName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 12, color: _kMuted),
                                  const SizedBox(width: 5),
                                  Text(_formatDate(order.orderDate), style: const TextStyle(fontSize: 12.5, color: _kMuted)),
                                  const SizedBox(width: 14),
                                  const Icon(Icons.inventory_2_outlined, size: 13, color: _kMuted),
                                  const SizedBox(width: 5),
                                  Text('${order.itemCount} items · Qty ${order.totalQty.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, color: _kMuted)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(color: _kBorder, height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontSize: 12.5, color: _kMuted, fontWeight: FontWeight.w600)),
                                  Text(
                                    'Rs. ${order.total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kInk),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No sales orders found', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextButton(onPressed: onRetry, child: const Text('Pull to refresh, or tap to retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}