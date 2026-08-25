import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/api_service.dart';
import 'sales_entry_screen.dart'; // Make sure this import is correct for your project

class PurchaseEntryScreen extends StatefulWidget {
  const PurchaseEntryScreen({super.key});

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final ApiService _apiService = ApiService();
  final Color _primaryColor = const Color(0xFF3B82F6);

  // ── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _voucherNoController = TextEditingController(text: 'Loading...');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _supplierBillNoController = TextEditingController();
  final TextEditingController _supplierDateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _creditDaysController = TextEditingController(text: '0');
  final TextEditingController _cashPartyNameController = TextEditingController();

  // ── Date State ───────────────────────────────────────────────────────────
  late NepaliDateTime _selectedNepaliDate;
  late DateTime _selectedAdDate;
  NepaliDateTime? _selectedSupplierNepaliDate;
  DateTime? _selectedSupplierAdDate;

  // ── POS State ────────────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedVendor;
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentModeLabel = 'Credit';
  int? _paymentLedgerId;

  // ── Terms & Adjustments State ────────────────────────────────────────────
  List<dynamic> _termMasters = [];
  List<Map<String, dynamic>> _billWiseTerms = [];

  // ── Totals ───────────────────────────────────────────────────────────────
  double _subTotal = 0.0;
  double _taxableAmount = 0.0;
  double _grandTotal = 0.0;

  // ── Loading & Guards ─────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _isSubmitting = false; // 🌟 Prevents rapid double-taps & sequence burning
  bool _isSupplierDateUnlocked = false;

  // Helper to format numbers cleanly (displays '0' instead of '0.00' when zero)
  String _cleanNum(double val) {
    if (val == 0) return '0';
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _fetchNextVoucher();
    _fetchTermMasters();

    // Auto-fill Supplier Date when Bill No is typed
    _supplierBillNoController.addListener(() {
      setState(() {
        _isSupplierDateUnlocked = _supplierBillNoController.text.trim().isNotEmpty;
        if (_isSupplierDateUnlocked) {
          if (_supplierDateController.text.isEmpty) {
            _selectedSupplierNepaliDate = _selectedNepaliDate;
            _selectedSupplierAdDate = _selectedAdDate;
            _supplierDateController.text = _dateController.text;
          }
        } else {
          _supplierDateController.clear();
          _selectedSupplierNepaliDate = null;
          _selectedSupplierAdDate = null;
        }
      });
    });
  }

  void _initializeDates() {
    _selectedNepaliDate = NepaliDateTime.now();
    _selectedAdDate = _selectedNepaliDate.toDateTime();
    _dateController.text = NepaliDateFormat('dd/MM/yyyy').format(_selectedNepaliDate);
  }

  Future<void> _fetchNextVoucher() async {
    try {
      final nextInv = await _apiService.getNextPurchaseVoucher();
      if (mounted) setState(() => _voucherNoController.text = nextInv);
    } catch (_) {
      if (mounted) setState(() => _voucherNoController.text = 'Error');
    }
  }

  Future<void> _fetchTermMasters() async {
    try {
      final dynamic response = await _apiService.fetchPurchaseTermMasters();
      List terms = [];
      if (response is List) {
        terms = response;
      } else if (response is Map && response['data'] is List) {
        terms = response['data'];
      }

      if (terms.isNotEmpty && mounted) {
        setState(() {
          _termMasters = terms;

          // Filter Bill-Wise Terms
          _billWiseTerms = terms.where((t) {
            var itemWiseValue = t['ItemWise'] ?? t['itemWise'] ?? t['itemwise'];
            String isItemWise = itemWiseValue?.toString().trim().toUpperCase() ?? 'N';
            return isItemWise == 'N' || isItemWise == '0' || isItemWise == 'FALSE' || isItemWise == '';
          }).map<Map<String, dynamic>>((t) {
            double dbRate = double.tryParse((t['Rate'] ?? t['rate'] ?? 0.0).toString()) ?? 0.0;
            return {
              'termId': t['TermID'] ?? t['termID'] ?? t['termid'] ?? t['TermId'] ?? 0,
              'termName': (t['TermName'] ?? t['termName'] ?? t['termname'] ?? 'Term').toString(),
              'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
              'percentController': TextEditingController(text: _cleanNum(dbRate)), // 🌟 Clean 0 format
              'amountController': TextEditingController(),
              'isActive': false,
              'isManualAmount': false,
              'rate': dbRate,
            };
          }).toList();

          _billWiseTerms.sort((a, b) {
            bool aIsVat = a['termName'].toString().toUpperCase().contains('VAT');
            bool bIsVat = b['termName'].toString().toUpperCase().contains('VAT');
            if (aIsVat && !bIsVat) return 1;
            if (!aIsVat && bIsVat) return -1;
            return 0;
          });
        });
      }
    } catch (e) {
      debugPrint("Error fetching term masters dynamically: $e");
    }
  }

  Future<void> _selectSystemDate(BuildContext context) async {
    final NepaliDateTime? picked = await showNepaliDatePicker(
      context: context,
      initialDate: _selectedNepaliDate,
      firstDate: NepaliDateTime(2000, 1, 1),
      lastDate: NepaliDateTime(2100, 12, 30),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedNepaliDate = picked;
        _selectedAdDate = picked.toDateTime();
        _dateController.text = NepaliDateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectSupplierDate(BuildContext context) async {
    if (!_isSupplierDateUnlocked) return;
    final NepaliDateTime? picked = await showNepaliDatePicker(
      context: context,
      initialDate: _selectedSupplierNepaliDate ?? NepaliDateTime.now(),
      firstDate: NepaliDateTime(2000, 1, 1),
      lastDate: NepaliDateTime(2100, 12, 30),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedSupplierNepaliDate = picked;
        _selectedSupplierAdDate = picked.toDateTime();
        _supplierDateController.text = NepaliDateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _calculateTotals({int? manualIndex, bool isPercentChange = false}) {
    double tempSub = 0.0;
    double tempTaxable = 0.0;

    for (var item in _cartItems) {
      double lineTotal = item['totalAmount'] ?? 0.0;
      tempSub += lineTotal;

      bool hasItemVat = false;
      if (item['itemTerms'] != null) {
        for (var t in item['itemTerms']) {
          if (t['termName'].toString().toUpperCase().contains('VAT')) {
            hasItemVat = true;
            break;
          }
        }
      }
      if (!hasItemVat) tempTaxable += lineTotal;
    }

    double runningTotal = tempSub;
    double runningTaxable = tempTaxable;

    for (int i = 0; i < _billWiseTerms.length; i++) {
      var bt = _billWiseTerms[i];

      if (manualIndex == i) {
        bt['isManualAmount'] = !isPercentChange;
      }

      if (bt['isActive']) {
        bool isVat = bt['termName'].toString().toUpperCase().contains('VAT');
        double base = isVat ? runningTaxable : runningTotal;
        bool isManual = bt['isManualAmount'] ?? false;
        double amt = 0.0;

        if (isManual) {
          amt = double.tryParse(bt['amountController'].text) ?? 0.0;
          if (base > 0 && !isPercentChange) {
            double pct = (amt / base) * 100;
            bt['percentController'].text = _cleanNum(pct);
          }
        } else {
          double pct = double.tryParse(bt['percentController'].text) ?? 0.0;
          amt = (base * pct) / 100;
          bt['amountController'].text = amt == 0 ? '0' : amt.toStringAsFixed(2);
        }

        if (bt['sign'] == '-') {
          runningTotal -= amt;
          if (!isVat) runningTaxable -= amt;
        } else {
          runningTotal += amt;
          if (!isVat) runningTaxable += amt;
        }
      } else {
        bt['amountController'].clear();
        bt['percentController'].text = _cleanNum(bt['rate'] ?? 0.0);
        bt['isManualAmount'] = false;
      }
    }

    setState(() {
      _subTotal = tempSub;
      _taxableAmount = runningTaxable;
      _grandTotal = runningTotal.clamp(0.0, double.infinity);
    });
  }

  void _removeItemFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
    _calculateTotals();
  }

  void _showPaymentModeSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Select Payment Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _paymentTile(
              ctx: ctx, 
              icon: Icons.account_balance_wallet_rounded, 
              iconColor: Colors.orange, 
              bgColor: Colors.orange.shade50,
              title: 'Credit', 
              subtitle: 'Standard vendor credit purchase',
              onTap: () {
                setState(() { 
                  _paymentModeLabel = 'Credit'; 
                  _paymentLedgerId = null; 
                });
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            _paymentTile(
              ctx: ctx, 
              icon: Icons.money_rounded, 
              iconColor: Colors.green, 
              bgColor: Colors.green.shade50,
              title: 'Cash', 
              subtitle: 'Immediate cash payment',
              onTap: () {
                setState(() { 
                  _paymentModeLabel = 'Cash'; 
                  _paymentLedgerId = null; 
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile({
    required BuildContext ctx, 
    required IconData icon, 
    required Color iconColor,
    required Color bgColor, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap,
  }) {
    final bool isSelected = _paymentModeLabel == title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container( 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withValues(alpha: 0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _primaryColor : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: _primaryColor, size: 22),
          ],
        ),
      ),
    );
  }

  void _showVendorSelection() {
    final Future<List<Map<String, dynamic>>> vendorsFuture = _apiService.getPurchaseVendors();
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: StatefulBuilder(builder: (ctx, setModal) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: vendorsFuture,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryColor));
                if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))));

                final all = snapshot.data ?? [];
                final query = searchController.text.toLowerCase();
                final filtered = all.where((c) {
                  final name = (c['LedgerName'] ?? c['ledgerName'] ?? '').toString().toLowerCase();
                  final code = (c['LedgerCode'] ?? c['ledgerCode'] ?? '').toString().toLowerCase();
                  return name.contains(query) || code.contains(query);
                }).toList();

                return Column(
                  children: [
                    Container(
                      width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                    const Text('Select Vendor / Supplier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setModal(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search vendor by name or code...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { searchController.clear(); setModal(() {}); })
                              : null,
                          filled: true, fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No vendors found.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final c = filtered[i];
                                final name = (c['LedgerName'] ?? c['ledgerName'] ?? 'Unknown').toString();
                                final code = (c['LedgerCode'] ?? c['ledgerCode'] ?? '').toString();
                                final isSelected = _selectedVendor != null && (_selectedVendor!['LedgerID'] ?? _selectedVendor!['ledgerID']) == (c['LedgerID'] ?? c['ledgerID']);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'V', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(name),
                                  subtitle: code.isNotEmpty ? Text(code) : null,
                                  trailing: isSelected ? Icon(Icons.check_circle, color: _primaryColor) : null,
                                  onTap: () {
                                    setState(() { _selectedVendor = c; });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          }),
        ),
      ),
    );
  }

  void _openItemSearchPage() async {
    final selectedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, a, __) => ItemSearchScreen(apiService: _apiService, primaryColor: _primaryColor),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ),
    );

    if (selectedItem != null && mounted) {
      _showAddBillingItemDialog(selectedItem);
    }
  }

  void _showAddBillingItemDialog(Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController(text: '1');
    final double initRate = item['BuyRate'] != null
        ? double.tryParse(item['BuyRate'].toString()) ?? 0.0
        : (item['buyRate'] != null ? double.tryParse(item['buyRate'].toString()) ?? 0.0 : 0.0);
    
    final rateCtrl = TextEditingController(text: initRate.toStringAsFixed(2));

    List<Map<String, dynamic>> dialogTerms = _termMasters.where((t) {
      var itemWiseValue = t['ItemWise'] ?? t['itemWise'] ?? t['itemwise'];
      String isItemWise = itemWiseValue?.toString().trim().toUpperCase() ?? 'N';
      return isItemWise == 'Y' || isItemWise == '1' || isItemWise == 'TRUE';
    }).map<Map<String, dynamic>>((t) {
      double dbRate = double.tryParse((t['Rate'] ?? t['rate'] ?? 0.0).toString()) ?? 0.0;
      return {
        'termId': t['TermID'] ?? t['termID'] ?? t['termid'] ?? t['TermId'] ?? 0,
        'termName': (t['TermName'] ?? t['termName'] ?? t['termname'] ?? 'Term').toString(),
        'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
        'percentController': TextEditingController(text: _cleanNum(dbRate)),
        'amountController': TextEditingController(),
        'isActive': false,
        'rate': dbRate,
      };
    }).toList();

    double dialogNetTotal = initRate;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddItem',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void recalculateDialog({bool fromAmount = false, int? index}) {
            double qty = double.tryParse(qtyCtrl.text) ?? 1.0;
            double rate = double.tryParse(rateCtrl.text) ?? 0.0;
            double currentTotal = qty * rate;

            for (int i = 0; i < dialogTerms.length; i++) {
              var term = dialogTerms[i];
              if (term['isActive']) {
                if (fromAmount && index == i) {
                  double amt = double.tryParse(term['amountController'].text) ?? 0.0;
                  if (currentTotal > 0) term['percentController'].text = _cleanNum((amt / currentTotal) * 100);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                } else {
                  double pct = double.tryParse(term['percentController'].text) ?? 0.0;
                  double amt = (currentTotal * pct) / 100;
                  term['amountController'].text = amt == 0 ? '0' : amt.toStringAsFixed(2);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                }
              } else {
                term['amountController'].clear();
                term['percentController'].text = _cleanNum(term['rate'] ?? 0.0);
              }
            }
            setDlg(() { dialogNetTotal = currentTotal; });
          }

          final itemName = (item['ItemName'] ?? item['itemName'] ?? '').toString();

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Purchase Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                          Text(itemName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ])),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _dlgField(label: 'Quantity', controller: qtyCtrl, onChanged: (_) => recalculateDialog())),
                      const SizedBox(width: 14),
                      Expanded(child: _dlgField(label: 'Buy Rate (Rs.)', controller: rateCtrl, onChanged: (_) => recalculateDialog())),
                    ]),
                    const SizedBox(height: 16),
                    if (dialogTerms.isNotEmpty)
                      const Text('Item Specific Terms', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    ...dialogTerms.asMap().entries.map((entry) {
                       int idx = entry.key;
                       var t = entry.value;
                       return Padding(
                         padding: const EdgeInsets.only(top: 10),
                         child: Row(children: [
                           Checkbox(
                             value: t['isActive'],
                             activeColor: _primaryColor,
                             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                             visualDensity: VisualDensity.compact,
                             onChanged: (val) { t['isActive'] = val; recalculateDialog(); }
                           ),
                           Expanded(child: Text(t['termName'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                           // 🌟 Wider percent field
                           SizedBox(width: 75, child: TextField(controller: t['percentController'], decoration: _modernInputDecoration(suffix: '%'), keyboardType: TextInputType.number, onChanged: (_) => recalculateDialog())),
                           const SizedBox(width: 8),
                           // 🌟 Wider amount field
                           SizedBox(width: 95, child: TextField(controller: t['amountController'], decoration: _modernInputDecoration(prefix: 'Rs '), keyboardType: TextInputType.number, onChanged: (_) => recalculateDialog(fromAmount: true, index: idx))),
                         ]),
                       );
                    }),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Total', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('Rs. ${dialogNetTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.grey[600]))),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Add to Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  setState(() {
                    _cartItems.add({
                      'id': item['ItemID'] ?? item['itemId'],
                      'name': itemName,
                      'price': double.tryParse(rateCtrl.text) ?? 0.0,
                      'qty': double.tryParse(qtyCtrl.text) ?? 1.0,
                      'totalAmount': dialogNetTotal,
                      'itemTerms': dialogTerms.where((dt) => dt['isActive']).map((dt) => {
                        'termId': dt['termId'],
                        'termName': dt['termName'],
                        'sign': dt['sign'],
                        'percent': double.tryParse(dt['percentController'].text) ?? 0.0,
                        'amount': double.tryParse(dt['amountController'].text) ?? 0.0,
                      }).toList(),
                    });
                  });
                  _calculateTotals();
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
      transitionBuilder: (_, a, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _showEditItemDialog(int index) {
    final ci = _cartItems[index];
    final qtyCtrl = TextEditingController(text: ci['qty'].toString());
    final rateCtrl = TextEditingController(text: ci['price'].toString());

    List<Map<String, dynamic>> dialogTerms = _termMasters.where((t) {
      var itemWiseValue = t['ItemWise'] ?? t['itemWise'] ?? t['itemwise'];
      String isItemWise = itemWiseValue?.toString().trim().toUpperCase() ?? 'N';
      return isItemWise == 'Y' || isItemWise == '1' || isItemWise == 'TRUE';
    }).map<Map<String, dynamic>>((t) {
      double dbRate = double.tryParse((t['Rate'] ?? t['rate'] ?? 0.0).toString()) ?? 0.0;
      return {
        'termId': t['TermID'] ?? t['termID'] ?? t['termid'] ?? t['TermId'] ?? 0,
        'termName': (t['TermName'] ?? t['termName'] ?? t['termname'] ?? 'Term').toString(),
        'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
        'percentController': TextEditingController(text: _cleanNum(dbRate)),
        'amountController': TextEditingController(),
        'isActive': false,
        'rate': dbRate,
      };
    }).toList();

    if (ci['itemTerms'] != null) {
      for (var existingTerm in ci['itemTerms']) {
        for (var dt in dialogTerms) {
          if (dt['termId'] == existingTerm['termId']) {
            dt['isActive'] = true;
            dt['percentController'].text = _cleanNum(existingTerm['percent']);
            dt['amountController'].text = existingTerm['amount'].toString();
          }
        }
      }
    }

    double dialogNetTotal = ci['totalAmount'] as double;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'EditItem',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void recalculateDialog({bool fromAmount = false, int? index}) {
            double qty = double.tryParse(qtyCtrl.text) ?? 1.0;
            double rate = double.tryParse(rateCtrl.text) ?? 0.0;
            double currentTotal = qty * rate;

            for (int i = 0; i < dialogTerms.length; i++) {
              var term = dialogTerms[i];
              if (term['isActive']) {
                if (fromAmount && index == i) {
                  double amt = double.tryParse(term['amountController'].text) ?? 0.0;
                  if (currentTotal > 0) term['percentController'].text = _cleanNum((amt / currentTotal) * 100);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                } else {
                  double pct = double.tryParse(term['percentController'].text) ?? 0.0;
                  double amt = (currentTotal * pct) / 100;
                  term['amountController'].text = amt == 0 ? '0' : amt.toStringAsFixed(2);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                }
              } else {
                term['amountController'].clear();
                term['percentController'].text = _cleanNum(term['rate'] ?? 0.0);
              }
            }
            setDlg(() { dialogNetTotal = currentTotal; });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.edit_outlined, color: _primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('EDITING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                              Text(ci['name'].toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _dlgField(label: 'Quantity', controller: qtyCtrl, onChanged: (_) => recalculateDialog())),
                      const SizedBox(width: 14),
                      Expanded(child: _dlgField(label: 'Buy Rate (Rs.)', controller: rateCtrl, onChanged: (_) => recalculateDialog())),
                    ]),
                    const SizedBox(height: 16),
                    if (dialogTerms.isNotEmpty)
                      const Text('Item Specific Terms', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    ...dialogTerms.asMap().entries.map((entry) {
                       int idx = entry.key;
                       var t = entry.value;
                       return Padding(
                         padding: const EdgeInsets.only(top: 10),
                         child: Row(children: [
                           Checkbox(
                             value: t['isActive'],
                             activeColor: _primaryColor,
                             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                             visualDensity: VisualDensity.compact,
                             onChanged: (val) { t['isActive'] = val; recalculateDialog(); }
                           ),
                           Expanded(child: Text(t['termName'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                           // 🌟 Wider percent field
                           SizedBox(width: 75, child: TextField(controller: t['percentController'], decoration: _modernInputDecoration(suffix: '%'), keyboardType: TextInputType.number, onChanged: (_) => recalculateDialog())),
                           const SizedBox(width: 8),
                           // 🌟 Wider amount field
                           SizedBox(width: 95, child: TextField(controller: t['amountController'], decoration: _modernInputDecoration(prefix: 'Rs '), keyboardType: TextInputType.number, onChanged: (_) => recalculateDialog(fromAmount: true, index: idx))),
                         ]),
                       );
                    }),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Total', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('Rs. ${dialogNetTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.grey[600]))),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  setState(() {
                    _cartItems[index]['qty'] = double.tryParse(qtyCtrl.text) ?? 1.0;
                    _cartItems[index]['price'] = double.tryParse(rateCtrl.text) ?? 0.0;
                    _cartItems[index]['totalAmount'] = dialogNetTotal;
                    _cartItems[index]['itemTerms'] = dialogTerms.where((dt) => dt['isActive']).map((dt) => {
                      'termId': dt['termId'],
                      'termName': dt['termName'],
                      'sign': dt['sign'],
                      'percent': double.tryParse(dt['percentController'].text) ?? 0.0,
                      'amount': double.tryParse(dt['amountController'].text) ?? 0.0,
                    }).toList();
                  });
                  _calculateTotals();
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
      transitionBuilder: (_, a, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _submitPurchase() async {
    // 🌟 Immediate synchronous lock flag to prevent rapid double-taps & sequence burning
    if (_isSubmitting) return;

    if (_cartItems.isEmpty) {
      _showSnack('Please add at least one item.', isError: true);
      return;
    }

    if (_paymentModeLabel == 'Credit' && _selectedVendor == null) {
      _showSnack('Please select a Vendor for a Credit purchase.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isSaving = true;
    });

    final ledgerId = _selectedVendor != null ? (_selectedVendor!['LedgerID'] ?? _selectedVendor!['ledgerID']) : null;
    final vendorName = _selectedVendor != null ? (_selectedVendor!['LedgerName'] ?? _selectedVendor!['ledgerName']) : _cashPartyNameController.text.trim();

    final payload = {
      'vendorLedgerId': ledgerId,
      'vendorName': vendorName.isNotEmpty ? vendorName : null,
      'partyBillNo': _supplierBillNoController.text.trim(),
      'partyBillDate': _selectedSupplierAdDate != null ? DateFormat('yyyy-MM-dd').format(_selectedSupplierAdDate!) : null,
      'branchId': null,
      'nepaliDate': _dateController.text,
      'adDate': DateFormat('yyyy-MM-dd').format(_selectedAdDate),
      'remarks': _remarksController.text,
      'paymentMode': _paymentModeLabel,      
      'paymentLedgerId': _paymentLedgerId,
      'creditDays': int.tryParse(_creditDaysController.text) ?? 0,
      'items': _cartItems.map((item) {
        return {
          'itemId': item['id'],
          'qty': item['qty'],
          'rate': item['price'],
          'itemTerms': item['itemTerms'] ?? [],
        };
      }).toList(),
      'billTerms': _billWiseTerms.where((t) => t['isActive']).map((t) => {
        'termId': t['termId'],
        'termName': t['termName'],
        'sign': t['sign'],
        'percent': double.tryParse(t['percentController'].text) ?? 0.0,
        'amount': double.tryParse(t['amountController'].text) ?? 0.0,
      }).toList(),
    };

    try {
      final result = await _apiService.submitPurchase(payload);
      if (!mounted) return;
      
      setState(() {
        _isSubmitting = false;
        _isSaving = false;
      });

      if (result['success'] == true) {
        _showSuccessSheet(result);
      } else {
        _showSnack(result['message'] ?? 'Failed to save purchase.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSaving = false;
        });
      }
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSuccessSheet(Map<String, dynamic> result) {
    final voucherId = result['voucherId'] ?? '';
    final netAmount = result['netAmount'] ?? _grandTotal;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Purchase Saved Successfully!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Voucher: $voucherId', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _summaryRow('Net Amount', 'Rs. ${netAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _summaryRow('Supplier Bill No', _supplierBillNoController.text.trim().isEmpty ? 'N/A' : _supplierBillNoController.text.trim()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { Navigator.pop(ctx); _resetForm(); },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('New Purchase'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _cartItems.clear();
      _selectedVendor = null;
      _supplierBillNoController.clear();
      _supplierDateController.clear();
      _selectedSupplierAdDate = null;
      _selectedSupplierNepaliDate = null;
      _paymentModeLabel = 'Credit';
      _paymentLedgerId = null;
      _creditDaysController.text = '0';
      _cashPartyNameController.clear();
      _remarksController.clear();
      _isSupplierDateUnlocked = false;

      for (var t in _billWiseTerms) {
        t['isActive'] = false;
        t['amountController'].clear();
        t['percentController'].text = _cleanNum(t['rate'] ?? 0.0);
      }

      _subTotal = 0;
      _taxableAmount = 0;
      _grandTotal = 0;
    });
    _fetchNextVoucher();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  InputDecoration _modernInputDecoration({String? hint, String? prefix, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryColor, width: 1.5)),
    );
  }

  Widget _dlgField({required String label, required TextEditingController controller, ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(controller: controller, keyboardType: TextInputType.number, onChanged: onChanged, decoration: _modernInputDecoration()),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, IconData? suffixIcon, VoidCallback? onTap, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: enabled ? Colors.grey[600] : Colors.grey[400])),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: onTap != null,
          enabled: enabled,
          onTap: enabled ? onTap : null,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: Icon(suffixIcon, color: enabled ? Colors.grey[600] : Colors.grey[300], size: 20),
            filled: !enabled,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: onTap != null ? _primaryColor : Colors.grey[300]!)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _voucherNoController.dispose();
    _dateController.dispose();
    _supplierBillNoController.dispose();
    _supplierDateController.dispose();
    _remarksController.dispose();
    _creditDaysController.dispose();
    _cashPartyNameController.dispose();

    for (var t in _billWiseTerms) {
      t['percentController']?.dispose();
      t['amountController']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorName = _selectedVendor == null
        ? 'Select Vendor / Supplier *'
        : (_selectedVendor!['LedgerName'] ?? _selectedVendor!['ledgerName'] ?? 'Unknown Vendor').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('New Purchase Entry', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(onPressed: _resetForm, child: Text('Clear', style: TextStyle(color: Colors.grey[600]))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _buildTextField(label: 'Voucher No. (System)', controller: _voucherNoController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(label: 'Nepali Date (BS)', controller: _dateController, suffixIcon: Icons.calendar_today_outlined, onTap: () => _selectSystemDate(context))),
            ]),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('AD: ${DateFormat('dd MMM yyyy').format(_selectedAdDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.receipt_long, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Vendor Bill Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildTextField(label: 'Supplier Bill No (Optional)', controller: _supplierBillNoController, enabled: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(
                      label: 'Supplier Date',
                      controller: _supplierDateController,
                      suffixIcon: Icons.calendar_month,
                      enabled: _isSupplierDateUnlocked,
                      onTap: () => _selectSupplierDate(context),
                    )),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildVendorCard(vendorName),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _openItemSearchPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Items', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
            _buildBillingSection(),
            const SizedBox(height: 20),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes / Remarks (Optional)',
                alignLabelWithHint: true,
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryColor)),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submitPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Save Purchase  -  Rs. ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorCard(String vendorName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _selectedVendor == null ? Colors.blue.shade50 : _primaryColor.withValues(alpha: 0.1),
          child: Icon(
            _selectedVendor == null ? Icons.storefront_outlined : Icons.store_rounded,
            color: _selectedVendor == null ? Colors.blue : _primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vendorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(
                _selectedVendor == null
                    ? 'Sundry Creditor'
                    : ((_selectedVendor!['LedgerCode'] ?? _selectedVendor!['ledgerCode'] ?? '') as String).isNotEmpty
                        ? 'Code: ${_selectedVendor!['LedgerCode'] ?? _selectedVendor!['ledgerCode']}'
                        : 'Supplier Account',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: _showVendorSelection,
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryColor,
            side: BorderSide(color: _primaryColor.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
          child: const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildBillingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCartCard(),
        const SizedBox(height: 16),
        _buildTotalCard(),
      ],
    );
  }

  Widget _buildCartCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Purchase Items  (${_cartItems.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (_cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Clear All Items?'),
                          content: const Text('This will remove all items from the cart.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                setState(() => _cartItems.clear());
                                _calculateTotals();
                                Navigator.pop(context);
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (_cartItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(children: [
                  Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No items added yet', style: TextStyle(color: Colors.grey[400])),
                ]),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (_, i) => _buildCartItemTile(i),
            ),
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal (${_cartItems.length} items)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Rs. ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(int i) {
    final item = _cartItems[i];
    final double qty = double.tryParse(item['qty'].toString()) ?? 0;
    final double price = double.tryParse(item['price'].toString()) ?? 0;
    final double total = double.tryParse(item['totalAmount'].toString()) ?? 0;
    final double gross = qty * price;
    final double disc = (gross - total).clamp(0.0, double.infinity);
    final double discPct = gross > 0 ? (disc / gross) * 100 : 0;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryColor))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${qty % 1 == 0 ? qty.toInt() : qty} × Rs. ${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                if (disc > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.local_offer_outlined, size: 11, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text('Terms Applied: Rs. ${disc.toStringAsFixed(2)} (${discPct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs. ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                InkWell(
                  onTap: () => _showEditItemDialog(i),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _removeItemFromCart(i),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  ),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillTermRow(int index) {
    var bt = _billWiseTerms[index];
    bool isActive = bt['isActive'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? _primaryColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _primaryColor.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 24, width: 24,
            child: Checkbox(
              value: isActive,
              activeColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              onChanged: (val) {
                setState(() { bt['isActive'] = val; _calculateTotals(); });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${bt['termName']} (${bt['sign']})',
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: isActive ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ),
          // 🌟 Increased width for larger percentage input box
          Container(
            width: 85,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: TextField(
              controller: bt['percentController'],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.black87 : Colors.grey),
              decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: InputBorder.none, suffixText: '%', suffixStyle: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onChanged: (_) => _calculateTotals(manualIndex: index, isPercentChange: true),
            ),
          ),
          const SizedBox(width: 10),
          // 🌟 Increased width for larger amount equivalent input box
          Container(
            width: 110,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: TextField(
              controller: bt['amountController'],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.black87 : Colors.grey),
              decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                border: InputBorder.none, prefixText: 'Rs ', prefixStyle: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onChanged: (_) => _calculateTotals(manualIndex: index, isPercentChange: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final activeNonVatTerms = _billWiseTerms.where((t) => t['isActive'] && !t['termName'].toString().toUpperCase().contains('VAT')).toList();
    final activeVatTerms = _billWiseTerms.where((t) => t['isActive'] && t['termName'].toString().toUpperCase().contains('VAT')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_billWiseTerms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text('Bill Adjustments & Taxes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          ),
        ...List.generate(_billWiseTerms.length, (index) {
          if (_billWiseTerms[index]['termName'].toString().toUpperCase().contains('VAT')) return const SizedBox.shrink();
          return _buildBillTermRow(index);
        }),
        ...List.generate(_billWiseTerms.length, (index) {
          if (!_billWiseTerms[index]['termName'].toString().toUpperCase().contains('VAT')) return const SizedBox.shrink();
          return _buildBillTermRow(index);
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bill Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 16),
              _summaryRow('Subtotal', 'Rs. ${_subTotal.toStringAsFixed(2)}'),
              if (activeNonVatTerms.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...activeNonVatTerms.map((t) {
                  final amt = double.tryParse(t['amountController'].text) ?? 0.0;
                  if (amt == 0) return const SizedBox.shrink();
                  final isDeduction = t['sign'] == '-';
                  return _summaryRow(
                    t['termName'].toString(),
                    '${isDeduction ? '- ' : '+ '}Rs. ${amt.toStringAsFixed(2)}',
                    valueColor: isDeduction ? Colors.orange.shade700 : Colors.blue.shade700,
                  );
                }),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: List.generate(40, (index) => Expanded(child: Container(color: index % 2 == 0 ? Colors.grey.shade300 : Colors.transparent, height: 1.5))),
                ),
              ),
              _summaryRow('Taxable Amount', 'Rs. ${_taxableAmount.toStringAsFixed(2)}', valueColor: _primaryColor, isBold: true),
              if (activeVatTerms.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...activeVatTerms.map((t) {
                  final amt = double.tryParse(t['amountController'].text) ?? 0.0;
                  if (amt == 0) return const SizedBox.shrink();
                  final isDeduction = t['sign'] == '-';
                  return _summaryRow(
                    t['termName'].toString(),
                    '${isDeduction ? '- ' : '+ '}Rs. ${amt.toStringAsFixed(2)}',
                    valueColor: isDeduction ? Colors.orange.shade700 : Colors.purple.shade700,
                  );
                }),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    Text('Rs. ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _showPaymentModeSelection,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _paymentModeLabel == 'Cash' ? Colors.green.shade100
                                : _paymentModeLabel == 'Credit' ? Colors.orange.shade100
                                : Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _paymentModeLabel == 'Cash' ? Icons.money_rounded
                                : _paymentModeLabel == 'Credit' ? Icons.account_balance_wallet_rounded
                                : Icons.account_balance_rounded,
                            color: _paymentModeLabel == 'Cash' ? Colors.green.shade700
                                : _paymentModeLabel == 'Credit' ? Colors.orange.shade700
                                : Colors.blue.shade700,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Mode', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(_paymentModeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          ],
                        ),
                      ]),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.black87 : Colors.grey[600], fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }
}