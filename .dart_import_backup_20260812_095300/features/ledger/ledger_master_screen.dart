import 'package:flutter/material.dart';
import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/utils/toast_service.dart';

class LedgerMasterScreen extends StatefulWidget {
  const LedgerMasterScreen({super.key});

  @override
  State<LedgerMasterScreen> createState() => _LedgerMasterScreenState();
}

class _LedgerMasterScreenState extends State<LedgerMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

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

  final List<String> _ledgerTypes = ['Customer', 'Vendor', 'Both', 'Other'];
  List<Map<String, dynamic>> _accGroups = []; 

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

  /// Fetches Account Groups from database with a built-in safe fallback
  Future<void> _loadAccountGroups() async {
    try {
      final groups = await _apiService.fetchAccountGroups();
      if (mounted) {
        setState(() {
          _accGroups = groups.isNotEmpty ? groups : [
            {'AccGrpID': 1, 'AccName': 'Sundry Creditors'},
            {'AccGrpID': 2, 'AccName': 'Sundry Debtors'},
          ];
          _isLoadingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _accGroups = [
            {'AccGrpID': 1, 'AccName': 'Sundry Creditors'},
            {'AccGrpID': 2, 'AccName': 'Sundry Debtors'},
          ];
          _isLoadingGroups = false;
        });
      }
    }
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

  Future<void> _generateCodeInstantly() async {
    final name = _nameController.text.trim();
    final type = _selectedType;

    if (name.isNotEmpty && type != null && type.isNotEmpty) {
      setState(() => _isGeneratingCode = true);

      final String prefix = '${name[0].toUpperCase()}${type[0].toUpperCase()}';
      final String? nextCode = await _apiService.fetchNextLedgerCode(prefix);
      
      if (nextCode != null && mounted) {
        setState(() {
          _codeController.text = nextCode;
        });
      }
      
      if (mounted) setState(() => _isGeneratingCode = false);
    }
  }

  Future<void> _verifyNameIsUnique() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && !_isCheckingName) {
      setState(() => _isCheckingName = true);
      
      final bool exists = await _apiService.checkLedgerNameExists(name);
      
      if (exists && mounted) {
        ToastService.show(context, 'A Ledger with the name "$name" already exists!', isError: true);
      }
      
      if (mounted) setState(() => _isCheckingName = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final ledgerData = {
          'ledgerName': _nameController.text.trim(),
          'ledgerCode': _codeController.text.trim(),
          'ledgerType': _selectedType == 'Customer' ? 'CU' : 
                        _selectedType == 'Vendor' ? 'VE' : 
                        _selectedType == 'Both' ? 'BO' : 'OT',
          'accGrpId': _selectedAccGrpId, 
          'panNo': _panController.text.trim(),
          'cashBank': _cashBank,
          'ledgerAddress': _addressController.text.trim(),
          'phoneNo': _phoneController.text.trim(),
          'ledgerEmail': _emailController.text.trim(),
        };

        await _apiService.createLedger(ledgerData);
        
        if (mounted) {
          ToastService.show(context, 'Ledger created successfully!', isError: false);
          Navigator.pop(context); 
        }
      } catch (e) {
        if (mounted) {
          final cleanError = e.toString().replaceAll('Exception: ', '');
          ToastService.show(context, 'Failed: $cleanError', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ledger Master'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Core Identifiers', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                decoration: const InputDecoration(labelText: 'Ledger Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                onChanged: (value) {
                  if (value.length == 1 && _selectedType != null) _generateCodeInstantly();
                },
                onEditingComplete: () {
                  FocusScope.of(context).nextFocus();
                  _generateCodeInstantly();
                  _verifyNameIsUnique(); 
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'Ledger Type *', border: OutlineInputBorder()),
                      items: _ledgerTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedType = val;
                          
                          // --- PRECISE AUTO-SELECTION LOGIC ---
                          if (val == 'Customer') {
                            final match = _accGroups.firstWhere(
                              (g) => g['AccName'].toString().trim().toLowerCase() == 'sundry debtors',
                              orElse: () => _accGroups.firstWhere(
                                (g) => g['AccName'].toString().toLowerCase().contains('debtors'),
                                orElse: () => {},
                              ),
                            );
                            if (match.isNotEmpty) {
                              _selectedAccGrpId = match['AccGrpID'] as int?;
                            }
                          } else if (val == 'Vendor') {
                            final match = _accGroups.firstWhere(
                              (g) => g['AccName'].toString().trim().toLowerCase() == 'sundry creditors',
                              orElse: () => _accGroups.firstWhere(
                                (g) => g['AccName'].toString().toLowerCase().contains('creditors'),
                                orElse: () => {},
                              ),
                            );
                            if (match.isNotEmpty) {
                              _selectedAccGrpId = match['AccGrpID'] as int?;
                            }
                          } else {
                            // For 'Both' or 'Other', reset so user can choose manually
                            _selectedAccGrpId = null; 
                          }
                        });
                        _generateCodeInstantly();
                      },
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ledger Code',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        suffixIcon: _isGeneratingCode ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Classification & Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              
              // A/C Group Dropdown
              _isLoadingGroups 
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : DropdownButtonFormField<int>(
                    initialValue: _selectedAccGrpId,
                    decoration: const InputDecoration(labelText: 'A/C Group *', border: OutlineInputBorder()),
                    items: _accGroups.map((g) {
                      return DropdownMenuItem<int>(
                        value: g['AccGrpID'] as int,
                        child: Text(g['AccName'].toString()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedAccGrpId = val),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _cashBank,
                decoration: const InputDecoration(labelText: 'Is this a Cash/Bank Ledger?', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Y', child: Text('Yes')),
                  DropdownMenuItem(value: 'N', child: Text('No')),
                ],
                onChanged: (val) => setState(() => _cashBank = val!),
              ),
              const SizedBox(height: 24),

              const Text('Contact & Tax Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              
              TextFormField(
                controller: _panController,
                decoration: const InputDecoration(
                  labelText: 'PAN No', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
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
                decoration: const InputDecoration(labelText: 'Full Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address', 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }
                        }
                        return null; 
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSubmitting || _isLoadingGroups ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Ledger', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}