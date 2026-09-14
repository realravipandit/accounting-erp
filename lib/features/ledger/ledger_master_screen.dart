import 'package:flutter/material.dart';
import 'package:sas_app/services/ledger/ledger_service.dart';
import 'package:sas_app/core/services/toast_service.dart';

/// ===================================================================
/// DESIGN CONCEPT — "Ledger Sheet"
/// ---------------------------------------------------------------
/// Grounded in the subject matter itself: a paper ledger card being
/// filled out and stamped. One sheet (not three identical boxed
/// cards), hairline-divided sections, underline-register inputs,
/// and a single bold moment — the ledger code renders as a rotated
/// ink-stamp once generated. Accent is a bank-ledger seal green,
/// not a generic SaaS blue/violet.
/// ===================================================================
class LedgerMasterScreen extends StatefulWidget {
  const LedgerMasterScreen({super.key});

  @override
  State<LedgerMasterScreen> createState() => _LedgerMasterScreenState();
}

class _LedgerMasterScreenState extends State<LedgerMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final LedgerService _apiService = LedgerService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();

  String? _selectedType;
  int? _selectedAccGrpId;
  String _cashBank = 'N';

  bool _isGeneratingCode = false;
  bool _isSubmitting = false;
  bool _isCheckingName = false;
  bool _isLoadingGroups = true;

  final List<String> _ledgerTypes = [
    'Customer',
    'Vendor',
    'Both',
    'Other',
  ];

  List<Map<String, dynamic>> _accGroups = [];

  // ===============================================
  // "LEDGER SHEET" PALETTE
  // ===============================================
  static const Color _page = Color(0xFFF3F4F1); // warm paper backdrop
  static const Color _sheet = Colors.white; // the ledger sheet itself
  static const Color _ink = Color(0xFF14171C); // near-black ink
  static const Color _inkSoft = Color(0xFF2A2E35);
  static const Color _muted = Color(0xFF767C87); // ash grey
  static const Color _hairline = Color(0xFFE3E5E0);
  static const Color _seal = Color(0xFF1E6B4E); // ledger-stamp green
  static const Color _sealSoft = Color(0xFFE7F1EC);
  static const Color _danger = Color(0xFFB3402D);

  @override
  void initState() {
    super.initState();
    _loadAccountGroups();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        _verifyNameIsUnique();
      }
    });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // =========================================
  // LOAD ACCOUNT GROUPS
  // =========================================
  Future<void> _loadAccountGroups() async {
    try {
      final groups = await _apiService.fetchAccountGroups();
      if (!mounted) return;
      setState(() {
        _accGroups = groups.isNotEmpty
            ? groups
            : [
                {'AccGrpID': 1, 'AccName': 'Sundry Creditors'},
                {'AccGrpID': 2, 'AccName': 'Sundry Debtors'},
              ];
        _isLoadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accGroups = [
          {'AccGrpID': 1, 'AccName': 'Sundry Creditors'},
          {'AccGrpID': 2, 'AccName': 'Sundry Debtors'},
        ];
        _isLoadingGroups = false;
      });
    }
  }

  // =========================================
  // GENERATE LEDGER CODE
  // =========================================
  Future<void> _generateCodeInstantly() async {
    final name = _nameController.text.trim();
    final type = _selectedType;

    if (name.isEmpty || type == null || type.isEmpty) {
      return;
    }

    if (_isGeneratingCode) {
      return;
    }

    setState(() {
      _isGeneratingCode = true;
    });

    try {
      final String prefix = '${name[0].toUpperCase()}${type[0].toUpperCase()}';
      final String? nextCode = await _apiService.fetchNextLedgerCode(prefix);

      if (!mounted) return;

      if (nextCode != null && nextCode.isNotEmpty) {
        setState(() {
          _codeController.text = nextCode;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context,
          'Failed to generate ledger code',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingCode = false;
        });
      }
    }
  }

  // =========================================
  // CHECK LEDGER NAME
  // =========================================
  Future<void> _verifyNameIsUnique() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _isCheckingName) {
      return;
    }

    setState(() {
      _isCheckingName = true;
    });

    try {
      final bool exists = await _apiService.checkLedgerNameExists(name);

      if (!mounted) return;

      if (exists) {
        ToastService.show(
          context,
          'A Ledger with the name "$name" already exists!',
          isError: true,
        );
      }
    } catch (e) {
      // Background check error handled silently
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingName = false;
        });
      }
    }
  }

  // =========================================
  // SUBMIT FORM
  // =========================================
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ledgerData = {
        'ledgerName': _nameController.text.trim(),
        'ledgerCode': _codeController.text.trim(),
        'ledgerType': _selectedType == 'Customer'
            ? 'CU'
            : _selectedType == 'Vendor'
                ? 'VE'
                : _selectedType == 'Both'
                    ? 'BO'
                    : 'OT',
        'accGrpId': _selectedAccGrpId,
        'panNo': _panController.text.trim(),
        'cashBank': _cashBank,
        'ledgerAddress': _addressController.text.trim(),
        'phoneNo': _phoneController.text.trim(),
        'ledgerEmail': _emailController.text.trim(),
      };

      await _apiService.createLedger(ledgerData);

      if (!mounted) return;

      ToastService.show(
        context,
        'Ledger created successfully!',
        isError: false,
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      final cleanError = e.toString().replaceAll('Exception: ', '');

      ToastService.show(
        context,
        'Failed: $cleanError',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // =========================================
  // TYPE CHANGE — auto-select account group (unchanged logic)
  // =========================================
  void _onTypeChanged(String? val) {
    setState(() {
      _selectedType = val;

      if (val == 'Customer') {
        final match = _accGroups.firstWhere(
          (g) => g['AccName'].toString().trim().toLowerCase() == 'sundry debtors',
          orElse: () => _accGroups.firstWhere(
            (g) => g['AccName'].toString().toLowerCase().contains('debtors'),
            orElse: () => <String, dynamic>{},
          ),
        );
        if (match.isNotEmpty) {
          _selectedAccGrpId =
              match['AccGrpID'] is int ? match['AccGrpID'] as int : int.tryParse(match['AccGrpID'].toString());
        }
      } else if (val == 'Vendor') {
        final match = _accGroups.firstWhere(
          (g) => g['AccName'].toString().trim().toLowerCase() == 'sundry creditors',
          orElse: () => _accGroups.firstWhere(
            (g) => g['AccName'].toString().toLowerCase().contains('creditors'),
            orElse: () => <String, dynamic>{},
          ),
        );
        if (match.isNotEmpty) {
          _selectedAccGrpId =
              match['AccGrpID'] is int ? match['AccGrpID'] as int : int.tryParse(match['AccGrpID'].toString());
        }
      } else {
        _selectedAccGrpId = null;
      }
    });

    _generateCodeInstantly();
  }

  // =========================================
  // BUILD
  // =========================================
  @override
  Widget build(BuildContext context) {
    final bool containsSelectedGroup = _selectedAccGrpId != null &&
        _accGroups.any((g) {
          final rawId = g['AccGrpID'];
          final id = rawId is int ? rawId : int.tryParse(rawId.toString());
          return id == _selectedAccGrpId;
        });

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _page,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text(
          'New ledger entry',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        child: Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              color: _sheet,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _hairline),
              boxShadow: [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _identityStrip(),
                _hairlineDivider(),
                _sectionBlock(
                  label: 'Identity',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      style: const TextStyle(color: _ink, fontSize: 15),
                      decoration: _registerDecoration(
                        label: 'Ledger name',
                        hint: 'e.g. Himalayan Enterprises',
                        suffix: _isCheckingName ? _miniSpinner() : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {}); // refresh identity strip preview
                        if (value.length == 1 && _selectedType != null) {
                          _generateCodeInstantly();
                        }
                      },
                      onEditingComplete: () {
                        FocusScope.of(context).nextFocus();
                        _generateCodeInstantly();
                        _verifyNameIsUnique();
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      dropdownColor: _sheet,
                      style: const TextStyle(color: _ink, fontSize: 15),
                      decoration: _registerDecoration(label: 'Ledger type'),
                      items: _ledgerTypes.map((t) {
                        return DropdownMenuItem<String>(value: t, child: Text(t));
                      }).toList(),
                      onChanged: _onTypeChanged,
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                  ],
                ),
                _hairlineDivider(),
                _sectionBlock(
                  label: 'Classification',
                  children: [
                    _isLoadingGroups
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.0),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _seal),
                            ),
                          )
                        : DropdownButtonFormField<int>(
                            initialValue: containsSelectedGroup ? _selectedAccGrpId : null,
                            dropdownColor: _sheet,
                            style: const TextStyle(color: _ink, fontSize: 15),
                            decoration: _registerDecoration(label: 'Account group'),
                            items: _accGroups.map((g) {
                              final rawId = g['AccGrpID'];
                              final int? groupId = rawId is int ? rawId : int.tryParse(rawId.toString());
                              return DropdownMenuItem<int>(
                                value: groupId,
                                child: Text(g['AccName']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAccGrpId = val;
                              });
                            },
                            validator: (value) => value == null ? 'Required' : null,
                          ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Cash or bank ledger',
                            style: TextStyle(fontSize: 14.5, color: _ink, fontWeight: FontWeight.w500),
                          ),
                        ),
                        _sealSwitch(),
                      ],
                    ),
                  ],
                ),
                _hairlineDivider(),
                _sectionBlock(
                  label: 'Contact & tax',
                  children: [
                    TextFormField(
                      controller: _panController,
                      style: const TextStyle(color: _ink, fontSize: 15, fontFamily: 'monospace'),
                      decoration: _registerDecoration(label: 'PAN no.', hint: '9-digit registration number'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final panRegex = RegExp(r'^\d{9}$');
                          if (!panRegex.hasMatch(value.trim())) {
                            return 'PAN must be exactly 9 digits';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      style: const TextStyle(color: _ink, fontSize: 15),
                      decoration: _registerDecoration(label: 'Full address', hint: 'Street, city, ward'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: _ink, fontSize: 15),
                      decoration: _registerDecoration(label: 'Phone', hint: '98XXXXXXXX'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: _ink, fontSize: 15),
                      decoration: _registerDecoration(label: 'Email', hint: 'office@company.com'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting || _isLoadingGroups ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              disabledBackgroundColor: _ink.withValues(alpha: 0.35),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save ledger',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  // ===============================================
  // IDENTITY STRIP — the one bold moment: a live
  // "stamped" preview of name + code as it's typed.
  // ===============================================
  Widget _identityStrip() {
    final name = _nameController.text.trim();
    final hasCode = _codeController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              name.isEmpty ? 'Unnamed ledger' : name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: name.isEmpty ? _muted : _ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: hasCode
                ? Transform.rotate(
                    key: ValueKey(_codeController.text),
                    angle: -0.035,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _sealSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _seal.withValues(alpha: 0.5), width: 1.2),
                      ),
                      child: Text(
                        _codeController.text.trim(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _seal,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  )
                : (_isGeneratingCode
                    ? const Padding(
                        key: ValueKey('spinner'),
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _seal),
                        ),
                      )
                    : Text(
                        key: const ValueKey('pending'),
                        'Code pending',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _muted.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _hairlineDivider() {
    return const Divider(height: 1, thickness: 1, color: _hairline);
  }

  Widget _sectionBlock({required String label, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(color: _seal, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _miniSpinner() {
    return const Padding(
      padding: EdgeInsets.all(10),
      child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _seal)),
    );
  }

  Widget _sealSwitch() {
    final isYes = _cashBank == 'Y';
    return GestureDetector(
      onTap: () => setState(() => _cashBank = isYes ? 'N' : 'Y'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isYes ? _seal : _hairline,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: isYes ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }

  // Filled, bordered "ledger cell" input — reads as a clear fillable
  // form field (not a bare underline), while keeping the sheet's
  // paper/ink character: soft grey fill, sharp-ish 8px corners,
  // seal-green focus ring.
  InputDecoration _registerDecoration({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFAEB3AC)),
      labelStyle: const TextStyle(fontSize: 13.5, color: _muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(fontSize: 13, color: _seal, fontWeight: FontWeight.w600),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F8F6),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _hairline, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _hairline, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _seal, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _danger, width: 1.8),
      ),
      errorStyle: const TextStyle(color: _danger, fontSize: 11.5),
    );
  }
}