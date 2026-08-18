import 'package:flutter/material.dart';
import 'package:sas_akount_login/services/banking/banking_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/core/services/toast_service.dart';

// ────────────────────────────────────────────────────────────
// DESIGN TOKENS
// A single neutral-ledger palette shared with Sales/Purchase/
// Outstanding screens, plus the same dual-accent system used
// there: emerald = inflow (Receipt), slate = outflow (Payment).
// The whole voucher — header, rows, dialogs, buttons — is
// tinted by whichever side the active document belongs to.
// ────────────────────────────────────────────────────────────
class _Tokens {
  static const Color textPrimary = Color(0xFF12142A);
  static const Color textSecondary = Color(0xFF6B7086);
  static const Color textMuted = Color(0xFF9CA0B4);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF6F7FB);
  static const Color border = Color(0xFFE7E9F1);
  static const Color borderStrong = Color(0xFFD8DBE6);

  // Receipt / inflow
  static const Color emerald = Color(0xFF0D9F6E);
  static const Color emeraldSoft = Color(0xFFE6F8F1);
  static const Color emeraldDark = Color(0xFF0B7F58);

  // Payment / outflow
  static const Color slate = Color(0xFF3B5BFB);
  static const Color slateSoft = Color(0xFFEEF1FF);
  static const Color slateDark = Color(0xFF2A44D6);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEF2F2);

  static const double rSm = 10;
  static const double rMd = 14;
  static const double rLg = 18;
  static const double rXl = 26;

  static const String mono = 'monospace';

  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(color: const Color(0xFF12142A).withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> glow(Color c) => [
        BoxShadow(color: c.withValues(alpha: 0.26), blurRadius: 18, offset: const Offset(0, 8)),
      ];
}

class CashBankEntryScreen extends StatefulWidget {
  const CashBankEntryScreen({super.key});
  @override
  State<CashBankEntryScreen> createState() => _CashBankEntryScreenState();
}

class _CashBankEntryScreenState extends State<CashBankEntryScreen> {
  final BankingService _apiService = BankingService();
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
      final sequences = await _apiService.fetchVoucherSequences();
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

  // ── Type / accent derivation (business logic unchanged) ──

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

  String _typeForSequence(Map<String, dynamic> seq) {
    final docType = (seq['documentType'] ?? seq['DocumentType'] ?? seq['DocumentName'] ?? '')
        .toString()
        .toUpperCase();
    if (docType.startsWith('R') || docType.contains('RECEIPT')) return 'R';
    return 'P';
  }

  bool get _isReceipt => _derivedCashBankType == 'R';
  Color get _accent => _isReceipt ? _Tokens.emerald : _Tokens.slate;
  Color get _accentSoft => _isReceipt ? _Tokens.emeraldSoft : _Tokens.slateSoft;
  Color get _accentDark => _isReceipt ? _Tokens.emeraldDark : _Tokens.slateDark;
  IconData get _accentIcon => _isReceipt ? Icons.call_received_rounded : Icons.call_made_rounded;
  String get _typeLabel => _isReceipt ? 'Receipt' : 'Payment';

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
                      const Text('Select Voucher Type',
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
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    shrinkWrap: true,
                    itemCount: _availableSequences.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final seq = _availableSequences[i];
                      final isSelected = _selectedSequence?['DocumentID'] == seq['DocumentID'];
                      final type = _typeForSequence(seq);
                      final tileAccent = type == 'R' ? _Tokens.emerald : _Tokens.slate;
                      final tileAccentSoft = type == 'R' ? _Tokens.emeraldSoft : _Tokens.slateSoft;
                      final tileIcon = type == 'R' ? Icons.call_received_rounded : Icons.call_made_rounded;
                      return _SelectableTile(
                        title: seq['DocumentName'] ?? 'Voucher',
                        subtitle: 'Prefix: ${seq['Prefix'] ?? '---'}',
                        icon: tileIcon,
                        accent: tileAccent,
                        accentSoft: tileAccentSoft,
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
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _accent)),
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

  double get _voucherTotal => _isReceipt ? _totalCredit : _totalDebit;

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
                accent: _accent,
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
                            iconColor: _accent,
                            iconBg: _accentSoft,
                            name: name.isNotEmpty ? name : 'Unnamed Account',
                            code: code,
                            pan: pan,
                            extraLine: [
                              if (address.isNotEmpty) address,
                              if (phone.isNotEmpty) 'Ph: $phone',
                            ].join('  ·  '),
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
                accent: _accent,
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
                            iconColor: _Tokens.textSecondary,
                            iconBg: _Tokens.canvas,
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
        ? double.tryParse(netAmount.toString()) ?? _voucherTotal
        : _voucherTotal;
    final accent = _accent;
    final accentSoft = _accentSoft;
    final label = _typeLabel;

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
                  color: accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.18), width: 6),
                ),
                child: Icon(Icons.check_rounded, color: accent, size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                '$label Saved Successfully',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _Tokens.textPrimary),
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
                    _buildPopupDetailRow('Total Amount', 'Rs. ${displayAmount.toStringAsFixed(2)}',
                        emphasize: true, accent: accent),
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
                      colors: [accent, _isReceipt ? _Tokens.emeraldDark : _Tokens.slateDark],
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

  Widget _buildPopupDetailRow(String label, String value, {bool emphasize = false, Color? accent}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _Tokens.textSecondary, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 15 : 13,
            fontWeight: FontWeight.w700,
            fontFamily: emphasize ? _Tokens.mono : null,
            color: emphasize ? (accent ?? _Tokens.textPrimary) : _Tokens.textPrimary,
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
        title: Row(
          children: [
            const Text(
              "Cash / Bank Entry",
              style: TextStyle(color: _Tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
            ),
            if (!_isLoadingSequences) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _typeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _accent, letterSpacing: 0.2),
                ),
              ),
            ],
          ],
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
                        _buildVoucherMetaCard(docTitle),
                        const SizedBox(height: 14),
                        _buildCashBankSelector(cashBankName),
                        const SizedBox(height: 24),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Entries (${_gridRows.length})',
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
                          _GhostAddButton(onTap: _addNewRow, color: _accent, bg: _accentSoft),
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

  // ── Header: voucher type + voucher no + date, one cohesive card ──
  Widget _buildVoucherMetaCard(String docTitle) {
    return Container(
      decoration: BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.circular(_Tokens.rLg),
        border: Border.all(color: _Tokens.border),
        boxShadow: _Tokens.shadowSm,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(_Tokens.rSm)),
                  child: Icon(_accentIcon, color: _accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('VOUCHER TYPE',
                          style: TextStyle(fontSize: 10.5, color: _Tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(docTitle, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Tokens.textPrimary)),
                    ],
                  ),
                ),
                if (_availableSequences.length > 1)
                  _ChipButton(label: 'Change', onTap: _showSequenceSelectorDialog, color: _accent, bg: _accentSoft),
              ],
            ),
          ),
          Divider(height: 1, color: _Tokens.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
            child: Row(
              children: [
                Expanded(
                  child: _metaField(
                    label: 'VOUCHER NO',
                    value: _voucherNoController.text,
                    mono: true,
                  ),
                ),
                Container(width: 1, height: 34, color: _Tokens.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(
                  child: _BouncingTap(
                    onTap: () => _selectSystemDate(context),
                    child: _metaField(
                      label: 'DATE (BS)',
                      value: _dateController.text,
                      trailingIcon: Icons.calendar_today_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaField({required String label, required String value, bool mono = false, IconData? trailingIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _Tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _Tokens.textPrimary,
                  fontFamily: mono ? _Tokens.mono : null,
                ),
              ),
            ),
            if (trailingIcon != null) Icon(trailingIcon, size: 15, color: _Tokens.textMuted),
          ],
        ),
      ],
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
          borderRadius: BorderRadius.circular(_Tokens.rLg),
          border: Border.all(color: isEmpty ? _accent.withValues(alpha: 0.4) : _Tokens.border, width: isEmpty ? 1.4 : 1),
          boxShadow: _Tokens.shadowSm,
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(_Tokens.rSm)),
            child: Icon(Icons.account_balance_wallet_rounded, color: _accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CASH / BANK ACCOUNT',
                    style: TextStyle(fontSize: 10.5, color: _Tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(
                  cashBankName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isEmpty ? _accent : _Tokens.textPrimary,
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
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
                          Text(_typeLabel.toUpperCase(),
                              style: TextStyle(fontSize: 10.5, color: _Tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(height: 3),
                          Text('Rs. ${_voucherTotal.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _accent, fontFamily: _Tokens.mono)),
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
                        colors: [_accent, _accentDark],
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

  Widget _buildRowItem(int i) {
    final row = _gridRows[i];
    final ledgerObj = row['ledger'];
    final ledgerName = ledgerObj == null ? 'Select ledger...' : (ledgerObj['LedgerName'] ?? ledgerObj['ledgerName'] ?? '').toString();
    final String rowType = row['type'] ?? _derivedCashBankType;
    final isReceiptRow = rowType == 'R';
    final rowAccent = isReceiptRow ? _Tokens.emerald : _Tokens.slate;
    final rowAccentSoft = isReceiptRow ? _Tokens.emeraldSoft : _Tokens.slateSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.circular(_Tokens.rMd),
        border: Border.all(color: _Tokens.border),
        boxShadow: _Tokens.shadowSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: rowAccentSoft, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    isReceiptRow ? 'CR' : 'DR',
                    style: TextStyle(color: rowAccent, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BouncingTap(
                    onTap: () => _showRowLedgerSelection(i),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ledgerName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ledgerObj == null ? _Tokens.textMuted : _Tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.unfold_more_rounded, size: 15, color: _Tokens.textMuted),
                      ],
                    ),
                  ),
                ),
                _BouncingTap(
                  onTap: () => _removeRow(i),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded, size: 18, color: _Tokens.textMuted),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _Tokens.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _RowInput(
                    controller: row['amountController'],
                    label: 'Amount (Rs)',
                    mono: true,
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
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// SHARED ANIMATED WIDGETS
// ────────────────────────────────────────────────────────────

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
  final bool mono;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _RowInput({
    required this.controller,
    required this.label,
    this.mono = false,
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
        textAlign: mono ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _Tokens.textPrimary,
          fontFamily: mono ? _Tokens.mono : null,
        ),
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
  final List<Color>? colors;

  const _PrimaryButton({required this.label, required this.onTap, this.loading = false, this.colors});

  @override
  Widget build(BuildContext context) {
    final gradientColors = colors ?? const [_Tokens.slate, _Tokens.slateDark];
    final disabled = onTap == null && !loading;
    return _BouncingTap(
      onTap: loading ? null : onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Tokens.rSm),
          gradient: disabled ? null : LinearGradient(colors: gradientColors),
          color: disabled ? _Tokens.borderStrong : null,
          boxShadow: disabled ? null : _Tokens.glow(gradientColors.first),
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
  final Color color;
  final Color bg;
  const _ChipButton({required this.label, required this.onTap, this.color = _Tokens.slate, this.bg = _Tokens.slateSoft});

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_Tokens.rLg),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

class _GhostAddButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final Color bg;
  const _GhostAddButton({required this.onTap, this.color = _Tokens.slate, this.bg = _Tokens.slateSoft});

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_Tokens.rSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: color),
            const SizedBox(width: 4),
            Text('Add Row', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
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
  final Color accent;
  final Color accentSoft;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.accentSoft,
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
          color: selected ? accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(_Tokens.rSm),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accentSoft, borderRadius: BorderRadius.circular(_Tokens.rSm)),
            child: Icon(icon, size: 18, color: accent),
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
          if (selected) Icon(Icons.check_circle_rounded, color: accent, size: 20),
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
  final Color accent;
  final TextEditingController searchController;
  final String searchHint;
  final VoidCallback onSearchChanged;
  final Widget child;

  const _SheetShell({
    required this.title,
    this.accent = _Tokens.slate,
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
                cursorColor: accent,
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
              decoration: const BoxDecoration(color: _Tokens.canvas, shape: BoxShape.circle),
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
          _skeleton(height: 96),
          const SizedBox(height: 14),
          _skeleton(height: 68),
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
        color: _Tokens.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(_Tokens.rMd),
      ),
    );
  }
}