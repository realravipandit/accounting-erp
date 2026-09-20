import 'package:flutter/material.dart';
import 'package:sas_app/services/sales/pos_sales_service.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sas_app/core/services/toast_service.dart';
import 'package:sas_app/shared/widgets/pdf_preview_screen.dart';

class SalesEntryPosScreen extends StatefulWidget {
  const SalesEntryPosScreen({super.key});

  @override
  State<SalesEntryPosScreen> createState() => _SalesEntryPosScreenState();
}

class _SalesEntryPosScreenState extends State<SalesEntryPosScreen> {
  final PosSalesService _posService = PosSalesService();
  final Color _primaryColor = const Color(0xFF45B38B);

  final TextEditingController _invoiceController = TextEditingController(text: 'Auto-Gen');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _tenderController = TextEditingController();

  NepaliDateTime _selectedNepaliDate = NepaliDateTime.now();
  late DateTime _selectedAdDate;

  bool _isTaxInvoice = false;
  List<Map<String, dynamic>> _counters = [];
  String? _selectedCounterName;

  Map<String, dynamic>? _selectedCustomer;
  final List<Map<String, dynamic>> _cartItems = [];

  List<dynamic> _termMasters = [];
  List<Map<String, dynamic>> _billWiseTerms = [];

  double _subTotal = 0.0;
  double _grandTotal = 0.0;
  final int _paymentLedgerId = 1;

  // Which bottom button is currently mid-save: 'complete', 'preview', or null.
  String? _loadingButton;

  List<Map<String, dynamic>> _cachedItems = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _fetchCounters();
    _fetchTermMasters();
    _preloadItems();
    _tenderController.addListener(() => setState(() {}));
  }

  void _initializeDates() {
    _selectedNepaliDate = NepaliDateTime.now();
    _selectedAdDate = _selectedNepaliDate.toDateTime();
    _dateController.text = NepaliDateFormat('dd/MM/yyyy').format(_selectedNepaliDate);
  }

  Future<void> _fetchCounters() async {
    try {
      final classes = await _posService.fetchClasses();
      if (mounted) {
        setState(() {
          _counters = classes.isNotEmpty ? classes : [{'ClassName': 'Main Counter'}];
          _selectedCounterName = _counters.isNotEmpty ? _counters[0]['ClassName'] : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTermMasters() async {
    try {
      final terms = await _posService.fetchTermMasters();
      if (mounted) {
        setState(() {
          _termMasters = terms;
          _billWiseTerms = terms.where((t) {
            final iw = (t['ItemWise'] ?? t['itemWise'] ?? '').toString().toUpperCase();
            return iw == 'N';
          }).map((t) {
            final String sign = (t['Sign'] ?? t['sign'] ?? '+').toString().trim();
            return {
              'termId': t['TermID'] ?? t['termID'],
              'termName': (t['TermName'] ?? t['termName']).toString(),
              'sign': sign,
              'percentController': TextEditingController(text: (t['Rate'] ?? t['rate'] ?? 0.0).toString()),
              'amountController': TextEditingController(),
              'isActive': sign == '+',
              'isManualAmount': false,
            };
          }).toList();
        });
        _calculateTotals();
      }
    } catch (_) {}
  }

  Future<void> _preloadItems() async {
    try {
      _cachedItems = await _posService.getItems();
    } catch (_) {}
  }

  Future<void> _selectDate(BuildContext context) async {
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

  void _calculateTotals({int? manualIndex, bool isPercentChange = false}) {
    double tempSub = 0.0;
    for (var item in _cartItems) {
      tempSub += (item['totalAmount'] as double);
    }

    double runningTotal = tempSub;

    for (int i = 0; i < _billWiseTerms.length; i++) {
      var bt = _billWiseTerms[i];
      if (bt['sign'] == '-') {
        if (manualIndex == i) bt['isManualAmount'] = !isPercentChange;

        if (bt['isActive']) {
          double amt = 0.0;
          bool isManual = bt['isManualAmount'] ?? false;

          if (isManual) {
            amt = double.tryParse(bt['amountController'].text) ?? 0.0;
            if (tempSub > 0) bt['percentController'].text = ((amt / tempSub) * 100).toStringAsFixed(2);
          } else {
            double pct = double.tryParse(bt['percentController'].text) ?? 0.0;
            amt = (tempSub * pct) / 100;
            bt['amountController'].text = amt.toStringAsFixed(2);
          }
          runningTotal -= amt;
        } else {
          bt['amountController'].clear();
        }
      }
    }

    for (int i = 0; i < _billWiseTerms.length; i++) {
      var bt = _billWiseTerms[i];
      if (bt['sign'] == '+') {
        if (bt['isActive']) {
          double rate = double.tryParse(bt['percentController'].text) ?? 0.0;
          double taxAmt = runningTotal - (runningTotal / (1 + (rate / 100)));
          bt['amountController'].text = taxAmt.toStringAsFixed(2);
        } else {
          bt['amountController'].clear();
        }
      }
    }

    setState(() {
      _subTotal = tempSub;
      _grandTotal = runningTotal.clamp(0.0, double.infinity);
    });
  }

  void _handleBarcodeSearch(String val) {
    if (val.trim().isEmpty) return;

    final query = val.trim().toLowerCase();
    final match = _cachedItems.firstWhere(
      (i) => (i['ItemCode'] ?? i['itemCode'] ?? '').toString().toLowerCase() == query ||
             (i['ItemName'] ?? i['itemName'] ?? '').toString().toLowerCase().contains(query),
      orElse: () => {},
    );

    if (match.isEmpty) {
      ToastService.showError(context, 'Item not found');
      return;
    }

    final itemId = match['ItemID'] ?? match['itemId'];
    final itemName = (match['ItemName'] ?? match['itemName'] ?? '').toString();
    final double itemRate = double.tryParse((match['SalesRate'] ?? match['salesRate'] ?? '0').toString()) ?? 0.0;

    setState(() {
      final existingIndex = _cartItems.indexWhere((ci) => ci['id'] == itemId);
      if (existingIndex >= 0) {
        final newQty = (_cartItems[existingIndex]['qty'] as double) + 1.0;
        _cartItems[existingIndex]['qty'] = newQty;
        _cartItems[existingIndex]['totalAmount'] = newQty * (_cartItems[existingIndex]['price'] as double);
      } else {
        _cartItems.add({
          'id': itemId,
          // Item's default unit, pulled silently from tblItems (no picker in UI)
          'unitId': match['UnitID'] ?? match['unitId'],
          'name': itemName,
          'price': itemRate,
          'qty': 1.0,
          'totalAmount': itemRate,
          'itemTerms': [],
          'originalItem': match,
        });
      }
    });
    _calculateTotals();
  }

  // ITEM DIALOG (Add / Edit) - now mirrors Purchase Entry's item-specific terms UI
  void _showAddBillingItemDialog(
    Map<String, dynamic> item, {
    Map<String, dynamic>? existingCartItem,
    int? existingIndex,
  }) {
    final bool isEditing = existingCartItem != null;
    final double initQty = isEditing ? (existingCartItem['qty'] as double) : 1.0;
    final double initRate = isEditing
        ? (existingCartItem['price'] as double)
        : double.tryParse((item['SalesRate'] ?? item['salesRate'] ?? '0').toString()) ?? 0.0;

    final qtyCtrl = TextEditingController(text: initQty.toString());
    final rateCtrl = TextEditingController(text: initRate.toStringAsFixed(2));

    // Item-specific terms (ItemWise = Y), same pattern as Purchase Entry
    List<Map<String, dynamic>> dialogTerms = _termMasters.where((t) {
      final itemWiseValue = t['ItemWise'] ?? t['itemWise'] ?? t['itemwise'];
      final String isItemWise = itemWiseValue?.toString().trim().toUpperCase() ?? 'N';
      return isItemWise == 'Y' || isItemWise == '1' || isItemWise == 'TRUE';
    }).map<Map<String, dynamic>>((t) {
      final double dbRate = double.tryParse((t['Rate'] ?? t['rate'] ?? 0.0).toString()) ?? 0.0;
      return {
        'termId': t['TermID'] ?? t['termID'] ?? t['termid'] ?? t['TermId'] ?? 0,
        'termName': (t['TermName'] ?? t['termName'] ?? t['termname'] ?? 'Term').toString(),
        'sign': (t['Sign'] ?? t['sign'] ?? '+').toString().trim(),
        'percentController': TextEditingController(
          text: dbRate % 1 == 0 ? dbRate.toInt().toString() : dbRate.toStringAsFixed(2),
        ),
        'amountController': TextEditingController(),
        'isActive': false,
        'rate': dbRate,
      };
    }).toList();

    // Pre-fill saved item terms when editing an existing cart line
    if (isEditing && existingCartItem['itemTerms'] != null) {
      for (final existingTerm in existingCartItem['itemTerms']) {
        for (final dt in dialogTerms) {
          if (dt['termId'] == existingTerm['termId']) {
            dt['isActive'] = true;
            dt['percentController'].text = (existingTerm['percent'] ?? 0.0).toString();
            dt['amountController'].text = (existingTerm['amount'] ?? 0.0).toString();
          }
        }
      }
    }

    double dialogNetTotal =
        isEditing ? (existingCartItem['totalAmount'] as double) : initQty * initRate;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddItem',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            void recalculateDialog({bool fromAmount = false, int? index}) {
              final double qty = double.tryParse(qtyCtrl.text) ?? 1.0;
              final double rate = double.tryParse(rateCtrl.text) ?? 0.0;
              double currentTotal = qty * rate;

              for (int i = 0; i < dialogTerms.length; i++) {
                final term = dialogTerms[i];
                if (term['isActive'] == true) {
                  if (fromAmount && index == i) {
                    final double amount = double.tryParse(term['amountController'].text) ?? 0.0;
                    if (currentTotal > 0) {
                      term['percentController'].text =
                          ((amount / currentTotal) * 100).toStringAsFixed(2);
                    }
                    currentTotal += term['sign'] == '-' ? -amount : amount;
                  } else {
                    final double percent = double.tryParse(term['percentController'].text) ?? 0.0;
                    final double amount = (currentTotal * percent) / 100;
                    term['amountController'].text = amount == 0 ? '0' : amount.toStringAsFixed(2);
                    currentTotal += term['sign'] == '-' ? -amount : amount;
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
              title: Text(
                isEditing ? 'Edit POS Item' : 'Add Item to POS Bill',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
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
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ITEM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    itemName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _dlgField(
                              label: 'Quantity',
                              controller: qtyCtrl,
                              onChanged: (_) => recalculateDialog(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _dlgField(
                              label: 'Rate (Rs.)',
                              controller: rateCtrl,
                              onChanged: (_) => recalculateDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (dialogTerms.isNotEmpty)
                        const Text(
                          'Item Specific Terms',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                        ),
                      ...dialogTerms.asMap().entries.map((entry) {
                        final int idx = entry.key;
                        final Map<String, dynamic> t = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Checkbox(
                                value: t['isActive'],
                                activeColor: _primaryColor,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  t['isActive'] = val ?? false;
                                  recalculateDialog();
                                },
                              ),
                              Expanded(
                                child: Text(
                                  t['termName'],
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 75,
                                child: TextField(
                                  controller: t['percentController'],
                                  decoration: _modernInputDecoration().copyWith(suffixText: '%'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => recalculateDialog(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 95,
                                child: TextField(
                                  controller: t['amountController'],
                                  decoration: _modernInputDecoration().copyWith(prefixText: 'Rs '),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => recalculateDialog(fromAmount: true, index: idx),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Total',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              'Rs. ${dialogNetTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                  icon: Icon(isEditing ? Icons.save_rounded : Icons.add_shopping_cart, size: 18),
                  label: Text(
                    isEditing ? 'Save Changes' : 'Add to Bill',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      final updatedItem = {
                        'id': item['ItemID'] ?? item['itemId'],
                        // Item's default unit, pulled silently from tblItems (no picker in UI)
                        'unitId': item['UnitID'] ?? item['unitId'],
                        'name': itemName,
                        'price': double.tryParse(rateCtrl.text) ?? 0.0,
                        'qty': double.tryParse(qtyCtrl.text) ?? 1.0,
                        'totalAmount': dialogNetTotal,
                        'itemTerms': dialogTerms
                            .where((dt) => dt['isActive'] == true)
                            .map((dt) {
                          return {
                            'termId': dt['termId'],
                            'termName': dt['termName'],
                            'sign': dt['sign'],
                            'percent': double.tryParse(dt['percentController'].text) ?? 0.0,
                            'amount': double.tryParse(dt['amountController'].text) ?? 0.0,
                          };
                        }).toList(),
                        'originalItem': item,
                      };

                      if (isEditing && existingIndex != null) {
                        _cartItems[existingIndex] = updatedItem;
                      } else {
                        _cartItems.add(updatedItem);
                      }
                    });
                    _calculateTotals();
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  void _showCustomerSelection() async {
    List<Map<String, dynamic>> ledgers = [];
    try {
      ledgers = await _posService.fetchLedgers();
    } catch (_) {}
    if (!mounted) return;

    final TextEditingController searchController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              final query = searchController.text.toLowerCase();
              final filtered = ledgers.where((c) {
                final name = (c['LedgerName'] ?? c['ledgerName'] ?? '').toString().toLowerCase();
                return name.contains(query);
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
                      autofocus: true,
                      onChanged: (_) => setModal(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.money, color: Colors.white)),
                    title: const Text('Cash Party (Walk-in)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() => _selectedCustomer = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final name = (c['LedgerName'] ?? c['ledgerName'] ?? '').toString();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _primaryColor.withValues(alpha: 0.1),
                            child: Text(name.isNotEmpty ? name[0] : 'C', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name),
                          onTap: () {
                            setState(() => _selectedCustomer = c);
                            debugPrint("=== SELECTED CUSTOMER DATA: $_selectedCustomer ===");
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Runs validation, builds the payload, and posts the sale.
  /// Returns the service result on success, or null on validation
  /// failure / API failure (an error toast is already shown in that case).
  /// Assumes the caller has already set `_loadingButton` before calling this.
  /// On success, `_loadingButton` is left set --- the caller decides when to
  /// clear it (immediately for the popup flow, or after navigation for
  /// the preview flow).
  Future<Map<String, dynamic>?> _processSale() async {
    if (_cartItems.isEmpty) {
      setState(() => _loadingButton = null);
      ToastService.showError(context, 'Cart is empty. Add items first.');
      return null;
    }

    final double tenderAmount = double.tryParse(_tenderController.text) ?? _grandTotal;
    if (tenderAmount < _grandTotal) {
      setState(() => _loadingButton = null);
      ToastService.showError(context, 'Tender amount cannot be less than Grand Total for Cash Sales!');
      return null;
    }

    // 1. Resolve ClassID
    final selectedCounterObj = _counters.firstWhere(
      (c) => (c['ClassName'] ?? c['className'] ?? '').toString() == _selectedCounterName,
      orElse: () => {},
    );

    final int? resolvedClassId = selectedCounterObj['ClassID'] ??
                                 selectedCounterObj['classID'] ??
                                 selectedCounterObj['ClassId'] ??
                                 selectedCounterObj['id'];

    // 2. Calculate return amount
    final double returnAmount = tenderAmount > _grandTotal ? tenderAmount - _grandTotal : 0.0;

    // 3. Dates
    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedAdDate);

    // 4. Remarks (null if empty string)
    final String? remarksValue = _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim();

    // 5. Send RAW inclusive prices (The Node.js backend handles the math)
    final formattedItems = _cartItems.map((item) {
      return {
        'itemId': item['id'],
        'unitId': item['unitId'],
        'qty': item['qty'],
        'rate': item['price'],          // Inclusive Rate
        'amount': item['totalAmount'],  // Inclusive Amount
        'itemTerms': item['itemTerms'] ?? [],
      };
    }).toList();

    // Payload for Node.js API
    final payload = {
      'isTaxInvoice': _isTaxInvoice,
      'classId': resolvedClassId,
      'ClassId': resolvedClassId,
      'customerLedgerId': _selectedCustomer != null ? (_selectedCustomer!['LedgerID'] ?? _selectedCustomer!['ledgerID']) : null,
      'customerName': _selectedCustomer != null ? _selectedCustomer!['LedgerName'] : 'Cash Party',
      'branchId': null,
      'nepaliDate': _dateController.text,
      'adDate': formattedDate,
      'voucherDate': formattedDate,
      'effectiveDate': formattedDate,
      'remarks': remarksValue,
      'counter': _selectedCounterName,
      'returnAmount': returnAmount,
      'printedBy': 'ADMIN',            // Handled securely by Backend JWT Token
      'isApproved': 'N',
      'items': formattedItems,
      'billTerms': _billWiseTerms.where((t) => t['isActive'] == true).map((t) => {
        'termId': t['termId'],
        'termName': t['termName'],
        'sign': t['sign'],
        'rate': double.tryParse(t['percentController'].text) ?? 0.0,
        'amount': double.tryParse(t['amountController'].text) ?? 0.0,
      }).toList(),
      'payments': [
        {
          'ledgerId': _paymentLedgerId,
          'amount': tenderAmount,
        }
      ],
    };

    debugPrint("=== POSTING PAYLOAD ===");
    debugPrint(payload.toString());

    try {
      final result = await _posService.submitPosSale(payload);
      if (!mounted) return null;

      if (result['success'] == true) {
        return result;
      } else {
        setState(() => _loadingButton = null);
        ToastService.showError(context, result['message'] ?? 'Failed to complete POS transaction.');
        return null;
      }
    } catch (e) {
      if (mounted) setState(() => _loadingButton = null);
      ToastService.showError(context, 'Error: $e');
      return null;
    }
  }

  /// "Complete Sale" button --- saves the sale and shows a completion
  /// popup with the bill details, then resets the form.
  Future<void> _completeSale() async {
    final double tenderAmount = double.tryParse(_tenderController.text) ?? _grandTotal;

    setState(() => _loadingButton = 'complete');
    final result = await _processSale();
    if (result == null) return;
    if (!mounted) return;

    setState(() => _loadingButton = null);
    await _showSaleCompletedDialog(result, tenderAmount);
  }

  /// "Save & Preview" button --- saves the sale and opens the PDF preview
  /// (this is what the single "Complete Sale" button used to do).
  Future<void> _completeSaleAndPreview() async {
    final double tenderAmount = double.tryParse(_tenderController.text) ?? _grandTotal;

    setState(() => _loadingButton = 'preview');
    final result = await _processSale();
    if (result == null) return;

    await _navigateToPdfPreview(result, tenderAmount);
  }

  Future<void> _showSaleCompletedDialog(Map<String, dynamic> result, double tenderAmount) async {
    final double changeReturn = tenderAmount > _grandTotal ? tenderAmount - _grandTotal : 0.0;
    final String voucherId = (result['voucherId'] ?? 'CS-X').toString();
    final String customerName = _selectedCustomer == null ? 'Cash Party' : (_selectedCustomer!['LedgerName'] ?? 'Cash Party');

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: _primaryColor, size: 48),
            const SizedBox(height: 8),
            const Text('Sale Completed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('Voucher No.', voucherId),
            _summaryRow('Customer', customerName),
            _summaryRow('Items', '${_cartItems.length}'),
            const Divider(),
            _summaryRow('Grand Total', 'Rs. ${_grandTotal.toStringAsFixed(2)}', isBold: true),
            _summaryRow('Tender', 'Rs. ${tenderAmount.toStringAsFixed(2)}'),
            _summaryRow('Change Return', 'Rs. ${changeReturn.toStringAsFixed(2)}', valueColor: Colors.green),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );

    _resetForm();
  }

  Future<void> _navigateToPdfPreview(Map<String, dynamic> result, double tender) async {
    final voucherId = result['voucherId'] ?? 'CS-X';
    final double changeReturn = tender > _grandTotal ? tender - _grandTotal : 0.0;

    Map<String, dynamic> companyInfo = {};
    try {
      companyInfo = await _posService.fetchActiveCompanyProfile();
    } catch (e) {
      debugPrint("Could not fetch company profile: $e");
    }

    // --- Threshold Check (Determine if effectively Tax Invoice) ---
    double maxAbbrLimit = 10000.0;
    if (companyInfo.containsKey('AbbrMaxAmount')) {
      maxAbbrLimit = double.tryParse(companyInfo['AbbrMaxAmount'].toString()) ?? 10000.0;
    } else if (companyInfo.containsKey('AbbreviatedMaxAmount')) {
      maxAbbrLimit = double.tryParse(companyInfo['AbbreviatedMaxAmount'].toString()) ?? 10000.0;
    }

    bool effectivelyTaxInvoice = _isTaxInvoice ||
                                 _grandTotal >= maxAbbrLimit ||
                                 voucherId.toString().contains('TI') ||
                                 voucherId.toString().contains('CI');

    final String type = effectivelyTaxInvoice ? 'tax' : 'abbr';

    double vatRate = 0.0;
    double vatAmount = 0.0;
    double discountAmount = 0.0;

    for (var t in _billWiseTerms) {
      if (t['isActive'] == true) {
        double amt = double.tryParse(t['amountController'].text) ?? 0.0;
        if (t['sign'] == '+') {
          vatAmount += amt;
          vatRate = double.tryParse(t['percentController'].text) ?? 13.0;
        }
        if (t['sign'] == '-') {
          discountAmount += amt;
        }
      }
    }

    if (vatRate == 0.0 && effectivelyTaxInvoice) {
      vatRate = 13.0; // Enforce default rate if it's a tax invoice
    }

    double calculatedTaxableValue = 0.0;
    final List<Map<String, dynamic>> processedItems = [];

    for (int i = 0; i < _cartItems.length; i++) {
      var item = _cartItems[i];
      double qty = item['qty'] as double;
      double lineTotalInclusive = item['totalAmount'] as double;

      double itemDiscount = 0.0;
      if (_subTotal > 0) {
        itemDiscount = discountAmount * (lineTotalInclusive / _subTotal);
      }

      double netLineInclusive = lineTotalInclusive - itemDiscount;

      // Calculate pre-tax amounts only if PDF is Tax type
      double lineTaxableAmount = (effectivelyTaxInvoice && vatRate > 0)
          ? netLineInclusive / (1 + (vatRate / 100))
          : netLineInclusive;

      calculatedTaxableValue += lineTaxableAmount;
      double rateBeforeTax = qty > 0 ? lineTaxableAmount / qty : 0.0;

      processedItems.add({
        'sno': i + 1,
        'itemName': item['name'],
        'qty': qty.toString(),
        'rate': rateBeforeTax.toStringAsFixed(2),
        'amount': lineTaxableAmount.toStringAsFixed(2),
      });
    }

    Map<String, dynamic> transactionData = {
      'companyInfo': companyInfo,
      'customerName': _selectedCustomer == null ? 'Cash Party' : (_selectedCustomer!['LedgerName'] ?? 'Cash Party'),

      // THIS IS THE FIX FOR THE ADDRESS: It checks all possible database keys for the address
      'customerAddress': _selectedCustomer == null
          ? ''
          : (_selectedCustomer!['LedgerAddress'] ?? ''),

      'printStatus': 'Original',
      'voucherId': voucherId,
      'miti': _dateController.text,
      'basicAmount': _subTotal.toStringAsFixed(2),
      'netAmount': _grandTotal.toStringAsFixed(2),
      'tenderAmount': tender.toStringAsFixed(2),
      'returnAmount': changeReturn.toStringAsFixed(2),
      'amountInWords': 'Rs. ${_numberToWords(_grandTotal.toInt())} only',
      'paymentMode': 'Cash',
      'counter': _selectedCounterName ?? 'MAIN',

      // THIS IS THE FIX FOR THE CASHIER: It dynamically pulls the logged-in user code
      'cashier': result['cashier'] ?? 'ADMIN',

      'time': DateFormat('h:mm a').format(DateTime.now()),
      'remarks': _remarksController.text,
      'items': processedItems,
      'totalGrossAmount': _subTotal.toStringAsFixed(2),
      'taxExemptedValue': '0.00',
      'taxableValue': calculatedTaxableValue.toStringAsFixed(2),
      'vatAmount': vatAmount.toStringAsFixed(2),
    };

    if (!mounted) return;
    setState(() => _loadingButton = null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          transactionData: transactionData,
          invoiceType: type,
        ),
      ),
    ).then((_) {
      _resetForm();
    });
  }

  void _resetForm() {
    setState(() {
      _cartItems.clear();
      _tenderController.clear();
      _remarksController.clear();
      _isTaxInvoice = false;
      _selectedCustomer = null;
      for (var t in _billWiseTerms) {
        t['amountController'].clear();
        if (t['sign'] == '-') {
          t['isActive'] = false;
        } else if (t['sign'] == '+') {
          t['isActive'] = true;
        }
      }
    });
    _calculateTotals();
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100) return '${tens[n ~/ 10]}${n % 10 > 0 ? " ${units[n % 10]}" : ""}';
      if (n < 1000) return '${units[n ~/ 100]} Hundred${n % 100 > 0 ? " ${convert(n % 100)}" : ""}';
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand${n % 1000 > 0 ? " ${convert(n % 1000)}" : ""}';
      if (n < 10000000) return '${convert(n ~/ 100000)} Lakh${n % 100000 > 0 ? " ${convert(n % 100000)}" : ""}';
      return '${convert(n ~/ 10000000)} Crore${n % 10000000 > 0 ? " ${convert(n % 10000000)}" : ""}';
    }

    return convert(number);
  }

  Widget _buildFieldContainer({required String label, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w600)), Icon(icon, size: 18, color: Colors.grey)]),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87))],
      ),
    );
  }

  InputDecoration _modernInputDecoration({String? hint, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
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

  @override
  Widget build(BuildContext context) {
    final customerName = _selectedCustomer == null ? 'Cash Party (Walk-in)' : (_selectedCustomer!['LedgerName'] ?? 'Customer');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('POS Counter Sales', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: Colors.black87)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _buildFieldContainer(label: 'Voucher No.', value: _invoiceController.text, icon: Icons.receipt_long)),
              const SizedBox(width: 12),
              Expanded(child: InkWell(onTap: () => _selectDate(context), child: _buildFieldContainer(label: 'Nepali Date (BS)', value: _dateController.text, icon: Icons.calendar_today))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: SwitchListTile(
                title: const Text('Tax Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(_isTaxInvoice ? 'Forced Tax Invoice (Counter Bill)' : 'Automatic Abbr / Tax rule active', style: const TextStyle(fontSize: 11)),
                value: _isTaxInvoice,
                activeThumbColor: _primaryColor,
                onChanged: (val) => setState(() => _isTaxInvoice = val),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Counter', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCounterName,
                          isExpanded: true,
                          items: _counters.map((c) => DropdownMenuItem<String>(value: c['ClassName'] ?? '', child: Text(c['ClassName'] ?? ''))).toList(),
                          onChanged: (val) => setState(() => _selectedCounterName = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _showCustomerSelection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(customerName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))), const Icon(Icons.arrow_drop_down, color: Colors.grey)]),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final selected = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemSearchPage(items: _cachedItems, primaryColor: _primaryColor),
                  ),
                );
                if (selected != null && mounted) {
                  _showAddBillingItemDialog(selected);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: _primaryColor),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Search item name / code or scan barcode...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final scannedCode = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (_) => BarcodeScannerScreen(primaryColor: _primaryColor)),
                        );
                        if (scannedCode != null && scannedCode.trim().isNotEmpty) {
                          _handleBarcodeSearch(scannedCode.trim());
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.qr_code_scanner, color: _primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Container(padding: const EdgeInsets.all(12), color: Colors.grey.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Cart Items', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_cartItems.length} item(s)', style: const TextStyle(color: Colors.grey))])),
                  _cartItems.isEmpty
                      ? const Padding(padding: EdgeInsets.all(24), child: Text('No items scanned/added yet', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cartItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final ci = _cartItems[i];
                            return InkWell(
                              onTap: () {
                                if (ci['originalItem'] != null) _showAddBillingItemDialog(ci['originalItem'], existingCartItem: ci, existingIndex: i);
                              },
                              child: ListTile(
                                title: Text(ci['name']),
                                subtitle: Text('${ci['qty']} x Rs. ${ci['price']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Rs. ${ci['totalAmount'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      onPressed: () {
                                        setState(() => _cartItems.removeAt(i));
                                        _calculateTotals();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_billWiseTerms.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bill Terms (Discount / VAT)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    ..._billWiseTerms.asMap().entries.map((entry) {
                      int index = entry.key;
                      var term = entry.value;
                      bool isVat = term['sign'] == '+';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: term['isActive'],
                              activeColor: _primaryColor,
                              onChanged: isVat ? null : (val) {
                                setState(() => term['isActive'] = val ?? false);
                                _calculateTotals();
                              },
                            ),
                            Expanded(flex: 2, child: Text(term['termName'], style: TextStyle(fontSize: 13, color: isVat ? Colors.grey : Colors.black87))),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: term['percentController'],
                                keyboardType: TextInputType.number,
                                enabled: !isVat,
                                decoration: const InputDecoration(labelText: '%', isDense: true, border: OutlineInputBorder()),
                                onChanged: (val) {
                                  setState(() => term['isActive'] = true);
                                  _calculateTotals(manualIndex: index, isPercentChange: true);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: term['amountController'],
                                keyboardType: TextInputType.number,
                                enabled: !isVat,
                                decoration: const InputDecoration(labelText: 'Amount', isDense: true, border: OutlineInputBorder()),
                                onChanged: (val) {
                                  setState(() => term['isActive'] = true);
                                  _calculateTotals(manualIndex: index, isPercentChange: false);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _remarksController,
              decoration: InputDecoration(
                labelText: 'Remarks / Notes',
                hintText: 'Enter any transaction notes...',
                prefixIcon: const Icon(Icons.notes, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _summaryRow('Subtotal', 'Rs. ${_subTotal.toStringAsFixed(2)}'),
                  ..._billWiseTerms.where((t) => t['isActive'] == true).map((t) {
                    final amt = double.tryParse(t['amountController'].text) ?? 0.0;
                    if (amt == 0) return const SizedBox.shrink();
                    final sign = t['sign'] == '-' ? '-' : '+';
                    return _summaryRow(
                      '${t['termName']} ($sign)',
                      'Rs. ${amt.toStringAsFixed(2)}',
                      valueColor: t['sign'] == '-' ? Colors.red.shade700 : Colors.grey.shade600,
                    );
                  }),
                  const Divider(),
                  _summaryRow('Grand Total', 'Rs. ${_grandTotal.toStringAsFixed(2)}', isBold: true),
                  const Divider(height: 20),
                  TextField(controller: _tenderController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Tender Amount (Cash Paid)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixText: 'Rs. ')),
                  const SizedBox(height: 10),
                  _summaryRow('Change Return', 'Rs. ${((double.tryParse(_tenderController.text) ?? 0) - _grandTotal > 0 ? (double.tryParse(_tenderController.text) ?? 0) - _grandTotal : 0).toStringAsFixed(2)}', valueColor: Colors.green, isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _primaryColor, width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _loadingButton != null ? null : _completeSale,
                  child: _loadingButton == 'complete'
                      ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: _primaryColor, strokeWidth: 2))
                      : Text('Complete Sale', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _loadingButton != null ? null : _completeSaleAndPreview,
                  child: _loadingButton == 'preview'
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  final Color primaryColor;
  const BarcodeScannerScreen({super.key, required this.primaryColor});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.qrCode, BarcodeFormat.upcA, BarcodeFormat.upcE]);
  int _scannedCount = 0;
  String _lastScannedText = '';
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fast POS Scanner ($_scannedCount added)'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) async {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  final code = barcode.rawValue!;
                  if (code == _lastScannedText) return;
                  setState(() {
                    _isProcessing = true;
                    _lastScannedText = code;
                    _scannedCount++;
                  });
                  Navigator.pop(context, code);
                  break;
                }
              }
            },
          ),
          Center(child: Container(width: 280, height: 160, decoration: BoxDecoration(border: Border.all(color: widget.primaryColor, width: 3), borderRadius: BorderRadius.circular(12)))),
        ],
      ),
    );
  }
}

/// Full-screen item picker (mirrors Purchase Entry's "Add Items" flow):
/// tapping the search field on the POS screen opens this page instead of
/// typing inline. Selecting an item pops it back to the caller, which then
/// opens the Add/Edit item dialog.
class ItemSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Color primaryColor;

  const ItemSearchPage({super.key, required this.items, required this.primaryColor});

  @override
  State<ItemSearchPage> createState() => _ItemSearchPageState();
}

class _ItemSearchPageState extends State<ItemSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      final name = (item['ItemName'] ?? item['itemName'] ?? '').toString().toLowerCase();
      final code = (item['ItemCode'] ?? item['itemCode'] ?? '').toString().toLowerCase();
      return name.contains(_query) || code.contains(_query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Select Item', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search item name / code...',
                prefixIcon: Icon(Icons.search, color: widget.primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      widget.items.isEmpty ? 'No items loaded.' : 'No items found.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final name = (item['ItemName'] ?? item['itemName'] ?? 'Unknown').toString();
                      final code = (item['ItemCode'] ?? item['itemCode'] ?? '').toString();
                      final rate = (item['SalesRate'] ?? item['salesRate'] ?? '0').toString();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'I',
                            style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Code: ${code.isNotEmpty ? code : 'N/A'} | Rate: Rs. $rate',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}