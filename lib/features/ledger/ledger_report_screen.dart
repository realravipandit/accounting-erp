import 'package:flutter/material.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_akount_login/core/network/api_service.dart';
import 'package:sas_akount_login/services/banking/banking_service.dart';

// PDF & Printing Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ledger_report_dialogs.dart';

/// =====================================================================
/// DATA MODELS & PARSERS
/// =====================================================================
class LedgerReportRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final int? ledgerType;
  final List<String> glCodes;
  final String agentCode;
  final String areaCode;
  final bool includeProductDetails;
  final bool includeRemarks;
  final bool useMiti;
  final bool isCashSales;

  const LedgerReportRequest({
    required this.fromDate,
    required this.toDate,
    this.ledgerType,
    this.glCodes = const [],
    this.agentCode = '',
    this.areaCode = '',
    this.includeProductDetails = true,
    this.includeRemarks = false,
    this.useMiti = false,
    this.isCashSales = false,
  });

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'fromDate': _d(fromDate),
        'toDate': _d(toDate),
        'ledgerType': ledgerType,
        'glCodes': glCodes.join(','),
        'agentCode': agentCode,
        'areaCode': areaCode,
        'productDetails': includeProductDetails ? 1 : 0,
        'remarks': includeRemarks ? 1 : 0,
        'chkMiti': useMiti ? 1 : 0,
        'cashSales': isCashSales ? 1 : 0,
      };
}

class LedgerRawRow {
  final String partyName;
  final String? partyPan;
  final DateTime? displayDate;
  final String? partyDate;
  final String particular;
  final String? voucherNo;
  final String? partyVoucher;
  final String? voucherSource;
  final double debitAmount;
  final double creditAmount;
  final String? productDetailsXml;
  final String? narration;
  final String? remark;

  LedgerRawRow({
    required this.partyName,
    this.partyPan,
    this.displayDate,
    this.partyDate,
    required this.particular,
    this.voucherNo,
    this.partyVoucher,
    this.voucherSource,
    this.debitAmount = 0,
    this.creditAmount = 0,
    this.productDetailsXml,
    this.narration,
    this.remark,
  });

  factory LedgerRawRow.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;
    String? toS(dynamic v) => v?.toString();
    return LedgerRawRow(
      partyName: j['PartyName']?.toString() ?? '',
      partyPan: toS(j['PartyPan']),
      displayDate: (j['DisplayDate'] != null && j['DisplayDate'].toString().isNotEmpty)
          ? DateTime.tryParse(j['DisplayDate'].toString())
          : null,
      partyDate: toS(j['PartyDate']),
      particular: j['Particular']?.toString() ?? '',
      voucherNo: toS(j['VoucherNo']),
      partyVoucher: toS(j['PartyVoucher']),
      voucherSource: toS(j['VoucherSource']),
      debitAmount: toD(j['DebitAmount']),
      creditAmount: toD(j['CreditAmount']),
      productDetailsXml: toS(j['ProductDetails']),
      narration: toS(j['Narration']),
      remark: toS(j['Remark']),
    );
  }
}

enum LedgerRowKind { partyHeader, entry, item, note, ledgerTotal, grandTotal }

class LedgerDisplayRow {
  final LedgerRowKind kind;
  final String date;
  final String description;
  final String debit;
  final String credit;
  final String balance;
  final String? voucherNo;
  final String? source;

  const LedgerDisplayRow({
    required this.kind,
    this.date = '',
    required this.description,
    this.debit = '',
    this.credit = '',
    this.balance = '',
    this.voucherNo,
    this.source,
  });
}

String _fmt(double v) {
  final n = v.abs();
  final parts = n.toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${buf.toString()}.${parts[1]}';
}

String _balanceStr(double debit, double credit) {
  final diff = debit - credit;
  return diff > 0 ? '${_fmt(diff)} Dr' : '${_fmt(diff.abs())} Cr';
}

String _dateStr(DateTime? d, {DateTime? fallbackDate, bool useMiti = false}) {
  final effective = d ?? fallbackDate;
  if (effective == null) return '';
  if (useMiti) {
    return NepaliDateTime.fromDateTime(effective).format('dd/MM/yyyy');
  }
  return '${effective.day.toString().padLeft(2, '0')}/${effective.month.toString().padLeft(2, '0')}/${effective.year}';
}

List<Map<String, String>> _parseItems(String xml) {
  final items = <Map<String, String>>[];
  final itemRegex = RegExp(r'<Items>(.*?)</Items>', dotAll: true);
  for (final m in itemRegex.allMatches(xml)) {
    final block = m.group(1) ?? '';
    String field(String tag) {
      final r = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(block);
      return r?.group(1)?.trim() ?? '';
    }
    items.add({
      'Pro': field('Pro'),
      'Qty': field('Qty'),
      'Unit': field('Unit'),
      'Rate': field('Rate'),
      'Amount': field('Amount'),
    });
  }
  return items;
}

List<LedgerDisplayRow> buildLedgerReportRows(
  List<LedgerRawRow> rows, {
  DateTime? fallbackDate,
  bool useMiti = false,
}) {
  final result = <LedgerDisplayRow>[];
  String currentParty = '';
  double partyDebit = 0, partyCredit = 0;
  double totalDebit = 0, totalCredit = 0;

  void closeParty() {
    if (currentParty.isEmpty) return;
    result.add(LedgerDisplayRow(
      kind: LedgerRowKind.ledgerTotal,
      description: 'Ledger Total',
      debit: _fmt(partyDebit),
      credit: _fmt(partyCredit),
      balance: _balanceStr(partyDebit, partyCredit),
    ));
  }

  for (final r in rows) {
    if (currentParty != r.partyName) {
      closeParty();
      partyDebit = 0;
      partyCredit = 0;
      currentParty = r.partyName;
      result.add(LedgerDisplayRow(
        kind: LedgerRowKind.partyHeader,
        description: (r.partyPan != null && r.partyPan!.isNotEmpty)
            ? 'A/c : ${r.partyName} : ${r.partyPan}'
            : 'A/c : ${r.partyName}',
      ));
    }

    String desc = r.particular;
    if (r.voucherNo != null && r.voucherNo!.isNotEmpty) {
      desc += '  # : ${r.voucherNo}';
      if (r.partyVoucher != null && r.partyVoucher!.isNotEmpty) {
        desc += '  PartyVoucher : ${r.partyVoucher} PartyDate : ${r.partyDate ?? ''}';
      }
    }

    if (r.debitAmount > 0) {
      partyDebit += r.debitAmount;
      totalDebit += r.debitAmount;
    }
    if (r.creditAmount > 0) {
      partyCredit += r.creditAmount;
      totalCredit += r.creditAmount;
    }

    result.add(LedgerDisplayRow(
      kind: LedgerRowKind.entry,
      date: _dateStr(r.displayDate, fallbackDate: fallbackDate, useMiti: useMiti),
      description: desc,
      debit: r.debitAmount > 0 ? _fmt(r.debitAmount) : '',
      credit: r.creditAmount > 0 ? _fmt(r.creditAmount) : '',
      balance: _balanceStr(partyDebit, partyCredit),
      voucherNo: r.voucherNo,
      source: r.voucherSource,
    ));

    final pd = r.productDetailsXml;
    if (pd != null && pd.isNotEmpty && pd != '<ProductDetails></ProductDetails>') {
      for (final item in _parseItems(pd)) {
        result.add(LedgerDisplayRow(
          kind: LedgerRowKind.item,
          description:
              'Items ->> ${item['Pro']}  ${item['Qty']}${item['Unit']}  ${item['Rate']}  ${item['Amount']}',
        ));
      }
    }
    if (r.narration != null && r.narration!.isNotEmpty) {
      result.add(LedgerDisplayRow(kind: LedgerRowKind.note, description: 'Narr : ${r.narration}'));
    }
    if (r.remark != null && r.remark!.isNotEmpty) {
      result.add(LedgerDisplayRow(kind: LedgerRowKind.note, description: 'Rem : ${r.remark}'));
    }
  }

  closeParty();
  if (rows.isNotEmpty) {
    result.add(LedgerDisplayRow(
      kind: LedgerRowKind.grandTotal,
      description: 'Grand Total',
      debit: _fmt(totalDebit),
      credit: _fmt(totalCredit),
      balance: _balanceStr(totalDebit, totalCredit),
    ));
  }

  return result;
}

/// =====================================================================
/// RESPONSIVE DESKTOP-STYLE GRID SCREEN
/// =====================================================================
typedef LedgerFetcher = Future<List<LedgerRawRow>> Function(LedgerReportRequest request);

class LedgerReportScreen extends StatefulWidget {
  final LedgerReportRequest request;
  final LedgerFetcher fetchRows;
  const LedgerReportScreen({
    super.key,
    required this.request,
    required this.fetchRows,
  });

  @override
  State<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends State<LedgerReportScreen> {
  late Future<List<LedgerDisplayRow>> _future;
  
  // ZOOM & GESTURE STATE
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  int _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LedgerDisplayRow>> _load() async {
    final raw = await widget.fetchRows(widget.request);
    return buildLedgerReportRows(
      raw,
      fallbackDate: widget.request.fromDate,
      useMiti: widget.request.useMiti,
    );
  }

  void _refresh() => setState(() => _future = _load());
  void _zoomIn() => setState(() => _zoom = (_zoom + 0.15).clamp(0.5, 3.0));
  void _zoomOut() => setState(() => _zoom = (_zoom - 0.15).clamp(0.5, 3.0));

  // --- Base Grid Column Widths ---
  static const double _wDateBase = 85.0;
  static const double _wDescBase = 270.0;
  static const double _wDebitBase = 95.0;
  static const double _wCreditBase = 95.0;
  static const double _wBalBase = 115.0;

  // Formats Header Date according to English/Miti toggle
  String _formatDate(DateTime d) {
    if (widget.request.useMiti) {
      return NepaliDateTime.fromDateTime(d).format('dd/MM/yyyy');
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // --- PDF Share Function ---
  Future<void> _sharePdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final rows = await _future;
      if (rows.isEmpty) throw Exception("No report data to share");

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          maxPages: 200,
          pageFormat: PdfPageFormat.a4, 
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.cyan100),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'Ledger Report',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'From: ${_formatDate(widget.request.fromDate)}  To: ${_formatDate(widget.request.toDate)}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          widget.request.glCodes.isEmpty ? 'All Ledger' : 'Selected Ledgers',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55),  // Date
                  1: const pw.FlexColumnWidth(),    // Description
                  2: const pw.FixedColumnWidth(65),  // Debit
                  3: const pw.FixedColumnWidth(65),  // Credit
                  4: const pw.FixedColumnWidth(70),  // Balance
                },
                children: [
                  // Table Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('Date', isHeader: true, align: pw.TextAlign.center),
                      _pdfCell('Description', isHeader: true, align: pw.TextAlign.left),
                      _pdfCell('Debit Amount', isHeader: true, align: pw.TextAlign.right),
                      _pdfCell('Credit Amount', isHeader: true, align: pw.TextAlign.right),
                      _pdfCell('Balance', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),

                  // Data Rows
                  ...rows.map((row) {
                    final isHeader = row.kind == LedgerRowKind.partyHeader;
                    final isTotal = row.kind == LedgerRowKind.ledgerTotal || row.kind == LedgerRowKind.grandTotal;
                    final isItem = row.kind == LedgerRowKind.item || row.kind == LedgerRowKind.note;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isHeader || isTotal ? PdfColors.grey100 : PdfColors.white,
                      ),
                      children: [
                        _pdfCell(row.date, isBold: isTotal, align: pw.TextAlign.center),
                        _pdfCell(
                          row.description,
                          align: isTotal ? pw.TextAlign.right : pw.TextAlign.left,
                          isBold: isHeader || isTotal,
                          isItalic: isItem,
                        ),
                        _pdfCell(row.debit, align: pw.TextAlign.right, isBold: isTotal),
                        _pdfCell(row.credit, align: pw.TextAlign.right, isBold: isTotal),
                        _pdfCell(row.balance, align: pw.TextAlign.right, isBold: isHeader || isTotal),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      if (mounted) Navigator.pop(context);

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Ledger_Report_${NepaliDateTime.now().format('yyyy_MM_dd')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool isItalic = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 7.5,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ledger Report'),
        actions: [
          IconButton(onPressed: _sharePdf, icon: const Icon(Icons.share_rounded), tooltip: 'Share PDF'),
          IconButton(onPressed: _zoomOut, icon: const Icon(Icons.zoom_out_rounded), tooltip: 'Zoom Out'),
          IconButton(onPressed: _zoomIn, icon: const Icon(Icons.zoom_in_rounded), tooltip: 'Zoom In'),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: FutureBuilder<List<LedgerDisplayRow>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Failed to load ledger: ${snap.error}'));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return const Center(child: Text('No ledger entries in this period'));
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final wDate = _wDateBase * _zoom;
            final wDebit = _wDebitBase * _zoom;
            final wCredit = _wCreditBase * _zoom;
            final wBal = _wBalBase * _zoom;
            final baseTotalWidth = wDate + (_wDescBase * _zoom) + wDebit + wCredit + wBal;

            final extraSpace = screenWidth > baseTotalWidth ? (screenWidth - baseTotalWidth) : 0.0;
            final wDesc = (_wDescBase * _zoom) + extraSpace;
            final dynamicTotalWidth = baseTotalWidth + extraSpace;

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(_zoom),
              ),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF00E5FF),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16 * _zoom, vertical: 10 * _zoom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Ledger Report',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        SizedBox(height: 6 * _zoom),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'From: ${_formatDate(widget.request.fromDate)} To: ${_formatDate(widget.request.toDate)}',
                              style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              widget.request.glCodes.isEmpty ? 'All Ledger' : 'Selected Ledgers',
                              style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => setState(() => _activePointers++),
                      onPointerUp: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
                      onPointerCancel: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque, 
                        onScaleStart: (details) => _baseZoom = _zoom,
                        onScaleUpdate: (details) {
                          if (_activePointers < 2) return;
                          setState(() {
                            _zoom = (_baseZoom * details.scale).clamp(0.5, 3.0);
                          });
                        },
                        child: Scrollbar(
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            physics: _activePointers > 1
                                ? const NeverScrollableScrollPhysics()
                                : const ClampingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              width: dynamicTotalWidth + 2.0,
                              decoration: const BoxDecoration(
                                border: Border(left: BorderSide(color: Colors.black26), right: BorderSide(color: Colors.black26)),
                              ),
                              child: Column(
                                children: [
                                  _buildGridHeader(wDate, wDesc, wDebit, wCredit, wBal),
                                  Expanded(
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        physics: _activePointers > 1
                                            ? const NeverScrollableScrollPhysics()
                                            : const ClampingScrollPhysics(),
                                        itemCount: rows.length,
                                        itemBuilder: (context, i) => _buildRow(
                                          rows[i],
                                          wDate, wDesc, wDebit, wCredit, wBal
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridHeader(double wDate, double wDesc, double wDebit, double wCredit, double wBal) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEEEEEE),
        border: Border(bottom: BorderSide(color: Colors.black45, width: 1.5)),
      ),
      child: Row(
        children: [
          _cell('Date', width: wDate, isHeader: true),
          _cell('Description', width: wDesc, isHeader: true, align: TextAlign.left),
          _cell('Debit Amount', width: wDebit, isHeader: true, align: TextAlign.right),
          _cell('Credit Amount', width: wCredit, isHeader: true, align: TextAlign.right),
          _cell('Balance', width: wBal, isHeader: true, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _cell(
    String text, {
    required double width,
    bool isHeader = false,
    TextAlign align = TextAlign.center,
    bool isBold = false,
    bool isItalic = false,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 6 * _zoom, vertical: 8 * _zoom),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.black26)),
      ),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : align == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          color: isHeader ? Colors.black87 : Colors.black,
        ),
      ),
    );
  }

  Widget _buildRow(LedgerDisplayRow row, double wDate, double wDesc, double wDebit, double wCredit, double wBal) {
    final isHeader = row.kind == LedgerRowKind.partyHeader;
    final isTotal = row.kind == LedgerRowKind.ledgerTotal || row.kind == LedgerRowKind.grandTotal;
    final isItem = row.kind == LedgerRowKind.item || row.kind == LedgerRowKind.note;

    Widget rowContent = Container(
      decoration: BoxDecoration(
        color: isHeader || isTotal ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isTotal ? Colors.black45 : Colors.black12,
            width: isTotal ? 1.5 : 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _cell(row.date, width: wDate, isBold: isTotal),
          _cell(
            row.description,
            width: wDesc,
            align: isTotal ? TextAlign.right : TextAlign.left,
            isBold: isHeader || isTotal,
            isItalic: isItem,
          ),
          _cell(row.debit, width: wDebit, align: TextAlign.right, isBold: isTotal),
          _cell(row.credit, width: wCredit, align: TextAlign.right, isBold: isTotal),
          _cell(row.balance, width: wBal, align: TextAlign.right, isBold: isHeader || isTotal),
        ],
      ),
    );

    if (row.kind == LedgerRowKind.entry && row.voucherNo != null && row.voucherNo!.isNotEmpty) {
      return InkWell(
        onTap: () {},
        child: rowContent,
      );
    }
    return rowContent;
  }
}

/// =====================================================================
/// ENTRY POINT / LANDING PAGE
/// =====================================================================
class LedgerReportPage extends StatelessWidget {
  const LedgerReportPage({super.key});

  static final ApiService _api = ApiService();

  static Future<List<LedgerRawRow>> _fetchLedgerRows(LedgerReportRequest request) async {
    debugPrint('Ledger report request: ${request.toJson()}');
    final response = await _api
        .post('ledgers/report', body: request.toJson())
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Ledger report request timed out after 60s.'),
        );

    if (response.statusCode != 200) {
      throw Exception('Ledger report request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = _api.decodeResponse(response);
    final list = decoded is List ? decoded : const [];
    return list.map((j) => LedgerRawRow.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger Report'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Report Generated',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a date range and accounts\nto generate your ledger report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('Select Dates & Ledgers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B5BDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final bankingService = BankingService();
                  final allLedgers = await bankingService.getVoucherLedgers();

                  final fetchedLedgers = allLedgers.map((l) {
                    final name = (l['LedgerName'] ?? l['ledgerName'] ?? '').toString();
                    final code = (l['LedgerCode'] ?? l['ledgerCode'] ?? '').toString();
                    return LedgerGlOption(
                      description: name.isNotEmpty ? name : 'Unnamed Account',
                      shortName: code,
                    );
                  }).toList();

                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    showLedgerReportFlow(
                      context,
                      ledgers: fetchedLedgers,
                      fetchRows: _fetchLedgerRows,
                    );
                  }
                } catch (error) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to load accounts: $error'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}