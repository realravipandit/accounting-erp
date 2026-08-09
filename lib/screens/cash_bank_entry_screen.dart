import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/api_service.dart';

class CashBankEntryScreen extends StatefulWidget {
  const CashBankEntryScreen({super.key});

  @override
  State<CashBankEntryScreen> createState() => _CashBankEntryScreenState();
}

class _CashBankEntryScreenState extends State<CashBankEntryScreen> {
  final ApiService _apiService = ApiService();
  final Color _primaryColor = const Color(0xFF3B82F6);

  // ── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _voucherNoController = TextEditingController(text: 'Loading...');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // ── Date State ───────────────────────────────────────────────────────────
  late NepaliDateTime _selectedNepaliDate;
  late DateTime _selectedAdDate;

  // ── Voucher Sequence State ───────────────────────────────────────────────
  Map<String, dynamic>? _selectedSequence;
  List<Map<String, dynamic>> _availableSequences = [];

  // ── Ledger States ────────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedCashBankLedger; // Main Cash/Bank account (CashBank = 'Y')
  final List<Map<String, dynamic>> _gridRows = []; // Details rows

  // ── Loading & Guards ─────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadVoucherSequences();
  }

  void _initializeDates() {
    _selectedNepaliDate = NepaliDateTime.now();
    _selectedAdDate = _selectedNepaliDate.toDateTime();
    _dateController.text = NepaliDateFormat('dd/MM/yyyy').format(_selectedNepaliDate);
  }

  Future<void> _loadVoucherSequences() async {
    try {
      final sequences = await _apiService.fetchVoucherSequences('CB');
      if (sequences.isNotEmpty && mounted) {
        setState(() {
          _availableSequences = sequences;
        });
        await _handleSequenceChange(sequences.first);
      } else {
        if (mounted) {
          setState(() {
            _voucherNoController.text = 'CB-0001';
          });
          _addNewRow();
        }
      }
    } catch (e) {
      debugPrint("Error loading voucher sequences: $e");
      if (mounted) {
        setState(() => _voucherNoController.text = 'CB-0001');
        _addNewRow();
      }
    }
  }

  // 🌟 Dynamically reads transaction type (P or R) from explicit database columns
  String get _derivedCashBankType {
    if (_selectedSequence == null) return 'P';
    
    final docType = (_selectedSequence!['documentType'] ?? 
                     _selectedSequence!['DocumentType'] ?? 
                     _selectedSequence!['DocumentName'] ?? '').toString().toUpperCase();

    if (docType.startsWith('R') || docType.contains('RECEIPT')) {
      return 'R';
    }
    return 'P'; // Default to Payment
  }

  Future<void> _handleSequenceChange(Map<String, dynamic> seq) async {
    debugPrint("SELECTED SEQUENCE OBJECT FROM DB: $seq");

    setState(() {
      _selectedSequence = seq;
      _voucherNoController.text = _calculateVoucherId(seq);
      
      // Update all existing row types dynamically
      final currentType = _derivedCashBankType;
      for (var row in _gridRows) {
        row['type'] = currentType;
      }
    });

    if (_gridRows.isEmpty) {
      _addNewRow();
    }

    final docName = (seq['DocumentName'] ?? '').toString().toLowerCase();
    if (docName.contains('cash')) {
      try {
        final cashBankLedgers = await _apiService.getCashBankLedgers();
        final cashLedger = cashBankLedgers.firstWhere(
          (l) => (l['LedgerName'] ?? l['ledgerName'] ?? '').toString().toLowerCase().contains('cash'),
          orElse: () => cashBankLedgers.isNotEmpty ? cashBankLedgers.first : {},
        );
        if (cashLedger.isNotEmpty && mounted) {
          setState(() {
            _selectedCashBankLedger = cashLedger;
          });
        }
      } catch (e) {
        debugPrint("Error auto-selecting cash ledger: $e");
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedCashBankLedger = null;
        });
      }
    }
  }

  String _calculateVoucherId(Map<String, dynamic> seq) {
    int nextNo = int.tryParse((seq['CurrentNo'] ?? 1).toString()) ?? 1;
    String prefix = seq['Prefix'] ?? '';
    String suffix = seq['Suffix'] ?? '';
    int bodyLen = int.tryParse((seq['BodyLength'] ?? 4).toString()) ?? 4;
    return '$prefix${nextNo.toString().padLeft(bodyLen, '0')}$suffix';
  }

  void _showSequenceSelectorDialog() {
    if (_availableSequences.isEmpty) {
      _showSnack('No document sequences found for CB.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Document Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableSequences.length,
            itemBuilder: (_, i) {
              final seq = _availableSequences[i];
              return ListTile(
                title: Text(seq['DocumentName'] ?? 'Voucher'),
                subtitle: Text('Prefix: ${seq['Prefix'] ?? ''}'),
                trailing: _selectedSequence?['DocumentID'] == seq['DocumentID']
                    ? Icon(Icons.check_circle, color: _primaryColor)
                    : null,
                onTap: () {
                  _handleSequenceChange(seq);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
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

  void _addNewRow() {
    setState(() {
      _gridRows.add({
        'ledger': null,
        'type': _derivedCashBankType,
        'amount': 0.0,
        'narration': '',
        'amountController': TextEditingController(),
        'narrationController': TextEditingController(),
      });
    });
  }

  void _removeRow(int index) {
    setState(() {
      _gridRows[index]['amountController'].dispose();
      _gridRows[index]['narrationController'].dispose();
      _gridRows.removeAt(index);
    });
  }

  double get _totalDebit {
    double sum = 0;
    for (var row in _gridRows) {
      if (row['type'] == 'P') sum += (row['amount'] ?? 0.0);
    }
    return sum;
  }

  double get _totalCredit {
    double sum = 0;
    for (var row in _gridRows) {
      if (row['type'] == 'R') sum += (row['amount'] ?? 0.0);
    }
    return sum;
  }

  Future<void> _showCashBankLedgerSelection() async {
    final cashBankLedgers = await _apiService.getCashBankLedgers();
    final TextEditingController searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.75,
          child: StatefulBuilder(builder: (ctx, setModal) {
            final filtered = cashBankLedgers.where((l) {
              final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString().toLowerCase();
              final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString().toLowerCase();
              final query = searchCtrl.text.toLowerCase();
              return name.contains(query) || code.contains(query);
            }).toList();

            return Column(
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const Text('Select Cash / Bank Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setModal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search Cash or Bank ledger...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No Cash/Bank accounts found. Make sure accounts are marked as Cash/Bank (Y) in Ledger Master.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final l = filtered[i];
                            final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString();
                            final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString();
                            final address = (l['LedgerAddress'] ?? l['ledgerAddress'] ?? '').toString();
                            final phone = (l['PhoneNo'] ?? l['phoneNo'] ?? l['MobileNo'] ?? '').toString();
                            final pan = (l['PanNo'] ?? l['panNo'] ?? '').toString();

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(Icons.account_balance, color: Colors.blue, size: 20),
                              ),
                              title: Text(name.isNotEmpty ? name : 'Unnamed Account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (code.isNotEmpty) Text('Code: $code', style: TextStyle(fontSize: 12, color: Colors.grey[650])),
                                      if (pan.isNotEmpty) ...[
                                        if (code.isNotEmpty) const Text('  •  ', style: TextStyle(color: Colors.grey)),
                                        Text('PAN: $pan', style: TextStyle(fontSize: 12, color: Colors.grey[650])),
                                      ],
                                    ],
                                  ),
                                  if (address.isNotEmpty || phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [if (address.isNotEmpty) address, if (phone.isNotEmpty) 'Ph: $phone'].join('  |  '),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () {
                                setState(() => _selectedCashBankLedger = l);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showRowLedgerSelection(int rowIndex) async {
    final allLedgers = await _apiService.getVoucherLedgers();
    final TextEditingController searchCtrl = TextEditingController();

    final headerLedgerId = _selectedCashBankLedger != null
        ? (_selectedCashBankLedger!['LedgerID'] ?? _selectedCashBankLedger!['ledgerID'] ?? _selectedCashBankLedger!['ledger_id'])
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.75,
          child: StatefulBuilder(builder: (ctx, setModal) {
            final filtered = allLedgers.where((l) {
              final id = l['LedgerID'] ?? l['ledgerID'] ?? l['ledger_id'];
              
              if (headerLedgerId != null && id == headerLedgerId) {
                return false;
              }

              final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString().toLowerCase();
              final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString().toLowerCase();
              final query = searchCtrl.text.toLowerCase();
              return name.contains(query) || code.contains(query);
            }).toList();

            return Column(
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const Text('Select Account Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setModal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search ledger name or code...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No ledgers found.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final l = filtered[i];
                            final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString();
                            final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString();
                            final address = (l['LedgerAddress'] ?? l['ledgerAddress'] ?? '').toString();
                            final pan = (l['PanNo'] ?? l['panNo'] ?? '').toString();

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade50,
                                child: const Icon(Icons.receipt_long, color: Colors.green, size: 20),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (code.isNotEmpty) Text('Code: $code', style: TextStyle(fontSize: 12, color: Colors.grey[650])),
                                      if (pan.isNotEmpty) ...[
                                        if (code.isNotEmpty) const Text('  •  ', style: TextStyle(color: Colors.grey)),
                                        Text('PAN: $pan', style: TextStyle(fontSize: 12, color: Colors.grey[650])),
                                      ],
                                    ],
                                  ),
                                  if (address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(address, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _gridRows[rowIndex]['ledger'] = l;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _submitVoucher() async {
    if (_isSubmitting) return;

    if (_selectedCashBankLedger == null) {
      _showSnack('Please select a Cash or Bank account.', isError: true);
      return;
    }
    if (_gridRows.isEmpty || _gridRows.any((r) => r['ledger'] == null)) {
      _showSnack('Please ensure all rows have an account selected.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isSaving = true;
    });

    // 🌟 Payload now dynamically sends exactly what is picked in the UI
    final payload = {
      'documentName': _selectedSequence?['DocumentName'],
      'documentPrefix': _selectedSequence?['Prefix'], // Extracted directly from selected sequence
      'cashBankLedgerId': _selectedCashBankLedger!['LedgerID'] ?? _selectedCashBankLedger!['ledgerID'] ?? _selectedCashBankLedger!['ledger_id'],
      'nepaliDate': _dateController.text,
      'adDate': DateFormat('yyyy-MM-dd').format(_selectedAdDate),
      'remarks': _remarksController.text.trim(),
      'items': _gridRows.map((r) => {
        'ledgerId': r['ledger']['LedgerID'] ?? r['ledger']['ledgerID'] ?? r['ledger']['ledger_id'],
        'cashBankType': r['type'],
        'amount': r['amount'],
        'narration': r['narrationController'].text.trim(),
      }).toList(),
    };

    try {
      final res = await _apiService.submitCashBankVoucher(payload);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSaving = false;
      });

      if (res['success'] == true) {
        // 🌟 Passing down the dynamically calculated netAmount back from API
        _showSuccessPopup(
          res['voucherId'] ?? _voucherNoController.text, 
          res['netAmount']
        );
      } else {
        _showSnack(res['message'] ?? 'Failed to save voucher.', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() { _isSubmitting = false; _isSaving = false; });
      _showSnack('Error: $e', isError: true);
    }
  }

  // 🌟 Captures the exact netAmount populated into the database
  void _showSuccessPopup(String voucherNo, [dynamic netAmount]) {
    // If backend doesn't explicitly return netAmount, fall back to our local calc
    final double displayAmount = netAmount != null
        ? double.tryParse(netAmount.toString()) ?? (_derivedCashBankType == 'R' ? _totalCredit : _totalDebit)
        : (_derivedCashBankType == 'R' ? _totalCredit : _totalDebit);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Voucher Saved Successfully!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Voucher No: $voucherNo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildPopupDetailRow('Account:', (_selectedCashBankLedger?['LedgerName'] ?? '').toString()),
                  const SizedBox(height: 6),
                  _buildPopupDetailRow('Total Amount:', 'Rs. ${displayAmount.toStringAsFixed(2)}'), // Accurate
                  const SizedBox(height: 6),
                  _buildPopupDetailRow('Date:', _dateController.text),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close sheet
                      Navigator.pop(context); // Exit screen
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Back to List'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close sheet
                      setState(() {
                        _gridRows.clear();
                        _remarksController.clear();
                        _initializeDates();
                        _loadVoucherSequences();
                        _addNewRow();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('New Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cashBankName = _selectedCashBankLedger == null
        ? 'Select Cash / Bank A/C *'
        : (_selectedCashBankLedger!['LedgerName'] ?? _selectedCashBankLedger!['ledgerName'] ?? '').toString();

    final docTitle = _selectedSequence != null
        ? (_selectedSequence!['DocumentName'] ?? 'Cash/Bank Voucher')
        : 'Cash/Bank Voucher';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text(docTitle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Type Selector Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: _primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DOCUMENT TYPE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(docTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (_availableSequences.length > 1)
                    OutlinedButton(
                      onPressed: _showSequenceSelectorDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Voucher No & Date Row
            Row(children: [
              Expanded(child: _buildTextField(label: 'Voucher No', controller: _voucherNoController, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(label: 'Date (BS)', controller: _dateController, suffixIcon: Icons.calendar_today, onTap: () => _selectSystemDate(context))),
            ]),
            const SizedBox(height: 16),

            // Main Cash/Bank Account Selector
            InkWell(
              onTap: _showCashBankLedgerSelection,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet, color: _primaryColor),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('CASH / BANK LEDGER', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(cashBankName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _selectedCashBankLedger == null ? Colors.blue : Colors.black87)),
                  ])),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Grid Items Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Voucher Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _addNewRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Row'),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0),
              ),
            ]),
            const SizedBox(height: 10),

            // Dynamic Rows List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _gridRows.length,
              itemBuilder: (_, i) => _buildRowItem(i),
            ),
            const SizedBox(height: 20),

            // Remarks
            TextField(
              controller: _remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Remarks / Narration',
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Debit: ${_totalDebit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Text('Credit: ${_totalCredit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ])),
            SizedBox(
              height: 50, width: 160,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitVoucher,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Voucher', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRowItem(int i) {
    final row = _gridRows[i];
    final ledgerObj = row['ledger'];
    final ledgerName = ledgerObj == null ? 'Select Ledger...' : (ledgerObj['LedgerName'] ?? ledgerObj['ledgerName'] ?? '').toString();

    row['type'] = _derivedCashBankType;
    final isReceipt = row['type'] == 'R';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () => _showRowLedgerSelection(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Text(ledgerName, style: TextStyle(color: ledgerObj == null ? Colors.grey : Colors.black87, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isReceipt ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isReceipt ? Colors.orange.shade200 : Colors.green.shade200),
            ),
            child: Text(
              isReceipt ? 'Receipt' : 'Payment',
              style: TextStyle(
                color: isReceipt ? Colors.orange.shade800 : Colors.green.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeRow(i)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: row['amountController'],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (Rs)', isDense: true, border: OutlineInputBorder()),
              onChanged: (val) {
                row['amount'] = double.tryParse(val) ?? 0.0;
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row['narrationController'],
              decoration: const InputDecoration(labelText: 'Narration', isDense: true, border: OutlineInputBorder()),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, IconData? suffixIcon, VoidCallback? onTap, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: onTap != null,
          enabled: enabled,
          onTap: onTap,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: Icon(suffixIcon, size: 20),
            filled: !enabled, fillColor: enabled ? Colors.white : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
