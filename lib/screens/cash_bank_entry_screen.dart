import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/utils/toast_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────
class _Tokens {
  static const Color primary = Color(0xFF3B5BFB);
  static const Color primaryDark = Color(0xFF2A44D6);
  static const Color primarySoft = Color(0xFFEEF1FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF6F7FB);
  static const Color border = Color(0xFFE7E9F1);
  static const Color borderStrong = Color(0xFFD8DBE6);
  static const Color textPrimary = Color(0xFF13152B);
  static const Color textSecondary = Color(0xFF6B7086);
  static const Color textMuted = Color(0xFF9CA0B4);
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFECFDF3);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFF7ED);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEF2F2);

  static const double rSm = 10;
  static const double rMd = 14;
  static const double rLg = 20;
  static const double rXl = 26;

  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(color: const Color(0xFF13152B).withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> shadowGlow = [
    BoxShadow(color: primary.withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}

class CashBankEntryScreen extends StatefulWidget {
  const CashBankEntryScreen({super.key});
  @override
  State<CashBankEntryScreen> createState() => _CashBankEntryScreenState();
}

class _CashBankEntryScreenState extends State<CashBankEntryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _voucherNoController = TextEditingController(text: 'Loading...');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  late NepaliDateTime _selectedNepaliDate;
  late DateTime _selectedAdDate;
  Map<String, dynamic>? _selectedSequence;
  List<Map<String, dynamic>> _availableSequences = [];
  Map<String, dynamic>? _selectedCashBankLedger;
  final List<Map<String, dynamic>> _gridRows = [];
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isLoadingSequences = true;

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
    setState(() => _isLoadingSequences = true);
    try {
      final sequences = await _apiService.fetchVoucherSequences('CB');
      final filteredSequences = <Map<String, dynamic>>[];
      for (var seq in sequences) {
        final docName = (
          seq['DocumentName'] ??
          seq['documentName'] ??
          seq['DocumentType'] ??
          seq['documentType'] ??
          ''
        ).toString().toLowerCase();

        if (!docName.contains('contra')) {
          filteredSequences.add(seq);
        }
      }

      if (filteredSequences.isNotEmpty && mounted) {
        setState(() {
          _availableSequences = filteredSequences;
        });
        await _handleSequenceChange(filteredSequences.first);
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
    } finally {
      if (mounted) setState(() => _isLoadingSequences = false);
    }
  }

  String get _derivedCashBankType {
    if (_selectedSequence == null) return 'P';
    final docType = (_selectedSequence!['documentType'] ??
            _selectedSequence!['DocumentType'] ??
            _selectedSequence!['DocumentName'] ??
            '')
        .toString()
        .toUpperCase();
    if (docType.startsWith('R') || docType.contains('RECEIPT')) {
      return 'R';
    }
    return 'P';
  }

  Future<void> _handleSequenceChange(Map<String, dynamic> seq) async {
    setState(() {
      _selectedSequence = seq;
      _voucherNoController.text = _calculateVoucherId(seq);
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
      builder: (ctx) => _SmoothPopupContainer(
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: _Tokens.surface,
              borderRadius: BorderRadius.circular(_Tokens.rLg),
              boxShadow: _Tokens.shadowMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Document Type',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
                      _BouncingTap(
                        onTap: () => Navigator.pop(ctx),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.close_rounded, size: 20, color: _Tokens.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shrinkWrap: true,
                    itemCount: _availableSequences.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final seq = _availableSequences[i];
                      final isSelected = _selectedSequence?['DocumentID'] == seq['DocumentID'];
                      return _SelectableTile(
                        title: seq['DocumentName'] ?? 'Voucher',
                        subtitle: 'Prefix: ${seq['Prefix'] ?? '---'}',
                        icon: Icons.description_rounded,
                        selected: isSelected,
                        onTap: () {
                          _handleSequenceChange(seq);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
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
      builder: (context, child) => _SmoothPopupContainer(
        child: Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _Tokens.primary)),
          child: child!,
        ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: StatefulBuilder(builder: (ctx, setModal) {
            final filtered = cashBankLedgers.where((l) {
              final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString().toLowerCase();
              final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString().toLowerCase();
              final query = searchCtrl.text.toLowerCase();
              return name.contains(query) || code.contains(query);
            }).toList();
            return _SmoothPopupContainer(
              child: _SheetShell(
                title: 'Select Cash / Bank Account',
                searchController: searchCtrl,
                searchHint: 'Search Cash or Bank ledger...',
                onSearchChanged: () => setModal(() {}),
                child: filtered.isEmpty
                    ? const _EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No accounts found',
                        message: 'Make sure accounts are marked as Cash/Bank (Y) in Ledger Master.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final l = filtered[i];
                          final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString();
                          final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString();
                          final address = (l['LedgerAddress'] ?? l['ledgerAddress'] ?? '').toString();
                          final phone = (l['PhoneNo'] ?? l['phoneNo'] ?? l['MobileNo'] ?? '').toString();
                          final pan = (l['PanNo'] ?? l['panNo'] ?? '').toString();
                          return _LedgerTile(
                            icon: Icons.account_balance_rounded,
                            iconColor: _Tokens.primary,
                            iconBg: _Tokens.primarySoft,
                            name: name.isNotEmpty ? name : 'Unnamed Account',
                            code: code,
                            pan: pan,
                            extraLine: [
                              if (address.isNotEmpty) address,
                              if (phone.isNotEmpty) 'Ph: $phone',
                            ].join('  -  '),
                            onTap: () {
                              setState(() => _selectedCashBankLedger = l);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.78,
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

            return _SmoothPopupContainer(
              child: _SheetShell(
                title: 'Select Account Ledger',
                searchController: searchCtrl,
                searchHint: 'Search ledger name or code...',
                onSearchChanged: () => setModal(() {}),
                child: filtered.isEmpty
                    ? const _EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No ledgers found',
                        message: 'Try a different search term.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final l = filtered[i];
                          final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString();
                          final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString();
                          final address = (l['LedgerAddress'] ?? l['ledgerAddress'] ?? '').toString();
                          final pan = (l['PanNo'] ?? l['panNo'] ?? '').toString();
                          return _LedgerTile(
                            icon: Icons.receipt_long_rounded,
                            iconColor: _Tokens.success,
                            iconBg: _Tokens.successSoft,
                            name: name,
                            code: code,
                            pan: pan,
                            extraLine: address,
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

    final payload = {
      'documentName': _selectedSequence?['DocumentName'],
      'documentPrefix': _selectedSequence?['Prefix'],
      'cashBankLedgerId':
          _selectedCashBankLedger!['LedgerID'] ?? _selectedCashBankLedger!['ledgerID'] ?? _selectedCashBankLedger!['ledger_id'],
      'nepaliDate': _dateController.text,
      'adDate': DateFormat('yyyy-MM-dd').format(_selectedAdDate),
      'remarks': _remarksController.text.trim(),
      'items': _gridRows
          .map((r) => {
                'ledgerId': r['ledger']['LedgerID'] ?? r['ledger']['ledgerID'] ?? r['ledger']['ledger_id'],
                'cashBankType': r['type'],
                'amount': r['amount'],
                'narration': r['narrationController'].text.trim(),
              })
          .toList(),
    };

    try {
      final res = await _apiService.submitCashBankVoucher(payload);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSaving = false;
      });
      if (res['success'] == true) {
        _showSuccessPopup(res['voucherId'] ?? _voucherNoController.text, res['netAmount']);
      } else {
        _showSnack(res['message'] ?? 'Failed to save voucher.', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() { _isSubmitting = false; _isSaving = false; });
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSuccessPopup(String voucherNo, [dynamic netAmount]) {
    final double displayAmount = netAmount != null
        ? double.tryParse(netAmount.toString()) ?? (_derivedCashBankType == 'R' ? _totalCredit : _totalDebit)
        : (_derivedCashBankType == 'R' ? _totalCredit : _totalDebit);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmoothPopupContainer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: const BoxDecoration(
            color: _Tokens.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_Tokens.rXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _Tokens.successSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Tokens.success.withOpacity(0.15), width: 6),
                ),
                child: const Icon(Icons.check_rounded, color: _Tokens.success, size: 32),
              ),
              const SizedBox(height: 18),
              const Text(
                'Voucher Saved Successfully',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _Tokens.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Voucher No: $voucherNo',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _Tokens.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Tokens.canvas,
                  borderRadius: BorderRadius.circular(_Tokens.rMd),
                  border: Border.all(color: _Tokens.border),
                ),
                child: Column(
                  children: [
                    _buildPopupDetailRow('Account', (_selectedCashBankLedger?['LedgerName'] ?? '').toString()),
                    const SizedBox(height: 10),
                    _buildPopupDetailRow('Total Amount', 'Rs. ${displayAmount.toStringAsFixed(2)}', emphasize: true),
                    const SizedBox(height: 10),
                    _buildPopupDetailRow('Date', _dateController.text),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryButton(
                      label: 'Back to List',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryButton(
                      label: 'New Entry',
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _gridRows.clear();
                          _remarksController.clear();
                          _initializeDates();
                          _loadVoucherSequences();
                          _addNewRow();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupDetailRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _Tokens.textSecondary, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 15 : 13,
            fontWeight: FontWeight.w700,
            color: emphasize ? _Tokens.primary : _Tokens.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(context, msg, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final cashBankName = _selectedCashBankLedger == null
        ? 'Select Cash / Bank A/C'
        : (_selectedCashBankLedger!['LedgerName'] ?? _selectedCashBankLedger!['ledgerName'] ?? '').toString();

    final docTitle =
        _selectedSequence != null ? (_selectedSequence!['DocumentName'] ?? 'Cash/Bank Voucher') : 'Cash/Bank Voucher';

    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = screenWidth > 720 ? 720.0 : screenWidth;

    return Scaffold(
      backgroundColor: _Tokens.canvas,
      appBar: AppBar(
        backgroundColor: _Tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: _BouncingTap(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration: BoxDecoration(
                color: _Tokens.canvas,
                borderRadius: BorderRadius.circular(_Tokens.rSm),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _Tokens.textPrimary, size: 18),
            ),
          ),
        ),
        title: const Text(
          "Cash/Bank Entry",
          style: TextStyle(color: _Tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _Tokens.border),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: _isLoadingSequences
                ? const _LoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDocTypeCard(docTitle),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: _buildTextField(
                              label: 'Voucher No',
                              controller: _voucherNoController,
                              enabled: false,
                              icon: Icons.confirmation_number_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              label: 'Date (BS)',
                              controller: _dateController,
                              suffixIcon: Icons.calendar_today_rounded,
                              onTap: () => _selectSystemDate(context),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _buildCashBankSelector(cashBankName),
                        const SizedBox(height: 24),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Voucher Entries (${_gridRows.length})',
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
                          _GhostAddButton(onTap: _addNewRow),
                        ]),
                        const SizedBox(height: 12),
                        if (_gridRows.isEmpty)
                          const _EmptyState(
                            icon: Icons.list_alt_rounded,
                            title: 'No entries yet',
                            message: 'Tap "Add Row" to start adding voucher entries.',
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _gridRows.length,
                            itemBuilder: (_, i) => _buildRowItem(i),
                          ),
                        const SizedBox(height: 20),
                        _buildRemarksField(),
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _isLoadingSequences ? null : _buildBottomBar(maxContentWidth),
    );
  }

  Widget _buildDocTypeCard(String docTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.circular(_Tokens.rMd),
        border: Border.all(color: _Tokens.border),
        boxShadow: _Tokens.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Tokens.primarySoft,
              borderRadius: BorderRadius.circular(_Tokens.rSm),
            ),
            child: const Icon(Icons.description_rounded, color: _Tokens.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DOCUMENT TYPE',
                    style: TextStyle(fontSize: 10.5, color: _Tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(docTitle, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
              ],
            ),
          ),
          if (_availableSequences.length > 1)
            _ChipButton(label: 'Change', onTap: _showSequenceSelectorDialog),
        ],
      ),
    );
  }

  Widget _buildCashBankSelector(String cashBankName) {
    final isEmpty = _selectedCashBankLedger == null;
    return _BouncingTap(
      onTap: _showCashBankLedgerSelection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _Tokens.surface,
          gradient: LinearGradient(
            colors: [_Tokens.primary.withOpacity(0.06), _Tokens.primary.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_Tokens.rMd),
          border: Border.all(color: isEmpty ? _Tokens.primary.withOpacity(0.3) : _Tokens.border),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _Tokens.surface, borderRadius: BorderRadius.circular(_Tokens.rSm), boxShadow: _Tokens.shadowSm),
            child: const Icon(Icons.account_balance_wallet_rounded, color: _Tokens.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CASH / BANK LEDGER',
                    style: TextStyle(fontSize: 10.5, color: _Tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(
                  cashBankName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isEmpty ? _Tokens.primary : _Tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _Tokens.textMuted),
        ]),
      ),
    );
  }

  Widget _buildRemarksField() {
    return Container(
      decoration: BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.circular(_Tokens.rMd),
        border: Border.all(color: _Tokens.border),
      ),
      child: TextField(
        controller: _remarksController,
        maxLines: 2,
        style: const TextStyle(fontSize: 14, color: _Tokens.textPrimary),
        decoration: const InputDecoration(
          labelText: 'Remarks / Narration',
          labelStyle: TextStyle(color: _Tokens.textSecondary, fontSize: 13.5),
          contentPadding: EdgeInsets.all(16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildBottomBar(double maxContentWidth) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: _Tokens.surface,
          border: const Border(top: BorderSide(color: _Tokens.border)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _totalsRow('Debit', _totalDebit, _Tokens.success),
                          const SizedBox(height: 4),
                          _totalsRow('Credit', _totalCredit, _Tokens.warning),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 50,
                      width: 168,
                      child: _PrimaryButton(
                        label: 'Save Voucher',
                        loading: _isSaving,
                        onTap: _isSaving ? null : _submitVoucher,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsRow(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ', style: const TextStyle(fontSize: 12.5, color: _Tokens.textSecondary, fontWeight: FontWeight.w500)),
        Text('Rs. ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildRowItem(int i) {
    final row = _gridRows[i];
    final ledgerObj = row['ledger'];
    final ledgerName = ledgerObj == null ? 'Select Ledger...' : (ledgerObj['LedgerName'] ?? ledgerObj['ledgerName'] ?? '').toString();
    final String rowType = row['type'] ?? _derivedCashBankType;
    final isReceipt = rowType == 'R';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.circular(_Tokens.rMd),
        border: Border.all(color: _Tokens.border),
        boxShadow: _Tokens.shadowSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: isReceipt ? _Tokens.warningSoft : _Tokens.successSoft,
                  borderRadius: BorderRadius.circular(_Tokens.rSm),
                ),
                child: Text(
                  isReceipt ? 'Rec' : 'Pay',
                  style: TextStyle(
                    color: isReceipt ? _Tokens.warning : _Tokens.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BouncingTap(
                  onTap: () => _showRowLedgerSelection(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _Tokens.canvas,
                      borderRadius: BorderRadius.circular(_Tokens.rSm),
                      border: Border.all(color: _Tokens.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ledgerName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ledgerObj == null ? _Tokens.textMuted : _Tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(Icons.unfold_more_rounded, size: 16, color: _Tokens.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _BouncingTap(
                onTap: () => _showRowLedgerSelection(i),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.transparent,
                  child: const Icon(Icons.edit_outlined, color: _Tokens.primary, size: 20),
                ),
              ),
              _BouncingTap(
                onTap: () => _removeRow(i),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.transparent,
                  child: const Icon(Icons.delete_outline_rounded, color: _Tokens.danger, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _RowInput(
                  controller: row['amountController'],
                  label: 'Amount (Rs)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  onChanged: (val) {
                    row['amount'] = double.tryParse(val) ?? 0.0;
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _RowInput(
                  controller: row['narrationController'],
                  label: 'Narration',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? suffixIcon,
    IconData? icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    Widget fieldContainer = Container(
      decoration: BoxDecoration(
        color: enabled ? _Tokens.surface : _Tokens.canvas,
        borderRadius: BorderRadius.circular(_Tokens.rSm),
        border: Border.all(color: _Tokens.border),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: onTap != null,
        enabled: enabled,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Tokens.textPrimary),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: icon != null ? Icon(icon, size: 18, color: _Tokens.textMuted) : null,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18, color: _Tokens.textMuted) : null,
          border: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );

    if (onTap != null) {
      fieldContainer = _BouncingTap(
        onTap: onTap,
        child: AbsorbPointer(child: fieldContainer),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _Tokens.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        fieldContainer,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SHARED ANIMATED WIDGETS
// ─────────────────────────────────────────────────────────────────────────

/// Ultra-Smooth Popup Transition (Scales and Fades seamlessly)
class _SmoothPopupContainer extends StatelessWidget {
  final Widget child;

  const _SmoothPopupContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      builder: (context, value, childWidget) {
        return Transform.scale(
          scale: 0.92 + (0.08 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

/// Custom Bouncing Tap Effect for Buttons, Tiles, and Cards
class _BouncingTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BouncingTap({required this.child, this.onTap});

  @override
  State<_BouncingTap> createState() => _BouncingTapState();
}

class _BouncingTapState extends State<_BouncingTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;
    
    _controller.forward();
    await Future.delayed(const Duration(milliseconds: 70));
    if (mounted) _controller.reverse();
    await Future.delayed(const Duration(milliseconds: 90));
    if (mounted) widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onTapDown: (_) {
        if (widget.onTap != null) _controller.forward();
      },
      onTapCancel: () {
        if (widget.onTap != null) _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class _RowInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _RowInput({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Tokens.canvas,
        borderRadius: BorderRadius.circular(_Tokens.rSm),
        border: Border.all(color: _Tokens.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tokens.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11.5, color: _Tokens.textMuted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const _PrimaryButton({required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: loading ? null : onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Tokens.rSm),
          gradient: onTap == null && !loading
              ? null
              : const LinearGradient(colors: [_Tokens.primary, _Tokens.primaryDark]),
          color: (onTap == null && !loading) ? _Tokens.borderStrong : null,
          boxShadow: onTap != null ? _Tokens.shadowGlow : null,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Tokens.rSm),
          border: Border.all(color: _Tokens.border),
          color: Colors.transparent,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _Tokens.textPrimary)),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _Tokens.primarySoft,
          borderRadius: BorderRadius.circular(_Tokens.rLg),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Tokens.primary)),
      ),
    );
  }
}

class _GhostAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GhostAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _Tokens.primarySoft,
          borderRadius: BorderRadius.circular(_Tokens.rSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: _Tokens.primary),
            const SizedBox(width: 4),
            const Text('Add Row', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _Tokens.primary)),
          ],
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _Tokens.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(_Tokens.rSm),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _Tokens.canvas, borderRadius: BorderRadius.circular(_Tokens.rSm)),
            child: Icon(icon, size: 18, color: _Tokens.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: _Tokens.textSecondary)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle_rounded, color: _Tokens.primary, size: 20),
        ]),
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String name;
  final String code;
  final String pan;
  final String extraLine;
  final VoidCallback onTap;

  const _LedgerTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.name,
    required this.code,
    required this.pan,
    required this.extraLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _Tokens.surface,
          borderRadius: BorderRadius.circular(_Tokens.rMd),
          border: Border.all(color: _Tokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(_Tokens.rSm)),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _Tokens.textPrimary)),
                  const SizedBox(height: 4),
                  if (code.isNotEmpty || pan.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (code.isNotEmpty) _MetaTag('Code: $code'),
                        if (pan.isNotEmpty) _MetaTag('PAN: $pan'),
                      ],
                    ),
                  if (extraLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      extraLine,
                      style: const TextStyle(fontSize: 11.5, color: _Tokens.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _Tokens.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String text;
  const _MetaTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11.5, color: _Tokens.textSecondary, fontWeight: FontWeight.w500));
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final String searchHint;
  final VoidCallback onSearchChanged;
  final Widget child;

  const _SheetShell({
    required this.title,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_Tokens.rXl)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: _Tokens.borderStrong, borderRadius: BorderRadius.circular(2)),
          ),
          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _Tokens.canvas,
                borderRadius: BorderRadius.circular(_Tokens.rSm),
                border: Border.all(color: _Tokens.border),
              ),
              child: TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                style: const TextStyle(fontSize: 14, color: _Tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: searchHint,
                  hintStyle: const TextStyle(color: _Tokens.textMuted, fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: _Tokens.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: _Tokens.canvas, shape: BoxShape.circle),
              child: Icon(icon, size: 26, color: _Tokens.textMuted),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _Tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeleton(height: 64),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _skeleton(height: 58)),
            const SizedBox(width: 12),
            Expanded(child: _skeleton(height: 58)),
          ]),
          const SizedBox(height: 14),
          _skeleton(height: 72),
          const SizedBox(height: 24),
          _skeleton(height: 18, width: 140),
          const SizedBox(height: 12),
          _skeleton(height: 110),
        ],
      ),
    );
  }

  Widget _skeleton({required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: _Tokens.border.withOpacity(0.6),
        borderRadius: BorderRadius.circular(_Tokens.rMd),
      ),
    );
  }
}