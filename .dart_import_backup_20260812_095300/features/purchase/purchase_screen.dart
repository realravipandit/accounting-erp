import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/models/purchase.dart';
import 'package:sas_akount_login/utils/pdf_service.dart';

enum PurchaseSortOption { newest, oldest, amountHighToLow, amountLowToHigh, supplierAZ }

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  bool _isLoading = true;
  List<Purchase> _purchases = [];
  List<Purchase> _filteredPurchases = [];
  final TextEditingController _searchController = TextEditingController();
  PurchaseSortOption _currentSortOption = PurchaseSortOption.newest;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedData = await ApiService().fetchPurchases();
      final purchaseList = fetchedData.map((json) => Purchase.fromJson(json)).toList();

      if (!mounted) return;
      setState(() {
        _purchases = purchaseList;
        _applyFilterAndSort(_searchController.text);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching purchase records: $e')),
      );
    }
  }

  void _applyFilterAndSort(String query) {
    setState(() {
      List<Purchase> temp = _purchases;
      if (query.isNotEmpty) {
        temp = temp.where((purchase) {
          final supplier = purchase.supplierName?.toLowerCase() ?? '';
          final invoice = purchase.invoiceNumber?.toLowerCase() ?? '';
          return supplier.contains(query.toLowerCase()) || invoice.contains(query.toLowerCase());
        }).toList();
      }

      temp.sort((a, b) {
        final dateA = a.date ?? DateTime(1970);
        final dateB = b.date ?? DateTime(1970);

        switch (_currentSortOption) {
          case PurchaseSortOption.newest:
            int timeComparison = dateB.compareTo(dateA);
            if (timeComparison == 0) {
              return (b.invoiceNumber ?? '').compareTo(a.invoiceNumber ?? '');
            }
            return timeComparison;

          case PurchaseSortOption.oldest:
            int timeComparison = dateA.compareTo(dateB);
            if (timeComparison == 0) {
              return (a.invoiceNumber ?? '').compareTo(b.invoiceNumber ?? '');
            }
            return timeComparison;

          case PurchaseSortOption.amountHighToLow:
            final amtA = a.totalAmount ?? 0.0;
            final amtB = b.totalAmount ?? 0.0;
            int amtComparison = amtB.compareTo(amtA);
            return amtComparison != 0 ? amtComparison : dateB.compareTo(dateA);

          case PurchaseSortOption.amountLowToHigh:
            final amtA = a.totalAmount ?? 0.0;
            final amtB = b.totalAmount ?? 0.0;
            int amtComparison = amtA.compareTo(amtB);
            return amtComparison != 0 ? amtComparison : dateB.compareTo(dateA);

          case PurchaseSortOption.supplierAZ:
            final supA = a.supplierName ?? '';
            final supB = b.supplierName ?? '';
            int nameComparison = supA.compareTo(supB);
            return nameComparison != 0 ? nameComparison : dateB.compareTo(dateA);
        }
      });

      _filteredPurchases = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff9dbdff), Color(0xff6eacda)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          title: const Text(
            'Purchase Records',
            style: TextStyle(
              color: Color(0xFF011835),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton<PurchaseSortOption>(
              icon: const Icon(Icons.sort, color: Color(0xFF011835)),
              onSelected: (PurchaseSortOption option) {
                setState(() {
                  _currentSortOption = option;
                  _applyFilterAndSort(_searchController.text);
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<PurchaseSortOption>>[
                const PopupMenuItem<PurchaseSortOption>(
                  value: PurchaseSortOption.newest,
                  child: Text('Date: Newest First (Exact Time)'),
                ),
                const PopupMenuItem<PurchaseSortOption>(
                  value: PurchaseSortOption.oldest,
                  child: Text('Date: Oldest First (Exact Time)'),
                ),
                const PopupMenuItem<PurchaseSortOption>(
                  value: PurchaseSortOption.amountHighToLow,
                  child: Text('Amount: High to Low'),
                ),
                const PopupMenuItem<PurchaseSortOption>(
                  value: PurchaseSortOption.amountLowToHigh,
                  child: Text('Amount: Low to High'),
                ),
                const PopupMenuItem<PurchaseSortOption>(
                  value: PurchaseSortOption.supplierAZ,
                  child: Text('Supplier: A to Z'),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _applyFilterAndSort,
                  decoration: const InputDecoration(
                    hintText: 'Search supplier or invoice...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF1E3A8A)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredPurchases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No purchase records found',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPurchases,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredPurchases.length,
                    itemBuilder: (context, index) {
                      final purchase = _filteredPurchases[index];
                      return PurchaseCardItem(purchase: purchase);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class PurchaseCardItem extends StatelessWidget {
  final Purchase purchase;
  const PurchaseCardItem({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPurchaseDetails(context, purchase),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shopping_bag_outlined, color: Colors.orange.shade800),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.supplierName ?? 'Unknown Supplier',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inv: ${purchase.invoiceNumber ?? 'N/A'} - ${purchase.date != null ? purchase.date.toString().split('.')[0] : ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${purchase.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Purchase',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPurchaseDetails(BuildContext context, Purchase purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PurchaseDetailsSheet(purchase: purchase);
      },
    );
  }
}

class PurchaseDetailsSheet extends StatelessWidget {
  final Purchase purchase;
  const PurchaseDetailsSheet({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: PurchaseMainAxisSizeWidget(purchase: purchase),
      ),
    );
  }
}

class PurchaseMainAxisSizeWidget extends StatelessWidget {
  final Purchase purchase;
  const PurchaseMainAxisSizeWidget({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Purchase Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 8),
        _buildDetailRow('Supplier', purchase.supplierName),
        _buildDetailRow('Invoice No', purchase.invoiceNumber),
        _buildDetailRow('Date & Time', purchase.date != null ? purchase.date.toString().split('.')[0] : 'N/A'),
        const SizedBox(height: 16),
        const Text('Items Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: purchase.items.length,
            itemBuilder: (context, index) {
              final item = purchase.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName ?? 'Product'} (x${item.quantity})',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    Text(
                      'Rs. ${item.price?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              'Rs. ${purchase.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Download & Share PDF Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _sharePurchaseDetails(context, purchase),
          ),
        ),
      ],
    );
  }

  Future<void> _sharePurchaseDetails(BuildContext context, Purchase purchase) async {
    try {
      final pdfFile = await PdfService.generatePurchaseInvoice(purchase);
      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          subject: 'Purchase Invoice: ${purchase.invoiceNumber}',
          text: 'Please find attached the purchase invoice for ${purchase.supplierName}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}