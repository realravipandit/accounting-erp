import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/services/sales/sales_service.dart';
import 'package:sas_akount_login/features/sales/sales_entry_screen.dart'; // For ItemSearchScreen reuse

class SalesOrderEntryScreen extends StatefulWidget {
  const SalesOrderEntryScreen({super.key});

  @override
  State<SalesOrderEntryScreen> createState() => _SalesOrderEntryScreenState();
}

class _SalesOrderEntryScreenState extends State<SalesOrderEntryScreen> {
  final SalesService _salesService = SalesService();
  final Color _primaryColor = const Color(0xFF45B38B); // Keeping the Sales Green

  // ── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _orderNoController = TextEditingController(text: 'Loading...');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // ── Date State ───────────────────────────────────────────────────────────
  late NepaliDateTime _selectedNepaliDate;
  late DateTime _selectedAdDate;

  // ── POS State ────────────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedCustomer;
  final List<Map<String, dynamic>> _cartItems = [];

  // ── Terms & Adjustments State ────────────────────────────────────────────
  List<dynamic> _termMasters = [];
  List<Map<String, dynamic>> _billWiseTerms = [];

  // ── Totals ───────────────────────────────────────────────────────────────
  double _subTotal = 0.0;
  double _taxableAmount = 0.0;
  double _grandTotal = 0.0;

  // ── Loading ──────────────────────────────────────────────────────────────
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _fetchNextOrderNumber();
    _fetchTermMasters(); // Reusing the Sales Term Masters as per your C# logic
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  void _initializeDates() {
    _selectedNepaliDate = NepaliDateTime.now();
    _selectedAdDate = _selectedNepaliDate.toDateTime();
    _dateController.text = NepaliDateFormat('dd/MM/yyyy').format(_selectedNepaliDate);
  }

  Future<void> _fetchNextOrderNumber() async {
    try {
      // You will need to add this method to your SalesService
      final nextOrd = await _salesService.getNextSalesOrderNumber();
      if (mounted) setState(() => _orderNoController.text = nextOrd);
    } catch (_) {
      if (mounted) setState(() => _orderNoController.text = 'Error');
    }
  }

  Future<void> _fetchTermMasters() async {
    try {
      final terms = await _salesService.fetchTermMasters();
      if (mounted) {
        setState(() {
          _termMasters = terms;
          _billWiseTerms = terms.where((t) => t['ItemWise'] == 'N').map((t) => {
            'termId': t['TermID'] ?? t['termID'],
            'termName': (t['TermName'] ?? t['termName']).toString(),
            'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
            'percentController': TextEditingController(text: (t['Rate'] ?? 0.0).toString()),
            'amountController': TextEditingController(),
            'isActive': false,
            'isManualAmount': false,
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
    } catch (_) {}
  }

  Future<void> _selectDate(BuildContext context) async {
    final NepaliDateTime? picked = await showNepaliDatePicker(
      context: context,
      initialDate: _selectedNepaliDate,
      firstDate: NepaliDateTime(2000, 1, 1),
      lastDate: NepaliDateTime(2100, 12, 30),
      initialDatePickerMode: DatePickerMode.day,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: _primaryColor),
        ),
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

  // ── Core Math Engine ─────────────────────────────────────────────────────
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
          if (base > 0) bt['percentController'].text = ((amt / base) * 100).toStringAsFixed(2);
        } else {
          double pct = double.tryParse(bt['percentController'].text) ?? 0.0;
          amt = (base * pct) / 100;
          bt['amountController'].text = amt.toStringAsFixed(2);
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

  // ── Customer Selection ───────────────────────────────────────────────────
  void _showCustomerSelection() {
    final Future<List<Map<String, dynamic>>> ledgersFuture = _salesService.fetchLedgers();
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
              future: ledgersFuture,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
                }

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
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                    const Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setModal(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name or code...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    setModal(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.person_outline, color: Colors.green)),
                      title: const Text('Walk-in Customer', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('No ledger account required'),
                      trailing: _selectedCustomer == null ? Icon(Icons.check_circle, color: _primaryColor) : null,
                      onTap: () {
                        setState(() {
                          _selectedCustomer = null;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No customers found.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final c = filtered[i];
                                final name = (c['LedgerName'] ?? c['ledgerName'] ?? 'Unknown').toString();
                                final code = (c['LedgerCode'] ?? c['ledgerCode'] ?? '').toString();
                                final isSelected = _selectedCustomer != null &&
                                    (_selectedCustomer!['LedgerID'] ?? _selectedCustomer!['ledgerID']) == (c['LedgerID'] ?? c['ledgerID']);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(name),
                                  subtitle: code.isNotEmpty ? Text(code) : null,
                                  trailing: isSelected ? Icon(Icons.check_circle, color: _primaryColor) : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedCustomer = c;
                                    });
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

  // ── Item Search & Dialogs ────────────────────────────────────────────────
  void _openItemSearchPage() async {
    final selectedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, a, __) => ItemSearchScreen(salesService: _salesService, primaryColor: _primaryColor),
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
    final double initRate = item['SalesRate'] != null ? double.tryParse(item['SalesRate'].toString()) ?? 0.0 : 0.0;
    final rateCtrl = TextEditingController(text: initRate.toStringAsFixed(2));

    List<Map<String, dynamic>> dialogTerms = _termMasters.where((t) => t['ItemWise'] == 'Y').map((t) => {
      'termId': t['TermID'] ?? t['termID'],
      'termName': (t['TermName'] ?? t['termName']).toString(),
      'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
      'percentController': TextEditingController(text: (t['Rate'] ?? 0.0).toString()),
      'amountController': TextEditingController(),
      'isActive': false,
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
                  if (currentTotal > 0) term['percentController'].text = ((amt / currentTotal) * 100).toStringAsFixed(2);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                } else {
                  double pct = double.tryParse(term['percentController'].text) ?? 0.0;
                  double amt = (currentTotal * pct) / 100;
                  term['amountController'].text = amt.toStringAsFixed(2);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                }
              } else {
                term['amountController'].clear();
              }
            }
            setDlg(() {
              dialogNetTotal = currentTotal;
            });
          }

          final itemName = (item['ItemName'] ?? item['itemName'] ?? '').toString();

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Item to Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            Text(itemName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _dlgField(label: 'Quantity', controller: qtyCtrl, onChanged: (_) => recalculateDialog())),
                      const SizedBox(width: 14),
                      Expanded(child: _dlgField(label: 'Rate (Rs.)', controller: rateCtrl, onChanged: (_) => recalculateDialog())),
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
                            onChanged: (val) {
                              t['isActive'] = val;
                              recalculateDialog();
                            },
                          ),
                          Expanded(child: Text(t['termName'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: t['percentController'],
                              decoration: _modernInputDecoration(suffix: '%'),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => recalculateDialog(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: t['amountController'],
                              decoration: _modernInputDecoration(prefix: 'Rs '),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => recalculateDialog(fromAmount: true, index: idx),
                            ),
                          ),
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
                label: const Text('Add to Order', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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

    List<Map<String, dynamic>> dialogTerms = _termMasters.where((t) => t['ItemWise'] == 'Y').map((t) => {
      'termId': t['TermID'] ?? t['termID'],
      'termName': (t['TermName'] ?? t['termName']).toString(),
      'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
      'percentController': TextEditingController(text: (t['Rate'] ?? 0.0).toString()),
      'amountController': TextEditingController(),
      'isActive': false,
    }).toList();

    if (ci['itemTerms'] != null) {
      for (var existingTerm in ci['itemTerms']) {
        for (var dt in dialogTerms) {
          if (dt['termId'] == existingTerm['termId']) {
            dt['isActive'] = true;
            dt['percentController'].text = existingTerm['percent'].toString();
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
                  if (currentTotal > 0) term['percentController'].text = ((amt / currentTotal) * 100).toStringAsFixed(2);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                } else {
                  double pct = double.tryParse(term['percentController'].text) ?? 0.0;
                  double amt = (currentTotal * pct) / 100;
                  term['amountController'].text = amt.toStringAsFixed(2);
                  if (term['sign'] == '-') {
                    currentTotal -= amt;
                  } else {
                    currentTotal += amt;
                  }
                }
              } else {
                term['amountController'].clear();
              }
            }
            setDlg(() {
              dialogNetTotal = currentTotal;
            });
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
                      Expanded(child: _dlgField(label: 'Rate (Rs.)', controller: rateCtrl, onChanged: (_) => recalculateDialog())),
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
                            onChanged: (val) {
                              t['isActive'] = val;
                              recalculateDialog();
                            },
                          ),
                          Expanded(child: Text(t['termName'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: t['percentController'],
                              decoration: _modernInputDecoration(suffix: '%'),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => recalculateDialog(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: t['amountController'],
                              decoration: _modernInputDecoration(prefix: 'Rs '),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => recalculateDialog(fromAmount: true, index: idx),
                            ),
                          ),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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

  // ── Submit Order ─────────────────────────────────────────────────────────
  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) {
      _showSnack('Please add at least one item.', isError: true);
      return;
    }

    final ledgerId = _selectedCustomer != null ? (_selectedCustomer!['LedgerID'] ?? _selectedCustomer!['ledgerID']) : null;
    final customerNameStr = _selectedCustomer != null 
        ? (_selectedCustomer!['LedgerName'] ?? _selectedCustomer!['ledgerName']).toString() 
        : 'Walk-in Customer';

    // Same structure as Sales Payload, mapped to Sales Order backend logic
    final payload = {
      'customerLedgerId': ledgerId,
      'customerName': customerNameStr,
      'branchId': 1,
      'nepaliDate': _dateController.text,
      'adDate': DateFormat('yyyy-MM-dd').format(_selectedAdDate),
      'remarks': _remarksController.text,
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

    setState(() => _isSaving = true);

    try {
      // You will need to add `submitSalesOrder` to your SalesService
      final result = await _salesService.submitSalesOrder(payload);
      
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result['success'] == true) {
        _showSuccessSheet(result);
      } else {
        _showSnack(result['message'] ?? 'Failed to save order.', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
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
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Sales Order Saved!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Order No: $voucherId', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _summaryRow('Net Amount', 'Rs. ${netAmount.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetForm();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('New Order'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
      _selectedCustomer = null;
      _remarksController.clear();
      for (var t in _billWiseTerms) {
        t['isActive'] = false;
        t['amountController'].clear();
      }
      _subTotal = 0;
      _taxableAmount = 0;
      _grandTotal = 0;
    });
    _fetchNextOrderNumber();
  }

  // ── UI Helpers ───────────────────────────────────────────────────────────
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildTextField({required String label, required TextEditingController controller, IconData? suffixIcon, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: Icon(suffixIcon, color: Colors.grey[600], size: 20),
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
    _orderNoController.dispose();
    _dateController.dispose();
    _remarksController.dispose();
    for (var t in _billWiseTerms) {
      t['percentController']?.dispose();
      t['amountController']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerName = _selectedCustomer == null
        ? 'Walk-in Customer'
        : (_selectedCustomer!['LedgerName'] ?? _selectedCustomer!['ledgerName'] ?? 'Unknown Customer').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('New Sales Order', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
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
              Expanded(child: _buildTextField(label: 'Order No.', controller: _orderNoController, suffixIcon: Icons.receipt_long_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(label: 'Nepali Date (BS)', controller: _dateController, suffixIcon: Icons.calendar_today_outlined, onTap: () => _selectDate(context))),
            ]),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('AD: ${DateFormat('dd MMM yyyy').format(_selectedAdDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
            const SizedBox(height: 16),
            _buildCustomerCard(customerName),
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
                filled: true,
                fillColor: Colors.white,
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
              onPressed: _isSaving ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Save Order  -  Rs. ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(String customerName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _selectedCustomer == null ? Colors.green.shade50 : _primaryColor.withValues(alpha: 0.1),
          child: Icon(
            _selectedCustomer == null ? Icons.person_outline_rounded : Icons.person_rounded,
            color: _selectedCustomer == null ? Colors.green : _primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(
                _selectedCustomer == null
                    ? 'No ledger account required'
                    : ((_selectedCustomer!['LedgerCode'] ?? _selectedCustomer!['ledgerCode'] ?? '') as String).isNotEmpty
                        ? 'Code: ${_selectedCustomer!['LedgerCode'] ?? _selectedCustomer!['ledgerCode']}'
                        : 'Credit customer',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: _showCustomerSelection,
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
                Text('Order Items  (${_cartItems.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (_cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Clear All Items?'),
                          content: const Text('This will remove all items from the order cart.'),
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
                  Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey[300]),
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
            width: 28,
            height: 28,
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
                Text('${qty % 1 == 0 ? qty.toInt() : qty} x Rs. ${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
            height: 24,
            width: 24,
            child: Checkbox(
              value: isActive,
              activeColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              onChanged: (val) {
                setState(() {
                  bt['isActive'] = val;
                  _calculateTotals();
                });
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
          Container(
            width: 70,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: TextField(
              controller: bt['percentController'],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.black87 : Colors.grey),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: InputBorder.none,
                suffixText: '%',
                suffixStyle: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onChanged: (_) => _calculateTotals(manualIndex: index, isPercentChange: true),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 90,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: TextField(
              controller: bt['amountController'],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.black87 : Colors.grey),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                border: InputBorder.none,
                prefixText: 'Rs ',
                prefixStyle: TextStyle(fontSize: 12, color: Colors.grey),
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
            child: Text('Order Adjustments & Taxes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[800])),
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
              const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
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