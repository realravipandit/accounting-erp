import 'package:flutter/material.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/core/network/api_service.dart';
import 'stock_ledger_report_screen.dart'; // adjust the relative path to match this file's location

/// =====================================================================
/// STOCK LEDGER REPORT --- modern popup flow
///
/// Two steps, both as rounded bottom sheets, same shape as the Ledger
/// Report flow:
///   1. _StockLedgerFilterSheet -> date range + With Value + Miti toggle
///   2. _StockItemPickerSheet   -> searchable, multi-select item list
///
/// On completion, both results are merged into a StockLedgerReportRequest
/// and pushed to StockLedgerReportScreen.
///
/// Usage (e.g. from your reports menu):
///
///   onTap: () => showStockLedgerReportFlow(
///     context,
///     items: myItemList,                      // List<StockItemOption>
///     fetchRows: StockLedgerReportPage._fetchStockLedgerRows,
///   ),
/// =====================================================================

/// ---- one selectable row in the item picker ----
class StockItemOption {
  final String itemName;
  final String itemCode; // ItemID / item code sent as ColDataProduct
  final String? unit;

  const StockItemOption({required this.itemName, required this.itemCode, this.unit});
}

/// Pulls the item list for the picker from your inventory backend
/// (inventoryController.js -> GET /inventory/item-options).
/// Returns ALL items, not just ones with current stock — a report can
/// span a date range where an item had stock previously but is at 0 now.
Future<List<StockItemOption>> fetchStockLedgerItemOptions() async {
  final api = ApiService();
  final response = await api.get('inventory/item-options');

  if (response.statusCode != 200) {
    throw Exception('Failed to load items (${response.statusCode}): ${response.body}');
  }

  final decoded = api.decodeResponse(response);
  final list = decoded is List ? decoded : const [];

  return list.map((j) {
    final m = j as Map<String, dynamic>;
    return StockItemOption(
      itemName: m['itemName']?.toString() ?? '',
      itemCode: m['itemCode']?.toString() ?? '',
      unit: m['unit']?.toString(),
    );
  }).toList();
}

// ---- design tokens: slate-blue accent, consistent with the rest of the app ----
class _T {
  static const accent = Color(0xFF3B5BDB);
  static const accentSoft = Color(0xFFEEF1FD);
  static const ink = Color(0xFF15181F);
  static const sub = Color(0xFF6B7280);
  static const line = Color(0xFFE7E9EE);
  static const bg = Color(0xFFFFFFFF);
  static const sheetRadius = 24.0;
}

class _FilterResult {
  final DateTime fromDate;
  final DateTime toDate;
  final bool withValue;
  final bool useMiti;

  const _FilterResult({
    required this.fromDate,
    required this.toDate,
    required this.withValue,
    required this.useMiti,
  });
}

/// Entry point: runs the two-step flow and pushes StockLedgerReportScreen.
/// Returns without navigating if the user cancels either step.
Future<void> showStockLedgerReportFlow(
  BuildContext context, {
  required List<StockItemOption> items,
  required StockLedgerFetcher fetchRows,
}) async {
  final filters = await showModalBottomSheet<_FilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StockLedgerFilterSheet(),
  );

  if (filters == null || !context.mounted) return;

  final selected = await showModalBottomSheet<List<StockItemOption>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StockItemPickerSheet(items: items),
  );

  if (selected == null || !context.mounted) return;

  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => StockLedgerReportScreen(
      request: StockLedgerReportRequest(
        fromDate: filters.fromDate,
        toDate: filters.toDate,
        itemCodes: selected.map((e) => e.itemCode).toList(),
        withValue: filters.withValue,
        useMiti: filters.useMiti,
      ),
      fetchRows: fetchRows,
    ),
  ));
}

/// =====================================================================
/// STEP 1 --- date range + options
/// =====================================================================
class _StockLedgerFilterSheet extends StatefulWidget {
  const _StockLedgerFilterSheet();

  @override
  State<_StockLedgerFilterSheet> createState() => _StockLedgerFilterSheetState();
}

class _StockLedgerFilterSheetState extends State<_StockLedgerFilterSheet> {
  late DateTime _from = NepaliDateTime(NepaliDateTime.now().year, 4, 1).toDateTime();
  late DateTime _to = DateTime.now();
  bool _withValue = false;
  bool _useMiti = true;

  Future<void> _pickDate({required bool isFrom}) async {
    if (_useMiti) {
      final initial = NepaliDateTime.fromDateTime(isFrom ? _from : _to);
      final picked = await showNepaliDatePicker(
        context: context,
        initialDate: initial,
        firstDate: NepaliDateTime(2000),
        lastDate: NepaliDateTime(2100),
      );
      if (picked == null) return;
      setState(() => isFrom ? _from = picked.toDateTime() : _to = picked.toDateTime());
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _T.accent)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Stock Ledger Details',
      subtitle: 'Choose a date range and what to include',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Miti (B.S.)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.sub)),
                Transform.scale(
                  scale: 0.85,
                  child: Switch.adaptive(
                    value: _useMiti,
                    activeColor: _T.accent,
                    onChanged: (v) => setState(() => _useMiti = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From Date',
                    date: _from,
                    useMiti: _useMiti,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'To Date',
                    date: _to,
                    useMiti: _useMiti,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Include', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.sub)),
            const SizedBox(height: 8),
            _toggle(
              'Show Rate & Value columns',
              _withValue,
              (v) => setState(() => _withValue = v),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Continue',
              onTap: () => Navigator.of(context).pop(_FilterResult(
                fromDate: _from,
                toDate: _to,
                withValue: _withValue,
                useMiti: _useMiti,
              )),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? _T.accentSoft : _T.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? _T.accent : _T.line),
        ),
        child: Row(
          children: [
            Icon(value ? Icons.check_circle : Icons.circle_outlined, size: 16, color: value ? _T.accent : _T.sub),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value ? _T.accent : _T.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool useMiti;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.date, required this.onTap, this.useMiti = false});

  @override
  Widget build(BuildContext context) {
    final text = useMiti
        ? NepaliDateTime.fromDateTime(date).format('dd/MM/yyyy')
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: _T.line), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: _T.sub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _T.ink))),
                const Icon(Icons.calendar_today_rounded, size: 15, color: _T.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================================================================
/// STEP 2 --- searchable, multi-select item picker
/// =====================================================================
class _StockItemPickerSheet extends StatefulWidget {
  final List<StockItemOption> items;

  const _StockItemPickerSheet({required this.items});

  @override
  State<_StockItemPickerSheet> createState() => _StockItemPickerSheetState();
}

class _StockItemPickerSheetState extends State<_StockItemPickerSheet> {
  final _search = TextEditingController();
  late final Set<String> _selected = {};
  late List<StockItemOption> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.items]..sort((a, b) => a.itemName.compareTo(b.itemName));
  }

  List<StockItemOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _sorted;
    return _sorted
        .where((e) => e.itemName.toLowerCase().contains(q) || e.itemCode.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return _SheetShell(
      title: 'Select Items',
      subtitle: _selected.isEmpty ? 'All items (leave empty for all)' : '${_selected.length} selected',
      maxHeightFraction: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search item name or code',
              hintStyle: const TextStyle(color: _T.sub, fontSize: 13.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _T.sub),
              filled: true,
              fillColor: const Color(0xFFF5F6F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pillAction('Tag all', () => setState(() => _selected.addAll(filtered.map((e) => e.itemCode)))),
              const SizedBox(width: 8),
              _pillAction('Untag', () => setState(() => _selected.removeAll(filtered.map((e) => e.itemCode)))),
              const SizedBox(width: 8),
              _pillAction(
                'Invert',
                () => setState(() {
                  for (final e in filtered) {
                    _selected.contains(e.itemCode) ? _selected.remove(e.itemCode) : _selected.add(e.itemCode);
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No items found', style: TextStyle(color: _T.sub))),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _T.line),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final selected = _selected.contains(item.itemCode);
                      return InkWell(
                        onTap: () => setState(
                          () => selected ? _selected.remove(item.itemCode) : _selected.add(item.itemCode),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                size: 20,
                                color: selected ? _T.accent : _T.sub,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.unit != null && item.unit!.isNotEmpty
                                      ? '${item.itemName} (${item.unit})'
                                      : item.itemName,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: _T.ink,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              Text(item.itemCode, style: const TextStyle(fontSize: 12, color: _T.sub)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _selected.isEmpty ? 'Show Report (All Items)' : 'Show Report (${_selected.length})',
            onTap: () => Navigator.of(context)
                .pop(_sorted.where((e) => _selected.contains(e.itemCode)).toList()),
          ),
        ],
      ),
    );
  }

  Widget _pillAction(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: _T.accentSoft, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _T.accent)),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final double maxHeightFraction;

  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxHeightFraction = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFraction),
        child: Container(
          decoration: const BoxDecoration(
            color: _T.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_T.sheetRadius)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: _T.line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: _T.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: _T.sub)),
                const SizedBox(height: 18),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _PrimaryButton({required this.label, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.accent,
          disabledBackgroundColor: _T.line,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}