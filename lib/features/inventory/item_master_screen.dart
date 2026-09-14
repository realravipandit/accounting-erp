import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sas_app/services/inventory/inventory_service.dart';
import 'package:intl/intl.dart';
import 'package:sas_app/core/services/toast_service.dart';

// --- Self-contained palette. No external theme dependency. ---
// Grounded in the physical vocabulary of stock rooms: shelf tags,
// bin labels, price stickers. Quiet teal ink, one warm amber
// reserved for the single generated thing on the page — the code.
class _Deck {
  static const ground = Color(0xFFF3F6F5);
  static const panel = Color(0xFFFFFFFF);
  static const rule = Color(0xFFE1E7E4);
  static const ink = Color(0xFF1C332F);
  static const inkSoft = Color(0xFF6D7C78);
  static const teal = Color(0xFF1F6F64);
  static const tealDeep = Color(0xFF15514A);
  static const tag = Color(0xFFE2A33B);
  static const tagInk = Color(0xFF5B3C0C);
  static const warn = Color(0xFFB5473A);
}

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventoryService _apiService = InventoryService();
  bool _isLoading = false;

  // --- Controllers ---
  final _itemNameController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _skuController = TextEditingController();
  final _hssCodeController = TextEditingController();
  final _groupController = TextEditingController();
  final _subGroupController = TextEditingController();
  final _altQtyController = TextEditingController();
  final _qtyController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _salesPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _tradePriceController = TextEditingController();
  final _mrRateController = TextEditingController();
  final _rateController = TextEditingController(text: '13.00');
  final _mfgDateController = TextEditingController();
  final _expDateController = TextEditingController();

  // --- State Variables ---
  String _selectedItemType = 'Inventory Item';
  String _vatStatus = 'Yes';
  List<Map<String, dynamic>> _availableUnits = [];
  int? _selectedUnitId;
  int? _selectedAltUnitId;

  // Dynamic Groups & SubGroups
  List<Map<String, dynamic>> _itemGroups = [];
  List<Map<String, dynamic>> _itemSubGroups = [];
  Map<String, dynamic>? _selectedGroup;
  Map<String, dynamic>? _selectedSubGroup;

  bool _enableAltUnit = false;
  String _lastGeneratedPrefix = '';
  TextEditingController? _autoCompleteController;

  // --- Live item-name search ---
  List<Map<String, dynamic>> _itemSearchResults = [];
  Timer? _searchDebounce;

  final List<String> _itemTypes = [
    'Inventory Item',
    'Service Item',
    'Fixed Asset',
  ];
  final List<String> _vatOptions = ['Yes', 'No'];

  @override
  void initState() {
    super.initState();
    _fetchUnitsFromDb();
    _fetchGroupsFromDb();
  }

  Future<void> _fetchUnitsFromDb() async {
    try {
      final units = await _apiService.getUnits();
      final mappedUnits =
          units.map((unit) => Map<String, dynamic>.from(unit as Map)).toList();
      if (mounted) {
        setState(() {
          _availableUnits = mappedUnits;
        });
      }
    } catch (e) {
      debugPrint("API ERROR: Failed to fetch units: $e");
    }
  }

  Future<void> _fetchGroupsFromDb() async {
    try {
      final groups = await _apiService.getItemGroups();
      final mappedGroups = groups
          .map((group) => Map<String, dynamic>.from(group as Map))
          .toList();
      if (mounted) {
        setState(() {
          _itemGroups = mappedGroups;
        });
      }
    } catch (e) {
      debugPrint("API ERROR: Failed to fetch groups: $e");
    }
  }

  void _onGroupSelected(Map<String, dynamic> group) async {
    setState(() {
      _selectedGroup = group;
      _groupController.text =
          (group['GrpName'] ?? group['grpName'] ?? group['ItemGrpName'] ?? '')
              .toString();
      _selectedSubGroup = null;
      _subGroupController.clear();
      _itemSubGroups = [];
    });

    final dynamic rawGroupId = group['ItemGrpID'] ?? group['itemGrpID'];
    final int? groupId =
        rawGroupId is int ? rawGroupId : int.tryParse(rawGroupId?.toString() ?? '');

    if (groupId == null) {
      debugPrint("API ERROR: Selected group has no valid ItemGrpID");
      return;
    }

    try {
      final subGroups = await _apiService.getItemSubGroups(groupId);
      final mappedSubGroups = subGroups
          .map((subGroup) => Map<String, dynamic>.from(subGroup as Map))
          .toList();
      if (mounted) {
        setState(() {
          _itemSubGroups = mappedSubGroups;
        });
      }
    } catch (e) {
      debugPrint("API ERROR: Failed to fetch sub-groups: $e");
    }
  }

  Future<void> _generateItemCode(String prefix) async {
    setState(() => _itemCodeController.text = 'Loading...');
    try {
      final code = await _apiService.getNextItemCode(prefix);
      if (mounted) {
        setState(() {
          _itemCodeController.text = code ?? '';
          _lastGeneratedPrefix = prefix;
        });
      }
    } catch (e) {
      debugPrint("API ERROR: $e");
      if (mounted) {
        setState(() => _itemCodeController.text = '');
        ToastService.show(context, 'Code Gen Error: $e', isError: true);
      }
    }
  }

  // --- Live item-name search (debounced) ---
  Future<void> _searchItems(String query) async {
    if (query.trim().length < 2) {
      if (mounted) {
        setState(() => _itemSearchResults = []);
      }
      return;
    }
    try {
      final results = await _apiService.searchItemNames(query.trim());
      final mapped =
          results.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      if (mounted) {
        setState(() => _itemSearchResults = mapped);
      }
    } catch (e) {
      debugPrint("API ERROR: Failed to search items: $e");
    }
  }

  void _onItemNameChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchItems(text);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _itemNameController.dispose();
    _itemCodeController.dispose();
    _skuController.dispose();
    _hssCodeController.dispose();
    _groupController.dispose();
    _subGroupController.dispose();
    _altQtyController.dispose();
    _qtyController.dispose();
    _buyPriceController.dispose();
    _salesPriceController.dispose();
    _mrpController.dispose();
    _tradePriceController.dispose();
    _mrRateController.dispose();
    _rateController.dispose();
    _mfgDateController.dispose();
    _expDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _Deck.teal,
              onPrimary: Colors.white,
              onSurface: _Deck.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitItem() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedUnitId == null) {
      ToastService.show(context, 'Please select a Primary Unit', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    String? formattedMfgDate;
    String? formattedExpDate;
    try {
      if (_mfgDateController.text.isNotEmpty) {
        formattedMfgDate = DateFormat('yyyy-MM-dd').format(
          DateFormat('dd/MM/yyyy').parse(_mfgDateController.text),
        );
      }
      if (_expDateController.text.isNotEmpty) {
        formattedExpDate = DateFormat('yyyy-MM-dd').format(
          DateFormat('dd/MM/yyyy').parse(_expDateController.text),
        );
      }
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }

    String dbItemType = 'PO';
    if (_selectedItemType == 'Service Item') {
      dbItemType = 'SV';
    }
    if (_selectedItemType == 'Fixed Asset') {
      dbItemType = 'FX';
    }

    double parsedFactor = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    double parsedConversionRatio = _enableAltUnit
        ? (double.tryParse(_altQtyController.text.trim()) ?? 0.0)
        : 0.0;

    final itemData = {
      'itemName': _itemNameController.text.trim(),
      'itemCode': _itemCodeController.text.trim(),
      'itemType': dbItemType,
      'itemsSKU': _skuController.text.trim(),
      'hssCode': _hssCodeController.text.trim(),
      'groupName': _groupController.text.trim(),
      'ItemGrpID': _selectedGroup?['ItemGrpID'] ?? _selectedGroup?['itemGrpID'],
      'subGroupName': _subGroupController.text.trim(),
      'ItemSubGrpID':
          _selectedSubGroup?['ItemSubGrpID'] ?? _selectedSubGroup?['itemSubGrpID'],
      'unitId': _selectedUnitId,
      'altUnitId': _enableAltUnit ? _selectedAltUnitId : null,
      // VALUATION HARDCODED HERE
      'valuationMethod': 'FIFO',
      'valuationTech': 'F',
      'ConversionRatio': parsedConversionRatio,
      'Factor': parsedFactor,
      'buyRate': double.tryParse(_buyPriceController.text) ?? 0.0,
      'salesRate': double.tryParse(_salesPriceController.text) ?? 0.0,
      'mrp': double.tryParse(_mrpController.text) ?? 0.0,
      'tradePrice': double.tryParse(_tradePriceController.text) ?? 0.0,
      'mrRate': double.tryParse(_mrRateController.text) ?? 0.0,
      'vatStatus': _vatStatus,
      'vatRate':
          _vatStatus == 'Yes' ? (double.tryParse(_rateController.text) ?? 13.0) : 0.0,
      'mfgDate': formattedMfgDate,
      'expiryDate': formattedExpDate,
      'itemLock': 'N',
      'batchItem': 'N',
    };

    try {
      await _apiService.createItem(itemData);
      if (mounted) {
        ToastService.show(context, 'Item created successfully!', isError: false);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, 'Failed to create item: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _itemNameController.clear();
    _itemCodeController.clear();
    _skuController.clear();
    _hssCodeController.clear();
    _groupController.clear();
    _subGroupController.clear();
    _altQtyController.clear();
    _qtyController.clear();
    _buyPriceController.clear();
    _salesPriceController.clear();
    _mrpController.clear();
    _tradePriceController.clear();
    _mrRateController.clear();
    _mfgDateController.clear();
    _expDateController.clear();
    setState(() {
      _selectedItemType = 'Inventory Item';
      _selectedUnitId = null;
      _selectedAltUnitId = null;
      _enableAltUnit = false;
      _vatStatus = 'Yes';
      _rateController.text = '13.00';
      _lastGeneratedPrefix = '';
      _selectedGroup = null;
      _selectedSubGroup = null;
      _itemSubGroups = [];
      _itemSearchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    String primaryUnitCode = '';
    if (_selectedUnitId != null && _availableUnits.isNotEmpty) {
      try {
        primaryUnitCode = _availableUnits
                .firstWhere((u) => (u['unitId'] ?? u['UnitID']) == _selectedUnitId)['unitCode']
                ?.toString() ??
            '';
      } catch (_) {}
    }

    String altUnitCode = '';
    if (_selectedAltUnitId != null && _availableUnits.isNotEmpty) {
      try {
        altUnitCode = _availableUnits
                .firstWhere((u) => (u['unitId'] ?? u['UnitID']) == _selectedAltUnitId)['unitCode']
                ?.toString() ??
            '';
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: _Deck.ground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _Deck.ground,
        foregroundColor: _Deck.ink,
        centerTitle: false,
        title: const Text(
          'New item',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Basic details', _Deck.teal),
              const SizedBox(height: 12),
              _Panel(
                children: [
                  _buildNameSearchField(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildItemCodeField()),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: _deckField(controller: _skuController, label: 'Item SKU'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _deckField(controller: _hssCodeController, label: 'HSS code'),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildGroupField()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSubGroupField()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildItemTypeSelector(),
                ],
              ),

              const SizedBox(height: 26),
              _sectionLabel('Units', const Color(0xFF6E8F84)),
              const SizedBox(height: 12),
              _Panel(
                children: [
                  _buildUnitsRow(),
                  const SizedBox(height: 18),
                  _buildQtyEquationRow(primaryUnitCode, altUnitCode),
                ],
              ),

              const SizedBox(height: 26),
              _sectionLabel('Pricing & tax', _Deck.tag),
              const SizedBox(height: 12),
              _Panel(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _deckField(
                          controller: _buyPriceController,
                          label: 'Buy price',
                          keyboardType: TextInputType.number,
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _deckField(
                          controller: _salesPriceController,
                          label: 'Sales price',
                          keyboardType: TextInputType.number,
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _deckField(
                          controller: _mrpController,
                          label: 'MRP',
                          keyboardType: TextInputType.number,
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _deckField(
                          controller: _tradePriceController,
                          label: 'Trade price',
                          keyboardType: TextInputType.number,
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _deckField(
                          controller: _mrRateController,
                          label: 'M.R. rate',
                          keyboardType: TextInputType.number,
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildVatRow(),
                ],
              ),

              const SizedBox(height: 26),
              _sectionLabel('Manufacturing & expiry', const Color(0xFF6E8F84)),
              const SizedBox(height: 12),
              _Panel(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          controller: _mfgDateController,
                          label: 'Mfg date',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateField(
                          controller: _expDateController,
                          label: 'Exp. date',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Section chrome
  // ------------------------------------------------------------------

  Widget _sectionLabel(String text, Color dot) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: _Deck.ink,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Fields — all Autocomplete widgets use Flutter's own default
  // suggestion-overlay rendering (no custom optionsViewBuilder), so
  // positioning/sizing always matches the field itself.
  // ------------------------------------------------------------------

  Widget _buildNameSearchField() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) =>
          (option['ItemName'] ?? option['itemName'] ?? '').toString(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.trim().length < 2) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        return _itemSearchResults;
      },
      onSelected: (Map<String, dynamic> selection) {
        final name = (selection['ItemName'] ?? '').toString();
        _itemNameController.text = name;
        if (name.length >= 2) {
          _generateItemCode(name.substring(0, 2));
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        if (_autoCompleteController != controller) {
          _autoCompleteController = controller;
          controller.addListener(() {
            final text = controller.text.trim();
            _itemNameController.text = text;
            _onItemNameChanged(text);
            if (text.length >= 2) {
              final prefix = text.substring(0, 2);
              if (prefix.toLowerCase() != _lastGeneratedPrefix.toLowerCase()) {
                _generateItemCode(prefix);
              }
            } else if (text.length < 2) {
              if (_itemCodeController.text.isNotEmpty) {
                _itemCodeController.clear();
                _lastGeneratedPrefix = '';
              }
            }
          });
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15, color: _Deck.ink),
          decoration: _deckDecoration('Item name'),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildItemCodeField() {
    final hasCode =
        _itemCodeController.text.isNotEmpty && _itemCodeController.text != 'Loading...';
    return TextFormField(
      controller: _itemCodeController,
      readOnly: true,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: hasCode ? _Deck.tagInk : _Deck.inkSoft,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: _deckDecoration('Code').copyWith(
        fillColor: hasCode ? _Deck.tag : _Deck.ground,
      ),
    );
  }

  Widget _buildGroupField() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) {
        return (option['GrpName'] ?? option['grpName'] ?? option['ItemGrpName'] ?? '')
            .toString();
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _itemGroups;
        }
        return _itemGroups.where((group) {
          final name = (group['GrpName'] ?? group['grpName'] ?? group['ItemGrpName'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: _onGroupSelected,
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        if (controller.text.isEmpty && _groupController.text.isNotEmpty) {
          controller.text = _groupController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 14.5, color: _Deck.ink),
          decoration: _deckDecoration('Item group').copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.expand_more, size: 20, color: _Deck.inkSoft),
              onPressed: () {
                controller.clear();
                _groupController.clear();
                focusNode.unfocus();
                Future.microtask(() => focusNode.requestFocus());
              },
            ),
          ),
          onChanged: (value) {
            _groupController.text = value;
            if (value.isEmpty) {
              setState(() {
                _selectedGroup = null;
                _selectedSubGroup = null;
                _subGroupController.clear();
                _itemSubGroups = [];
              });
            }
          },
        );
      },
    );
  }

  Widget _buildSubGroupField() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) {
        return (option['ItemSubGrpName'] ??
                option['itemSubGrpName'] ??
                option['SubGrpName'] ??
                option.values.last ??
                '')
            .toString();
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (_selectedGroup == null) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        if (textEditingValue.text.isEmpty) {
          return _itemSubGroups;
        }
        return _itemSubGroups.where((subGroup) {
          final name = (subGroup['ItemSubGrpName'] ??
                  subGroup['itemSubGrpName'] ??
                  subGroup['SubGrpName'] ??
                  '')
              .toString()
              .toLowerCase();
          return name.contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (Map<String, dynamic> selection) {
        setState(() {
          _selectedSubGroup = selection;
          _subGroupController.text = (selection['ItemSubGrpName'] ??
                  selection['itemSubGrpName'] ??
                  selection['SubGrpName'] ??
                  '')
              .toString();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        if (controller.text.isEmpty && _subGroupController.text.isNotEmpty) {
          controller.text = _subGroupController.text;
        }
        final enabled = _selectedGroup != null;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          textInputAction: TextInputAction.next,
          enabled: enabled,
          style: TextStyle(fontSize: 14.5, color: enabled ? _Deck.ink : _Deck.inkSoft),
          decoration: _deckDecoration(
            enabled ? 'Item sub group' : 'Select group first',
          ).copyWith(
            fillColor: enabled ? _Deck.ground : _Deck.rule.withValues(alpha: 0.5),
            suffixIcon: IconButton(
              icon: Icon(Icons.expand_more, size: 20, color: enabled ? _Deck.inkSoft : _Deck.rule),
              onPressed: !enabled
                  ? null
                  : () {
                      controller.clear();
                      _subGroupController.clear();
                      focusNode.unfocus();
                      Future.microtask(() => focusNode.requestFocus());
                    },
            ),
          ),
          onChanged: (value) => _subGroupController.text = value,
        );
      },
    );
  }

  Widget _buildItemTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Item type', style: TextStyle(fontSize: 12.5, color: _Deck.inkSoft)),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: _Deck.ground,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: _itemTypes.map((type) {
              final selected = _selectedItemType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedItemType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? _Deck.panel : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      type,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? _Deck.ink : _Deck.inkSoft,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _deckDropdown<int>(
            label: 'Primary unit',
            value: _selectedUnitId,
            items: _availableUnits
                .map(
                  (u) => DropdownMenuItem<int>(
                    value: (u['unitId'] ?? u['UnitID']) as int,
                    child: Text((u['unitCode'] ?? u['UnitCode'] ?? '').toString()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedUnitId = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _enableAltUnit,
                      activeColor: _Deck.teal,
                      side: const BorderSide(color: _Deck.rule, width: 1.4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() {
                        _enableAltUnit = v!;
                        if (!v) {
                          _selectedAltUnitId = null;
                          _qtyController.clear();
                          _altQtyController.clear();
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Alt unit',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _enableAltUnit ? _Deck.ink : _Deck.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _deckDropdown<int>(
                label: '',
                hideLabel: true,
                value: _selectedAltUnitId,
                enabled: _enableAltUnit,
                items: _availableUnits
                    .map(
                      (u) => DropdownMenuItem<int>(
                        value: (u['unitId'] ?? u['UnitID']) as int,
                        child: Text((u['unitCode'] ?? u['UnitCode'] ?? '').toString()),
                      ),
                    )
                    .toList(),
                onChanged: _enableAltUnit ? (v) => setState(() => _selectedAltUnitId = v) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQtyEquationRow(String primaryUnitCode, String altUnitCode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _deckField(
            controller: _altQtyController,
            label: 'Alt qty',
            keyboardType: TextInputType.number,
            enabled: _enableAltUnit,
            numeric: true,
            suffixGlyph: altUnitCode,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.sync_alt, size: 17, color: _enableAltUnit ? _Deck.teal : _Deck.rule),
        ),
        Expanded(
          child: _deckField(
            controller: _qtyController,
            label: 'Qty',
            keyboardType: TextInputType.number,
            enabled: _enableAltUnit,
            numeric: true,
            suffixGlyph: primaryUnitCode,
          ),
        ),
      ],
    );
  }

  Widget _buildVatRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _deckDropdown<String>(
            label: 'VAT',
            value: _vatStatus,
            items: _vatOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _vatStatus = v!),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: _deckField(
            controller: _rateController,
            label: 'Rate',
            keyboardType: TextInputType.number,
            enabled: _vatStatus == 'Yes',
            numeric: true,
            suffixGlyph: '%',
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({required TextEditingController controller, required String label}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(fontSize: 14.5, color: _Deck.ink),
      decoration: _deckDecoration(label).copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 17, color: _Deck.inkSoft),
      ),
      onTap: () => _selectDate(context, controller),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: _Deck.teal,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _isLoading ? null : _submitItem,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save item',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Field primitives
  // ------------------------------------------------------------------

  InputDecoration _deckDecoration(String label, {String? suffixGlyph, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: const TextStyle(fontSize: 13, color: _Deck.inkSoft),
      floatingLabelStyle: const TextStyle(fontSize: 12.5, color: _Deck.teal, fontWeight: FontWeight.w600),
      isDense: true,
      filled: true,
      fillColor: _Deck.ground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixText: suffixGlyph,
      suffixStyle: const TextStyle(fontSize: 13, color: _Deck.inkSoft, fontWeight: FontWeight.w600),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _Deck.teal, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _Deck.warn, width: 1.4),
      ),
      errorStyle: const TextStyle(fontSize: 11, color: _Deck.warn),
    );
  }

  Widget _deckField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool enabled = true,
    bool numeric = false,
    String? suffixGlyph,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        fontSize: 14.5,
        color: enabled ? _Deck.ink : _Deck.inkSoft,
        fontFeatures: numeric ? const [FontFeature.tabularFigures()] : null,
      ),
      decoration: _deckDecoration(label, suffixGlyph: suffixGlyph, suffixIcon: suffixIcon).copyWith(
        fillColor: enabled ? _Deck.ground : _Deck.rule.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _deckDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    String? Function(T?)? validator,
    bool enabled = true,
    bool hideLabel = false,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      icon: Icon(Icons.expand_more, size: 20, color: enabled ? _Deck.inkSoft : _Deck.rule),
      style: TextStyle(fontSize: 14.5, color: enabled ? _Deck.ink : _Deck.inkSoft),
      dropdownColor: _Deck.panel,
      decoration: _deckDecoration(hideLabel ? '' : label).copyWith(
        fillColor: enabled ? _Deck.ground : _Deck.rule.withValues(alpha: 0.5),
      ),
      disabledHint: const Text('Disabled', style: TextStyle(fontSize: 13, color: _Deck.inkSoft)),
    );
  }
}

/// An un-boxed grouping surface: soft fill, quiet edge, no stacked
/// card kit — just enough separation to read as one group of fields.
class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Deck.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Deck.rule, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}