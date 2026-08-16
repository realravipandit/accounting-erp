import 'package:flutter/material.dart';
import 'package:sas_akount_login/services/inventory/inventory_service.dart';
import 'package:intl/intl.dart';
import 'package:sas_akount_login/core/services/toast_service.dart';

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

  final List<String> _itemTypes = [
    'Inventory Item',
    'Service Item',
    'Fixed Asset'
  ];

  final List<String> _vatOptions = ['Yes', 'No'];

  final List<String> _existingItemNames = [
    'Dl40 Chinese',
    'J.S. Back Stool',
    'Hydrolic',
    'Wheel'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnitsFromDb();
    _fetchGroupsFromDb();
  }

  Future<void> _fetchUnitsFromDb() async {
    try {
      final units = await _apiService.getUnits();

      final mappedUnits = units
          .map(
            (unit) => Map<String, dynamic>.from(
              unit as Map,
            ),
          )
          .toList();

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
          .map(
            (group) => Map<String, dynamic>.from(
              group as Map,
            ),
          )
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
          (group['GrpName'] ??
                  group['grpName'] ??
                  group['ItemGrpName'] ??
                  '')
              .toString();

      _selectedSubGroup = null;
      _subGroupController.clear();
      _itemSubGroups = [];
    });

    try {
      // InventoryService.getItemSubGroups() currently accepts no arguments.
      final subGroups = await _apiService.getItemSubGroups();

      final mappedSubGroups = subGroups
          .map(
            (subGroup) => Map<String, dynamic>.from(
              subGroup as Map,
            ),
          )
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
      // InventoryService.getNextItemCode() currently accepts no arguments.
      final code = await _apiService.getNextItemCode();

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
        ToastService.show(
          context,
          'Code Gen Error: $e',
          isError: true,
        );
      }
    }
  }

  @override
  void dispose() {
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
      ToastService.show(
        context,
        'Please select a Primary Unit',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    String? formattedMfgDate;
    String? formattedExpDate;

    try {
      if (_mfgDateController.text.isNotEmpty) {
        formattedMfgDate = DateFormat('yyyy-MM-dd').format(
          DateFormat('dd/MM/yyyy').parse(
            _mfgDateController.text,
          ),
        );
      }

      if (_expDateController.text.isNotEmpty) {
        formattedExpDate = DateFormat('yyyy-MM-dd').format(
          DateFormat('dd/MM/yyyy').parse(
            _expDateController.text,
          ),
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

    double parsedFactor =
        double.tryParse(_qtyController.text.trim()) ?? 0.0;

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
      'ItemGrpID':
          _selectedGroup?['ItemGrpID'] ??
              _selectedGroup?['itemGrpID'],

      'subGroupName': _subGroupController.text.trim(),
      'ItemSubGrpID':
          _selectedSubGroup?['ItemSubGrpID'] ??
              _selectedSubGroup?['itemSubGrpID'],

      'unitId': _selectedUnitId,
      'altUnitId': _enableAltUnit ? _selectedAltUnitId : null,

      // VALUATION HARDCODED HERE
      'valuationMethod': 'FIFO',
      'valuationTech': 'F',

      'ConversionRatio': parsedConversionRatio,
      'Factor': parsedFactor,

      'buyRate':
          double.tryParse(_buyPriceController.text) ?? 0.0,

      'salesRate':
          double.tryParse(_salesPriceController.text) ?? 0.0,

      'mrp': double.tryParse(_mrpController.text) ?? 0.0,

      'tradePrice':
          double.tryParse(_tradePriceController.text) ?? 0.0,

      'mrRate':
          double.tryParse(_mrRateController.text) ?? 0.0,

      'vatStatus': _vatStatus,

      'vatRate': _vatStatus == 'Yes'
          ? (double.tryParse(_rateController.text) ?? 13.0)
          : 0.0,

      'mfgDate': formattedMfgDate,
      'expiryDate': formattedExpDate,
      'itemLock': 'N',
      'batchItem': 'N',
    };

    try {
      await _apiService.createItem(itemData);

      if (mounted) {
        ToastService.show(
          context,
          'Item created successfully!',
          isError: false,
        );

        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context,
          'Failed to create item: $e',
          isError: true,
        );
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
    });
  }

  @override
  Widget build(BuildContext context) {
    String primaryUnitCode = '';

    if (_selectedUnitId != null &&
        _availableUnits.isNotEmpty) {
      try {
        primaryUnitCode = _availableUnits
                .firstWhere(
                  (u) =>
                      (u['unitId'] ?? u['UnitID']) ==
                      _selectedUnitId,
                )['unitCode']
                ?.toString() ??
            '';
      } catch (_) {}
    }

    String altUnitCode = '';

    if (_selectedAltUnitId != null &&
        _availableUnits.isNotEmpty) {
      try {
        altUnitCode = _availableUnits
                .firstWhere(
                  (u) =>
                      (u['unitId'] ?? u['UnitID']) ==
                      _selectedAltUnitId,
                )['unitCode']
                ?.toString() ??
            '';
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Item Master',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Basic Details'),

              Autocomplete<String>(
                optionsBuilder:
                    (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }

                  return _existingItemNames.where(
                    (option) => option
                        .toLowerCase()
                        .contains(
                          textEditingValue.text
                              .toLowerCase(),
                        ),
                  );
                },
                onSelected: (String selection) {
                  _itemNameController.text = selection;

                  if (selection.length >= 2) {
                    _generateItemCode(
                      selection.substring(0, 2),
                    );
                  }
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onEditingComplete,
                ) {
                  if (_autoCompleteController != controller) {
                    _autoCompleteController = controller;

                    controller.addListener(() {
                      final text = controller.text.trim();

                      _itemNameController.text = text;

                      if (text.length >= 2) {
                        final prefix = text.substring(0, 2);

                        if (prefix.toLowerCase() !=
                            _lastGeneratedPrefix
                                .toLowerCase()) {
                          _generateItemCode(prefix);
                        }
                      } else if (text.length < 2) {
                        if (_itemCodeController
                            .text
                            .isNotEmpty) {
                          _itemCodeController.clear();
                          _lastGeneratedPrefix = '';
                        }
                      }
                    });
                  }

                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete:
                        onEditingComplete,
                    textInputAction:
                        TextInputAction.next,
                    decoration: _inputDecoration(
                      'Item Name (Live Search)',
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Required' : null,
                  );
                },
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller:
                          _itemCodeController,
                      decoration:
                          _inputDecoration(
                            'Item Code',
                          ).copyWith(
                            fillColor:
                                Colors.grey[200],
                          ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        'Item S.K.U.',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _hssCodeController,
                textInputAction:
                    TextInputAction.next,
                decoration: _inputDecoration(
                  'H.S.S Code',
                ),
              ),

              const SizedBox(height: 12),

              // --- DYNAMIC GROUPS AND SUB GROUPS ---
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        Autocomplete<
                            Map<String, dynamic>>(
                      displayStringForOption: (option) {
                        return (option['GrpName'] ??
                                option['grpName'] ??
                                option['ItemGrpName'] ??
                                '')
                            .toString();
                      },
                      optionsBuilder:
                          (TextEditingValue
                              textEditingValue) {
                        if (textEditingValue
                            .text
                            .isEmpty) {
                          return _itemGroups;
                        }

                        return _itemGroups.where(
                          (group) {
                            final name =
                                (group['GrpName'] ??
                                        group['grpName'] ??
                                        group['ItemGrpName'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();

                            return name.contains(
                              textEditingValue
                                  .text
                                  .toLowerCase(),
                            );
                          },
                        );
                      },
                      onSelected:
                          _onGroupSelected,
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onEditingComplete,
                      ) {
                        if (controller.text.isEmpty &&
                            _groupController
                                .text
                                .isNotEmpty) {
                          controller.text =
                              _groupController.text;
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete:
                              onEditingComplete,
                          textInputAction:
                              TextInputAction.next,
                          decoration: _inputDecoration(
                            'Item Group',
                          ).copyWith(
                            suffixIcon:
                                IconButton(
                              icon: const Icon(
                                Icons.arrow_drop_down,
                              ),
                              onPressed: () {
                                controller.clear();
                                _groupController
                                    .clear();
                                focusNode.unfocus();

                                Future.microtask(
                                  () => focusNode
                                      .requestFocus(),
                                );
                              },
                            ),
                          ),
                          onChanged: (value) {
                            _groupController
                                .text = value;

                            if (value.isEmpty) {
                              setState(() {
                                _selectedGroup = null;
                                _selectedSubGroup =
                                    null;
                                _subGroupController
                                    .clear();
                                _itemSubGroups = [];
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child:
                        Autocomplete<
                            Map<String, dynamic>>(
                      displayStringForOption: (option) {
                        return (option[
                                    'ItemSubGrpName'] ??
                                option[
                                    'itemSubGrpName'] ??
                                option['SubGrpName'] ??
                                option.values.last ??
                                '')
                            .toString();
                      },
                      optionsBuilder:
                          (TextEditingValue
                              textEditingValue) {
                        if (_selectedGroup == null) {
                          return const Iterable<
                              Map<String,
                                  dynamic>>.empty();
                        }

                        if (textEditingValue
                            .text
                            .isEmpty) {
                          return _itemSubGroups;
                        }

                        return _itemSubGroups.where(
                          (subGroup) {
                            final name =
                                (subGroup[
                                            'ItemSubGrpName'] ??
                                        subGroup[
                                            'itemSubGrpName'] ??
                                        subGroup[
                                            'SubGrpName'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();

                            return name.contains(
                              textEditingValue
                                  .text
                                  .toLowerCase(),
                            );
                          },
                        );
                      },
                      onSelected: (
                        Map<String, dynamic>
                            selection,
                      ) {
                        setState(() {
                          _selectedSubGroup =
                              selection;

                          _subGroupController.text =
                              (selection[
                                          'ItemSubGrpName'] ??
                                      selection[
                                          'itemSubGrpName'] ??
                                      selection[
                                          'SubGrpName'] ??
                                      '')
                                  .toString();
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onEditingComplete,
                      ) {
                        if (controller.text.isEmpty &&
                            _subGroupController
                                .text
                                .isNotEmpty) {
                          controller.text =
                              _subGroupController.text;
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete:
                              onEditingComplete,
                          textInputAction:
                              TextInputAction.next,
                          enabled:
                              _selectedGroup != null,
                          decoration: _inputDecoration(
                            _selectedGroup == null
                                ? 'Select Group First'
                                : 'Item Sub Group',
                          ).copyWith(
                            fillColor:
                                _selectedGroup ==
                                        null
                                    ? Colors.grey[200]
                                    : Colors.white,
                            suffixIcon:
                                IconButton(
                              icon: const Icon(
                                Icons.arrow_drop_down,
                              ),
                              onPressed:
                                  _selectedGroup ==
                                          null
                                      ? null
                                      : () {
                                          controller
                                              .clear();
                                          _subGroupController
                                              .clear();
                                          focusNode
                                              .unfocus();

                                          Future
                                              .microtask(
                                            () => focusNode
                                                .requestFocus(),
                                          );
                                        },
                            ),
                          ),
                          onChanged: (value) =>
                              _subGroupController
                                  .text = value,
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedItemType,
                decoration: _inputDecoration(
                  'Item Type',
                ),
                items: _itemTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(
                  () =>
                      _selectedItemType = v!,
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionHeader(
                'Units & Quantities',
              ),

              // Row 1: The Dropdowns
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        DropdownButtonFormField<int>(
                      initialValue:
                          _selectedUnitId,
                      decoration:
                          _inputDecoration(
                        'Primary Unit',
                      ),
                      items: _availableUnits
                          .map(
                            (u) =>
                                DropdownMenuItem<
                                    int>(
                              value: (u[
                                          'unitId'] ??
                                      u['UnitID'])
                                  as int,
                              child: Text(
                                (u['unitCode'] ??
                                        u['UnitCode'] ??
                                        '')
                                    .toString(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _selectedUnitId = v,
                      ),
                      validator: (v) =>
                          v == null ? 'Required' : null,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: _enableAltUnit,
                          onChanged: (v) =>
                              setState(() {
                            _enableAltUnit = v!;
                            if (!v) {
                              _selectedAltUnitId =
                                  null;
                              _qtyController.clear();
                              _altQtyController.clear();
                            }
                          }),
                        ),
                        Expanded(
                          child:
                              DropdownButtonFormField<
                                  int>(
                            initialValue:
                                _selectedAltUnitId,
                            decoration:
                                _inputDecoration(
                              'Alt Unit',
                            ).copyWith(
                              fillColor:
                                  _enableAltUnit
                                      ? Colors.white
                                      : Colors.grey[200],
                            ),
                            items: _availableUnits
                                .map(
                                  (u) =>
                                      DropdownMenuItem<
                                          int>(
                                    value: (u[
                                                'unitId'] ??
                                            u['UnitID'])
                                        as int,
                                    child: Text(
                                      (u[
                                                  'unitCode'] ??
                                              u[
                                                  'UnitCode'] ??
                                              '')
                                          .toString(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _enableAltUnit
                                ? (v) => setState(
                                      () =>
                                          _selectedAltUnitId =
                                              v,
                                    )
                                : null,
                            disabledHint:
                                const Text(
                              'Disabled',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: The Text Fields
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller:
                          _altQtyController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      enabled: _enableAltUnit,
                      decoration:
                          _inputDecoration(
                        'Alt Qty',
                      ).copyWith(
                        fillColor: _enableAltUnit
                            ? Colors.white
                            : Colors.grey[200],
                        suffixText:
                            altUnitCode,
                        suffixStyle:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.blueAccent,
                        ),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0,
                    ),
                    child: Text(
                      '=',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      enabled: _enableAltUnit,
                      decoration:
                          _inputDecoration(
                        'Qty',
                      ).copyWith(
                        fillColor: _enableAltUnit
                            ? Colors.white
                            : Colors.grey[200],
                        suffixText:
                            primaryUnitCode,
                        suffixStyle:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.blueAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionHeader(
                'Pricing & Taxation',
              ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller:
                          _buyPriceController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        'Buy Price',
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller:
                          _salesPriceController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        'Sales Price',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        'M.R.P.',
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller:
                          _tradePriceController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        'Trade Price',
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller:
                          _mrRateController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        'M.R. Rate',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child:
                        DropdownButtonFormField<
                            String>(
                      initialValue: _vatStatus,
                      decoration:
                          _inputDecoration(
                        'VAT',
                      ),
                      items: _vatOptions
                          .map(
                            (v) =>
                                DropdownMenuItem(
                              value: v,
                              child: Text(v),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _vatStatus = v!,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller:
                                _rateController,
                            keyboardType:
                                TextInputType.number,
                            textInputAction:
                                TextInputAction.done,
                            enabled:
                                _vatStatus == 'Yes',
                            decoration:
                                _inputDecoration(
                              'Rate',
                            ).copyWith(
                              fillColor:
                                  _vatStatus ==
                                          'Yes'
                                      ? Colors.white
                                      : Colors.grey[200],
                            ),
                          ),
                        ),

                        const Padding(
                          padding:
                              EdgeInsets.only(
                            left: 8.0,
                          ),
                          child: Text(
                            '%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionHeader(
                'Manufacturing & Expiry',
              ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller:
                          _mfgDateController,
                      readOnly: true,
                      decoration:
                          _inputDecoration(
                        'Mfg Date (dd/mm/yyyy)',
                      ).copyWith(
                        suffixIcon:
                            const Icon(
                          Icons.calendar_month,
                        ),
                      ),
                      onTap: () =>
                          _selectDate(
                        context,
                        _mfgDateController,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller:
                          _expDateController,
                      readOnly: true,
                      decoration:
                          _inputDecoration(
                        'Exp. Date (dd/mm/yyyy)',
                      ).copyWith(
                        suffixIcon:
                            const Icon(
                          Icons.calendar_month,
                        ),
                      ),
                      onTap: () =>
                          _selectDate(
                        context,
                        _expDateController,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF0F172A),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : _submitItem,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Item',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16.0,
        top: 8.0,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
  ) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.blueAccent,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.grey[200]!,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}