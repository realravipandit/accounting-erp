import 'package:flutter/material.dart';

class VoucherDetailsScreen extends StatefulWidget {
  final String voucherId;

  const VoucherDetailsScreen({super.key, required this.voucherId});

  @override
  State<VoucherDetailsScreen> createState() => _VoucherDetailsScreenState();
}

class _VoucherDetailsScreenState extends State<VoucherDetailsScreen> {
  // Replace this with your actual model class for Voucher Items
  late Future<List<dynamic>> _voucherItemsFuture; 

  @override
  void initState() {
    super.initState();
    _loadVoucherDetails();
  }

  void _loadVoucherDetails() {
    // TODO: Create this method in your ReceivableService or SaleService
    // Example: _voucherItemsFuture = _apiService.fetchVoucherItems(widget.voucherId);
    
    // Mocking an API delay for now so you can test the UI:
    _voucherItemsFuture = Future.delayed(
      const Duration(seconds: 1), 
      () => [
        {'itemName': 'Item A', 'qty': 2, 'price': 150.0},
        {'itemName': 'Item B', 'qty': 1, 'price': 300.0},
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text('Voucher: ${widget.voucherId}', style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _voucherItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final items = snapshot.data ?? [];
          
          if (items.isEmpty) {
            return const Center(child: Text('No items found for this voucher.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: Text(item['itemName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Qty: ${item['qty']}'),
                trailing: Text('Rs. ${item['price']}'),
              );
            },
          );
        },
      ),
    );
  }
}