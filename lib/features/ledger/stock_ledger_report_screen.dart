import 'package:flutter/material.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:sas_app/core/network/api_service.dart';

// PDF & Printing Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'stock_ledger_report_dialogs.dart';

/// =====================================================================
/// DATA MODELS & PARSERS
/// =====================================================================
class StockLedgerReportRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final List<String> itemCodes;
  final bool withValue;
  final bool useMiti;

  const StockLedgerReportRequest({
    required this.fromDate,
    required this.toDate,
    this.itemCodes = const [],
    this.withValue = false,
    this.useMiti = false,
  });

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'fromDate': _d(fromDate),
        'toDate': _d(toDate),
        'itemCode': itemCodes.join(','),
        'withValue': withValue ? 1 : 0,
        'chkMiti': useMiti ? 1 : 0,
      };
}

/// Dynamic Company Profile mapped directly from the database
class CompanyProfile {
  final String name;
  final String address;
  final String phone;
  final String panVat;

  const CompanyProfile({
    this.name = 'Company Name',
    this.address = 'Company Address',
    this.phone = 'Contact Number',
    this.panVat = 'PAN/VAT No',
  });

  static String _str(dynamic val, String fallback) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    String getVal(List<String> keys, String fallback) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null && json[k].toString().trim().isNotEmpty) {
          return json[k].toString().trim();
        }
        for (final mapKey in json.keys) {
          if (mapKey.toLowerCase() == k.toLowerCase() && json[mapKey] != null && json[mapKey].toString().trim().isNotEmpty) {
            return json[mapKey].toString().trim();
          }
        }
      }
      return fallback;
    }

    return CompanyProfile(
      name: getVal(['CompanyName', 'name'], 'Company Name (Missing in DB)'),
      address: getVal(['FullAddress', 'Address', 'CompanyAddress'], ''),
      phone: getVal(['Phone', 'PhoneNo', 'ContactNo'], ''),
      panVat: getVal(['PanVatNo', 'PanNo', 'VatNo'], ''),
    );
  }
}

class StockLedgerRawRow {
  final String itemName;
  final String? unit;
  final String? displayDate;
  final String particular;
  final String? voucherNo;
  final String? voucherSource;
  final double opening;
  final double inQty;
  final double outQty;
  final double amount;

  StockLedgerRawRow({
    required this.itemName,
    this.unit,
    this.displayDate,
    required this.particular,
    this.voucherNo,
    this.voucherSource,
    this.opening = 0,
    this.inQty = 0,
    this.outQty = 0,
    this.amount = 0,
  });

  factory StockLedgerRawRow.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;
    String? toS(dynamic v) => v?.toString();

    return StockLedgerRawRow(
      itemName: j['ItemName']?.toString() ?? '',
      unit: toS(j['Unit']),
      displayDate: toS(j['DisplayDate']),
      particular: j['Particular']?.toString() ?? '',
      voucherNo: toS(j['VoucherNo']),
      voucherSource: toS(j['VoucherSources']),
      opening: toD(j['Opening']),
      inQty: toD(j['InQty']),
      outQty: toD(j['OutQty']),
      amount: toD(j['Amount']),
    );
  }
}

enum StockLedgerRowKind { itemHeader, entry, itemTotal, grandTotal }

class StockLedgerDisplayRow {
  final StockLedgerRowKind kind;
  final String date;
  final String description;
  final String opening;
  final String openingValue;
  final String inQty;
  final String inQtyValue;
  final String outQty;
  final String outQtyValue;
  final String balance;
  final String rate;
  final String value;
  final String? voucherNo;
  final String? source;

  const StockLedgerDisplayRow({
    required this.kind,
    this.date = '',
    required this.description,
    this.opening = '',
    this.openingValue = '',
    this.inQty = '',
    this.inQtyValue = '',
    this.outQty = '',
    this.outQtyValue = '',
    this.balance = '',
    this.rate = '',
    this.value = '',
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

String _dateStr(String? displayDate, {DateTime? fallbackDate, bool useMiti = false}) {
  if (displayDate != null && displayDate.isNotEmpty) return displayDate;
  if (fallbackDate == null) return '';

  if (useMiti) {
    return NepaliDateTime.fromDateTime(fallbackDate).format('dd/MM/yyyy');
  }
  return '${fallbackDate.day.toString().padLeft(2, '0')}/${fallbackDate.month.toString().padLeft(2, '0')}/${fallbackDate.year}';
}

List<StockLedgerDisplayRow> buildStockLedgerReportRows(
  List<StockLedgerRawRow> rows, {
  required bool withValue,
  DateTime? fallbackDate,
  bool useMiti = false,
}) {
  final result = <StockLedgerDisplayRow>[];
  String currentItem = '';

  double itemOpening = 0, itemIn = 0, itemOut = 0;
  double itemOpeningValue = 0, itemInValue = 0, itemOutValue = 0;

  double totalOpening = 0, totalIn = 0, totalOut = 0;
  double totalOpeningValue = 0, totalInValue = 0, totalOutValue = 0;

  void closeItem() {
    if (currentItem.isEmpty) return;
    final balanceQty = itemOpening + itemIn - itemOut;
    final balanceValue = itemOpeningValue + itemInValue - itemOutValue;

    result.add(StockLedgerDisplayRow(
      kind: StockLedgerRowKind.itemTotal,
      description: 'Item Total',
      opening: _fmt(itemOpening.abs()),
      openingValue: withValue ? _fmt(itemOpeningValue.abs()) : '',
      inQty: _fmt(itemIn.abs()),
      inQtyValue: withValue ? _fmt(itemInValue.abs()) : '',
      outQty: _fmt(itemOut.abs()),
      outQtyValue: withValue ? _fmt(itemOutValue.abs()) : '',
      balance: _fmt(balanceQty),
      value: withValue ? _fmt(balanceValue.abs()) : '',
    ));
  }

  for (final r in rows) {
    if (currentItem != r.itemName) {
      closeItem();
      itemOpening = 0;
      itemIn = 0;
      itemOut = 0;
      itemOpeningValue = 0;
      itemInValue = 0;
      itemOutValue = 0;
      currentItem = r.itemName;
      result.add(StockLedgerDisplayRow(
        kind: StockLedgerRowKind.itemHeader,
        description: 'A/c : $currentItem${(r.unit != null && r.unit!.isNotEmpty) ? '     - ${r.unit}' : ''}',
      ));
    }

    String desc = r.particular;
    if (r.voucherNo != null && r.voucherNo!.isNotEmpty) {
      desc += '  # : ${r.voucherNo}';
    }

    String openingCell = '';
    String openingValueCell = '';
    if (r.opening > 0) {
      openingCell = _fmt(r.opening);
      itemOpening += r.opening;
      totalOpening += r.opening;
      if (withValue) {
        openingValueCell = _fmt(r.amount);
        itemOpeningValue += r.amount;
        totalOpeningValue += r.amount;
      }
    }

    String inCell = '';
    String inValueCell = '';
    if (r.inQty > 0) {
      inCell = _fmt(r.inQty);
      itemIn += r.inQty;
      totalIn += r.inQty;
      if (withValue) {
        inValueCell = _fmt(r.amount);
        itemInValue += r.amount;
        totalInValue += r.amount;
      }
    }

    String outCell = '';
    String outValueCell = '';
    if (r.outQty > 0) {
      outCell = _fmt(r.outQty);
      itemOut += r.outQty;
      totalOut += r.outQty;
      if (withValue) {
        outValueCell = _fmt(r.amount);
        itemOutValue += r.amount;
        totalOutValue += r.amount;
      }
    }

    final runningBalanceQty = itemOpening + itemIn - itemOut;

    String rateCell = '';
    String valueCell = '';
    if (withValue) {
      if (runningBalanceQty == 0) {
        valueCell = '0.00';
      } else {
        final runningBalanceValue = itemOpeningValue + itemInValue - itemOutValue;
        final rate = runningBalanceValue / runningBalanceQty;
        rateCell = _fmt(rate);
        valueCell = _fmt(runningBalanceValue.abs());
      }
    }

    result.add(StockLedgerDisplayRow(
      kind: StockLedgerRowKind.entry,
      date: _dateStr(r.displayDate, fallbackDate: fallbackDate, useMiti: useMiti),
      description: desc,
      opening: openingCell,
      openingValue: openingValueCell,
      inQty: inCell,
      inQtyValue: inValueCell,
      outQty: outCell,
      outQtyValue: outValueCell,
      balance: _fmt(runningBalanceQty),
      rate: rateCell,
      value: valueCell,
      voucherNo: r.voucherNo,
      source: r.voucherSource,
    ));
  }
  closeItem();

  if (rows.isNotEmpty) {
    final grandBalanceQty = totalOpening + totalIn - totalOut;
    final grandBalanceValue = totalOpeningValue + totalInValue - totalOutValue;
    result.add(StockLedgerDisplayRow(
      kind: StockLedgerRowKind.grandTotal,
      description: 'Grand Total',
      opening: _fmt(totalOpening.abs()),
      openingValue: withValue ? _fmt(totalOpeningValue.abs()) : '',
      inQty: _fmt(totalIn.abs()),
      inQtyValue: withValue ? _fmt(totalInValue.abs()) : '',
      outQty: _fmt(totalOut.abs()),
      outQtyValue: withValue ? _fmt(totalOutValue.abs()) : '',
      balance: _fmt(grandBalanceQty),
      value: withValue ? _fmt(grandBalanceValue.abs()) : '',
    ));
  }

  return result;
}

/// =====================================================================
/// COLUMN SPEC
/// =====================================================================
class _Col {
  final String label;
  final double baseWidth;
  final TextAlign align;
  final String Function(StockLedgerDisplayRow) get;

  const _Col(this.label, this.baseWidth, this.align, this.get);
}

List<_Col> _columns(bool withValue) {
  if (!withValue) {
    return [
      _Col('Date', 80, TextAlign.center, (r) => r.date),
      _Col('Description', 300, TextAlign.left, (r) => r.description),
      _Col('Opening', 90, TextAlign.right, (r) => r.opening),
      _Col('In Qty', 90, TextAlign.right, (r) => r.inQty),
      _Col('Out Qty', 90, TextAlign.right, (r) => r.outQty),
      _Col('Balance', 90, TextAlign.right, (r) => r.balance),
    ];
  }
  return [
    _Col('Date', 75, TextAlign.center, (r) => r.date),
    _Col('Description', 260, TextAlign.left, (r) => r.description),
    _Col('Opening', 75, TextAlign.right, (r) => r.opening),
    _Col('Opening Val', 85, TextAlign.right, (r) => r.openingValue),
    _Col('In Qty', 75, TextAlign.right, (r) => r.inQty),
    _Col('In Val', 85, TextAlign.right, (r) => r.inQtyValue),
    _Col('Out Qty', 75, TextAlign.right, (r) => r.outQty),
    _Col('Out Val', 85, TextAlign.right, (r) => r.outQtyValue),
    _Col('Balance', 75, TextAlign.right, (r) => r.balance),
    _Col('Rate', 75, TextAlign.right, (r) => r.rate),
    _Col('Value', 85, TextAlign.right, (r) => r.value),
  ];
}

/// =====================================================================
/// RESPONSIVE DESKTOP-STYLE GRID SCREEN
/// =====================================================================
typedef StockLedgerFetcher = Future<List<StockLedgerRawRow>> Function(StockLedgerReportRequest request);

class StockLedgerReportScreen extends StatefulWidget {
  final StockLedgerReportRequest request;
  final StockLedgerFetcher fetchRows;

  const StockLedgerReportScreen({
    super.key,
    required this.request,
    required this.fetchRows,
  });

  @override
  State<StockLedgerReportScreen> createState() => _StockLedgerReportScreenState();
}

class _StockLedgerReportScreenState extends State<StockLedgerReportScreen> {
  late Future<List<StockLedgerDisplayRow>> _future;
  late Future<CompanyProfile> _companyProfileFuture;
  final ApiService _api = ApiService();

  double _zoom = 1.0;
  double _baseZoom = 1.0;
  int _activePointers = 0;
  late final List<_Col> _cols = _columns(widget.request.withValue);

  @override
  void initState() {
    super.initState();
    _future = _load();
    _companyProfileFuture = _fetchCompanyProfile();
  }

  Future<List<StockLedgerDisplayRow>> _load() async {
    final raw = await widget.fetchRows(widget.request);
    return buildStockLedgerReportRows(
      raw,
      withValue: widget.request.withValue,
      fallbackDate: widget.request.fromDate,
      useMiti: widget.request.useMiti,
    );
  }

  Future<CompanyProfile> _fetchCompanyProfile() async {
    try {
      final response = await _api.get('company/profile').timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        var decoded = _api.decodeResponse(response);
        if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
        if (decoded is Map<String, dynamic>) {
          var data = decoded.containsKey('data') ? decoded['data'] : decoded;
          return CompanyProfile.fromJson(data as Map<String, dynamic>);
        }
      } else {
        return CompanyProfile(name: 'Error ${response.statusCode}', address: response.body.toString());
      }
    } catch (e) {
      return CompanyProfile(name: 'App Exception', address: e.toString());
    }
    return const CompanyProfile();
  }

  void _refresh() => setState(() {
        _future = _load();
        _companyProfileFuture = _fetchCompanyProfile();
      });

  void _zoomIn() => setState(() => _zoom = (_zoom + 0.15).clamp(0.5, 3.0));
  void _zoomOut() => setState(() => _zoom = (_zoom - 0.15).clamp(0.5, 3.0));

  String _formatDate(DateTime d) {
    if (widget.request.useMiti) {
      return NepaliDateTime.fromDateTime(d).format('dd/MM/yyyy');
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _sharePdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final rows = await _future;
      final company = await _companyProfileFuture;

      if (rows.isEmpty) throw Exception("No report data to share");

      final doc = pw.Document();
      final cols = _cols;

      final now = DateTime.now();
      final todayStr = widget.request.useMiti
          ? NepaliDateTime.fromDateTime(now).format('dd/MM/yyyy')
          : '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      doc.addPage(
        pw.MultiPage(
          maxPages: 200,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // ==================================================
              // PDF HEADER: CENTERED COMPANY DETAILS, THEN 3-COLUMN ROW
              // ==================================================
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.cyan100),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. CENTER: COMPANY DETAILS ---
                    if (company.name.isNotEmpty) ...[
                      pw.Text(
                        company.name,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                    ],
                    if (company.address.isNotEmpty) ...[
                      pw.Text(
                        company.address,
                        style: const pw.TextStyle(fontSize: 8.5),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 1),
                    ],
                    if (company.phone.isNotEmpty) ...[
                      pw.Text(
                        'Ph: ${company.phone}',
                        style: const pw.TextStyle(fontSize: 8.5),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                    ],
                    pw.SizedBox(height: 6),

                    // --- 2. ROW BELOW COMPANY DETAILS ---
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: PAN/VAT & From-To Date
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (company.panVat.isNotEmpty) ...[
                                pw.Text(
                                  'PAN/VAT No: ${company.panVat}',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.SizedBox(height: 2),
                              ],
                              pw.Text(
                                'From: ${_formatDate(widget.request.fromDate)}\nTo: ${_formatDate(widget.request.toDate)}',
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                        // Center: Stock Ledger Report
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'Stock Ledger Report',
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Right: Today's Date
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Date: $todayStr',
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ==================================================
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  for (int i = 0; i < cols.length; i++)
                    i: i == 1 ? const pw.FlexColumnWidth() : pw.FixedColumnWidth(cols[i].baseWidth * 0.85),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      for (final c in cols)
                        _pdfCell(c.label, isHeader: true, align: pw.TextAlign.center),
                    ],
                  ),
                  ...rows.map((row) {
                    final isHeaderRow = row.kind == StockLedgerRowKind.itemHeader;
                    final isTotal = row.kind == StockLedgerRowKind.itemTotal || row.kind == StockLedgerRowKind.grandTotal;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isHeaderRow || isTotal ? PdfColors.grey100 : PdfColors.white,
                      ),
                      children: [
                        for (int i = 0; i < cols.length; i++)
                          _pdfCell(
                            cols[i].get(row),
                            align: i == 1
                                ? (isTotal ? pw.TextAlign.right : pw.TextAlign.left)
                                : (cols[i].align == TextAlign.right ? pw.TextAlign.right : pw.TextAlign.center),
                            isBold: isHeaderRow || isTotal,
                          ),
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
        filename: 'Stock_Ledger_Report_${NepaliDateTime.now().format('yyyy_MM_dd')}.pdf',
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stock Ledger Report'),
        actions: [
          IconButton(onPressed: _sharePdf, icon: const Icon(Icons.share_rounded), tooltip: 'Share PDF'),
          IconButton(onPressed: _zoomOut, icon: const Icon(Icons.zoom_out_rounded), tooltip: 'Zoom Out'),
          IconButton(onPressed: _zoomIn, icon: const Icon(Icons.zoom_in_rounded), tooltip: 'Zoom In'),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: FutureBuilder<List<StockLedgerDisplayRow>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Failed to load stock ledger: ${snap.error}'));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return const Center(child: Text('No stock movements in this period'));
            }

            final cols = _cols;
            final widths = cols.map((c) => c.baseWidth * _zoom).toList();
            final screenWidth = MediaQuery.of(context).size.width;
            final baseTotalWidth = widths.fold<double>(0, (a, b) => a + b);
            final extraSpace = screenWidth > baseTotalWidth ? (screenWidth - baseTotalWidth) : 0.0;

            widths[1] += extraSpace;
            final dynamicTotalWidth = baseTotalWidth + extraSpace;

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_zoom)),
              child: Column(
                children: [
                  // ==================================================
                  // APP SCREEN HEADER: CENTERED COMPANY DETAILS, THEN 3-COLUMN ROW
                  // ==================================================
                  Container(
                    color: const Color(0xFF00E5FF),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16 * _zoom, vertical: 10 * _zoom),
                    child: FutureBuilder<CompanyProfile>(
                      future: _companyProfileFuture,
                      builder: (context, companySnap) {
                        if (companySnap.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0 * _zoom),
                              child: const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2),
                              ),
                            ),
                          );
                        }

                        final company = companySnap.data ?? const CompanyProfile();
                        
                        final now = DateTime.now();
                        final todayStr = widget.request.useMiti
                            ? NepaliDateTime.fromDateTime(now).format('dd/MM/yyyy')
                            : '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- 1. CENTER: COMPANY DETAILS ---
                            if (company.name.isNotEmpty) ...[
                              Text(
                                company.name,
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold, 
                                  color: company.name.contains('API FAILED') ? Colors.red.shade900 : Colors.black87
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 2 * _zoom),
                            ],
                            if (company.address.isNotEmpty) ...[
                              Text(
                                company.address,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 1 * _zoom),
                            ],
                            if (company.phone.isNotEmpty) ...[
                              Text(
                                'Ph: ${company.phone}',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 2 * _zoom),
                            ],
                            SizedBox(height: 6 * _zoom),

                            // --- 2. ROW BELOW COMPANY DETAILS ---
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left: PAN/VAT & From-To Date
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (company.panVat.isNotEmpty) ...[
                                        Text(
                                          'PAN/VAT No: ${company.panVat}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        SizedBox(height: 2 * _zoom),
                                      ],
                                      Text(
                                        'From: ${_formatDate(widget.request.fromDate)}\nTo: ${_formatDate(widget.request.toDate)}',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),

                                // Center: Stock Ledger Report Title
                                const Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Stock Ledger Report',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),

                                // Right: Today's Date
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Date: $todayStr',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // ==================================================
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
                          setState(() => _zoom = (_baseZoom * details.scale).clamp(0.5, 3.0));
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
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      _buildGridHeader(cols, widths),
                                      Expanded(
                                        child: Scrollbar(
                                          thumbVisibility: true,
                                          child: ListView.builder(
                                            physics: _activePointers > 1
                                                ? const NeverScrollableScrollPhysics()
                                                : const ClampingScrollPhysics(),
                                            itemCount: rows.length,
                                            itemBuilder: (context, i) => _buildRow(rows[i], cols, widths),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned.fill(child: IgnorePointer(child: _buildColumnSeparators(widths))),
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

  Widget _buildGridHeader(List<_Col> cols, List<double> widths) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEEEEEE),
        border: Border(bottom: BorderSide(color: Colors.black45, width: 1.5)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < cols.length; i++)
            _cell(cols[i].label, width: widths[i], isHeader: true, align: cols[i].align == TextAlign.left ? TextAlign.left : TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildColumnSeparators(List<double> widths) {
    final lines = <Widget>[];
    double x = 0;
    for (final w in widths) {
      x += w;
      lines.add(Positioned(left: x - 1, top: 0, bottom: 0, child: Container(width: 1, color: Colors.black26)));
    }
    return Stack(children: lines);
  }

  Widget _cell(
    String text, {
    required double width,
    bool isHeader = false,
    TextAlign align = TextAlign.center,
    bool isBold = false,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 6 * _zoom, vertical: 8 * _zoom),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : align == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.black87 : Colors.black,
        ),
      ),
    );
  }

  Widget _buildRow(StockLedgerDisplayRow row, List<_Col> cols, List<double> widths) {
    final isHeaderRow = row.kind == StockLedgerRowKind.itemHeader;
    final isTotal = row.kind == StockLedgerRowKind.itemTotal || row.kind == StockLedgerRowKind.grandTotal;

    return Container(
      decoration: BoxDecoration(
        color: isHeaderRow || isTotal ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isTotal ? Colors.black45 : Colors.black12,
            width: isTotal ? 1.5 : 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < cols.length; i++)
            _cell(
              cols[i].get(row),
              width: widths[i],
              align: i == 1
                  ? (isTotal ? TextAlign.right : TextAlign.left)
                  : cols[i].align,
              isBold: isHeaderRow || isTotal,
            ),
        ],
      ),
    );
  }
}

/// =====================================================================
/// ENTRY POINT / LANDING PAGE
/// =====================================================================
class StockLedgerReportPage extends StatelessWidget {
  const StockLedgerReportPage({super.key});

  static final ApiService _api = ApiService();

  static Future<List<StockLedgerRawRow>> _fetchStockLedgerRows(StockLedgerReportRequest request) async {
    debugPrint('Stock ledger report request: ${request.toJson()}');
    final response = await _api
        .post('stock-ledger/report', body: request.toJson())
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Stock ledger report request timed out after 60s.'),
        );

    if (response.statusCode != 200) {
      throw Exception('Stock ledger report request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = _api.decodeResponse(response);
    final list = decoded is List ? decoded : const [];

    return list.map((j) => StockLedgerRawRow.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Ledger Report')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No Report Generated', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Select a date range and items\nto generate your stock ledger report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('Select Dates & Items'),
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
                  final fetchedItems = await fetchStockLedgerItemOptions();

                  if (context.mounted) Navigator.pop(context);

                  if (context.mounted) {
                    showStockLedgerReportFlow(
                      context,
                      items: fetchedItems,
                      fetchRows: _fetchStockLedgerRows,
                    );
                  }
                } catch (error) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to load items: $error'),
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