import 'package:flutter/material.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'ledger_report_screen.dart'; // adjust the relative path to match this file's location

/// =====================================================================
/// LEDGER REPORT — modern popup flow
///
/// Two steps, both as rounded bottom sheets instead of the legacy WinForms
/// dialogs:
///   1. _LedgerFilterSheet   -> date range + Group By + option toggles
///   2. _LedgerPickerSheet   -> searchable, multi-select ledger list
///
/// On completion, both results are merged into a LedgerReportRequest and
/// pushed to your existing LedgerReportScreen. Nothing about
/// buildLedgerReportRows / LedgerRawRow changes — this file only replaces
/// the two input dialogs.
///
/// Usage (e.g. from your reports menu):
///
///   onTap: () => showLedgerReportFlow(
///     context,
///     ledgers: myGlCodeList, // List<LedgerGlOption>
///     fetchRows: LedgerReportPage.fetchLedgerRows, // or your own fetcher
///   ),
/// =====================================================================

/// ---- one selectable row in the ledger picker (from your GL code list) ----
class LedgerGlOption {
  final String description;
  final String shortName; // e.g. 'AC00001'

  const LedgerGlOption({required this.description, required this.shortName});
}

enum LedgerGroupBy { ledger, subLedger, cashAcSales }

extension on LedgerGroupBy {
  String get label => switch (this) {
        LedgerGroupBy.ledger => 'Ledger',
        LedgerGroupBy.subLedger => 'Sub Ledger',
        LedgerGroupBy.cashAcSales => 'Cash A/C Sales',
      };
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
  final LedgerGroupBy groupBy;
  final bool itemDetails;
  final bool date;
  final bool remarks;
  final bool subLedger;
  final bool summary;
  final bool cashSales;
  final bool includeCheque;
  final bool useMiti;

  const _FilterResult({
    required this.fromDate,
    required this.toDate,
    required this.groupBy,
    required this.itemDetails,
    required this.date,
    required this.remarks,
    required this.subLedger,
    required this.summary,
    required this.cashSales,
    required this.includeCheque,
    required this.useMiti,
  });
}

/// Entry point: runs the two-step flow and pushes LedgerReportScreen.
/// Returns without navigating if the user cancels either step.
Future<void> showLedgerReportFlow(
  BuildContext context, {
  required List<LedgerGlOption> ledgers,
  required LedgerFetcher fetchRows,
}) async {
  final filters = await showModalBottomSheet<_FilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LedgerFilterSheet(),
  );
  if (filters == null || !context.mounted) return;

  final selected = await showModalBottomSheet<List<LedgerGlOption>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LedgerPickerSheet(ledgers: ledgers),
  );
  if (selected == null || !context.mounted) return;

  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => LedgerReportScreen(
      request: LedgerReportRequest(
        fromDate: filters.fromDate,
        toDate: filters.toDate,
        glCodes: selected.map((e) => e.shortName).toList(),
        includeProductDetails: filters.itemDetails,
        includeRemarks: filters.remarks,
        useMiti: filters.useMiti,
        isCashSales: filters.cashSales,
      ),
      fetchRows: fetchRows,
    ),
  ));
}

/// =====================================================================
/// STEP 1 — date range + options
/// =====================================================================
class _LedgerFilterSheet extends StatefulWidget {
  const _LedgerFilterSheet();

  @override
  State<_LedgerFilterSheet> createState() => _LedgerFilterSheetState();
}

class _LedgerFilterSheetState extends State<_LedgerFilterSheet> {
  late DateTime _from = DateTime(DateTime.now().year, 1, 1);
  late DateTime _to = DateTime.now();
  LedgerGroupBy _groupBy = LedgerGroupBy.ledger;

  bool itemDetails = false;
  bool date = false;
  bool remarks = false;
  bool subLedger = false;
  bool summary = false;
  bool cashSales = false;
  bool includeCheque = false;
  bool _useMiti = true;

  bool get _allChecked =>
      itemDetails && date && remarks && subLedger && summary && cashSales && includeCheque;

  void _setAll(bool v) => setState(() {
        itemDetails = date = remarks = subLedger = summary = cashSales = includeCheque = v;
      });

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
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _T.accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Ledger Details',
      subtitle: 'Choose a date range and what to include',
      // WRAPPED IN SingleChildScrollView TO PREVENT BOTTOM OVERFLOW
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
            const Text('Group By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.sub)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: LedgerGroupBy.values.map((g) {
                final selected = g == _groupBy;
                return ChoiceChip(
                  label: Text(g.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _groupBy = g),
                  selectedColor: _T.accentSoft,
                  labelStyle: TextStyle(
                    color: selected ? _T.accent : _T.sub,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  backgroundColor: _T.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: selected ? _T.accent : _T.line),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Include', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.sub)),
                TextButton(
                  onPressed: () => _setAll(!_allChecked),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: Text(
                    _allChecked ? 'Clear all' : 'Select all',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _toggle('Item Details', itemDetails, (v) => setState(() => itemDetails = v)),
                _toggle('Date', date, (v) => setState(() => date = v)),
                _toggle('Remarks', remarks, (v) => setState(() => remarks = v)),
                _toggle('Sub Ledger', subLedger, (v) => setState(() => subLedger = v)),
                _toggle('Summary', summary, (v) => setState(() => summary = v)),
                _toggle('Cash A/C Sales', cashSales, (v) => setState(() => cashSales = v)),
                _toggle('Include Cheque', includeCheque, (v) => setState(() => includeCheque = v)),
              ],
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Continue',
              onTap: () => Navigator.of(context).pop(_FilterResult(
                fromDate: _from,
                toDate: _to,
                groupBy: _groupBy,
                itemDetails: itemDetails,
                date: date,
                remarks: remarks,
                subLedger: subLedger,
                summary: summary,
                cashSales: cashSales,
                includeCheque: includeCheque,
                useMiti: _useMiti,
              )),
            ),
            const SizedBox(height: 12), // Bottom padding safeguard
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? _T.accentSoft : _T.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? _T.accent : _T.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: value ? _T.accent : _T.sub,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: value ? _T.accent : _T.ink,
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
        ? NepaliDateTime.fromDateTime(date).format('dd/MM/yyyy') // BS display, e.g. 01/04/2082
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _T.line),
          borderRadius: BorderRadius.circular(12),
        ),
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
/// STEP 2 — searchable, multi-select ledger picker
/// =====================================================================
class _LedgerPickerSheet extends StatefulWidget {
  final List<LedgerGlOption> ledgers;

  const _LedgerPickerSheet({required this.ledgers});

  @override
  State<_LedgerPickerSheet> createState() => _LedgerPickerSheetState();
}

class _LedgerPickerSheetState extends State<_LedgerPickerSheet> {
  final _search = TextEditingController();
  late final Set<String> _selected = {};
  late List<LedgerGlOption> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.ledgers]..sort((a, b) => a.description.compareTo(b.description));
  }

  List<LedgerGlOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _sorted;
    return _sorted.where((e) =>
        e.description.toLowerCase().contains(q) || e.shortName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return _SheetShell(
      title: 'Select Ledgers',
      subtitle: '${_selected.length} selected',
      maxHeightFraction: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search ledger name or code',
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
              _pillAction('Tag all', () => setState(() => _selected.addAll(filtered.map((e) => e.shortName)))),
              const SizedBox(width: 8),
              _pillAction('Untag', () => setState(() => _selected.removeAll(filtered.map((e) => e.shortName)))),
              const SizedBox(width: 8),
              _pillAction('Invert', () => setState(() {
                    for (final e in filtered) {
                      _selected.contains(e.shortName) ? _selected.remove(e.shortName) : _selected.add(e.shortName);
                    }
                  })),
            ],
          ),
          const SizedBox(height: 8),
          Expanded( // Changed from Flexible
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No ledgers found', style: TextStyle(color: _T.sub))),
                  )
                : ListView.separated(
                    // Removed shrinkWrap: true 
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _T.line),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final selected = _selected.contains(item.shortName);
                      return InkWell(
                        onTap: () => setState(() =>
                            selected ? _selected.remove(item.shortName) : _selected.add(item.shortName)),
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
                                child: Text(item.description,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: _T.ink,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                              ),
                              Text(item.shortName, style: const TextStyle(fontSize: 12, color: _T.sub)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Show Report${_selected.isEmpty ? '' : ' (${_selected.length})'}',
            enabled: _selected.isNotEmpty,
            onTap: () => Navigator.of(context)
                .pop(_sorted.where((e) => _selected.contains(e.shortName)).toList()),
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
        decoration: BoxDecoration(
          color: _T.accentSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _T.accent)),
      ),
    );
  }
}

/// =====================================================================
/// shared shell + button
/// =====================================================================
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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