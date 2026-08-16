import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:sas_akount_login/models/sales/sales.dart';
import 'package:sas_akount_login/models/purchase/purchase.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<File> generateInvoice(Sales sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('SAS Akount - Sales Invoice',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              _buildInvoiceHeader(sale),
              pw.SizedBox(height: 30),
              _buildItemsTable(sale),
              pw.SizedBox(height: 30),
              _buildTotalSection(sale),
              pw.SizedBox(height: 50),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return _saveDocument(name: 'invoice_${sale.invoiceNumber}.pdf', pdf: pdf);
  }

  static Future<File> generatePurchaseInvoice(Purchase purchase) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('SAS Akount - Purchase Invoice',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              _buildPurchaseHeader(purchase),
              pw.SizedBox(height: 30),
              _buildPurchaseItemsTable(purchase),
              pw.SizedBox(height: 30),
              _buildPurchaseTotalSection(purchase),
              pw.SizedBox(height: 50),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return _saveDocument(name: 'purchase_${purchase.id}.pdf', pdf: pdf);
  }

  static Future<void> generateAndShareReport({
    required String title,
    required List<Map<String, dynamic>> data,
    required List<String> headers,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text(title)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: headers,
                data: data
                    .map((item) =>
                        headers.map((h) => item[h].toString()).toList())
                    .toList(),
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Generated on: ${DateTime.now().toString()}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${title.toLowerCase().replaceAll(' ', '_')}_report.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static pw.Widget _buildInvoiceHeader(Sales sale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Customer: ${sale.customerName ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 16)),
                pw.Text('Invoice: ${sale.invoiceNumber}',
                    style: const pw.TextStyle(fontSize: 16)),
                if (sale.date != null)
                  pw.Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(sale.date!)}',
                      style: const pw.TextStyle(fontSize: 16)),
              ],
            ),
            pw.Container(
              height: 100,
              width: 100,
              child: pw.FlutterLogo(),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildPurchaseHeader(Purchase purchase) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Supplier: ${purchase.supplierName ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 16)),
                pw.Text('Invoice: ${purchase.invoiceNumber ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 16)),
                if (purchase.date != null)
                  pw.Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(purchase.date!)}',
                      style: const pw.TextStyle(fontSize: 16)),
              ],
            ),
            pw.Container(
              height: 100,
              width: 100,
              child: pw.FlutterLogo(),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildItemsTable(Sales sale) {
    return pw.Table.fromTextArray(
      headers: ['Product', 'Quantity', 'Price', 'Total'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 12),
      data: sale.items.map((item) {
        return [
          item.productName ?? 'N/A',
          item.quantity?.toString() ?? '0',
          'Rs. ${item.price?.toStringAsFixed(2) ?? "0.00"}',
          'Rs. ${((item.quantity ?? 0) * (item.price ?? 0)).toStringAsFixed(2)}'
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildPurchaseItemsTable(Purchase purchase) {
    return pw.Table.fromTextArray(
      headers: ['Product', 'Quantity', 'Price', 'Total'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 12),
      data: purchase.items.map((item) {
        return [
          item.productName ?? 'N/A',
          item.quantity?.toString() ?? '0',
          'Rs. ${item.price?.toStringAsFixed(2) ?? "0.00"}',
          'Rs. ${((item.quantity ?? 0) * (item.price ?? 0)).toStringAsFixed(2)}'
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildTotalSection(Sales sale) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Rs. ${sale.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                    style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total:',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Rs. ${sale.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Payment Method: ${sale.paymentMethod}',
                style: const pw.TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPurchaseTotalSection(Purchase purchase) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 14)),
                pw.Text(
                    'Rs. ${purchase.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                    style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total:',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Rs. ${purchase.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'Thank you for your business!',
        style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  static Future<File> _saveDocument({
    required String name,
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  // =========================================================================
  // THE UNIVERSAL DOCUMENT BUILDER
  // Use this for Sales, Purchases, Payables, Receivables, etc.
  // =========================================================================
  static Future<void> generateAndShareGenericDocument({
    required String documentTitle,    // e.g., "Purchase Invoice" or "Sales Receipt"
    required String entityLabel,      // e.g., "Supplier:" or "Customer:"
    required String entityName,       // e.g., "ABC Traders"
    required String referenceLabel,   // e.g., "Bill No:" or "Invoice No:"
    required String referenceNumber,  // e.g., "INV-1002"
    required String dateLabel,        // e.g., "Date:"
    required String dateValue,        // e.g., "2024-05-12"
    required List<String> tableHeaders, // e.g., ['Product', 'Qty', 'Rate', 'Total']
    required List<List<String>> tableData, // The mapped rows
    required String totalAmount,      // e.g., "1,500.00"
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- Title ---
              pw.Header(
                level: 0,
                child: pw.Text('SAS Akount - $documentTitle',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              
              // --- Header Info (Entity, Ref, Date) ---
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('$entityLabel $entityName', style: const pw.TextStyle(fontSize: 16)),
                          pw.Text('$referenceLabel $referenceNumber', style: const pw.TextStyle(fontSize: 16)),
                          pw.Text('$dateLabel $dateValue', style: const pw.TextStyle(fontSize: 16)),
                        ],
                      ),
                      pw.Container(height: 80, width: 80, child: pw.FlutterLogo()), // Replace with your company logo if needed
                    ],
                  ),
                  pw.Divider(),
                ],
              ),
              pw.SizedBox(height: 30),

              // --- Dynamic Table ---
              pw.Table.fromTextArray(
                headers: tableHeaders,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 12),
                data: tableData,
              ),
              pw.SizedBox(height: 30),

              // --- Totals ---
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs. $totalAmount', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 50),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    // Save and Share
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final safeFileName = '${documentTitle.replaceAll(' ', '_')}_$referenceNumber.pdf';
    final file = File('${dir.path}/$safeFileName');
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles([XFile(file.path)], text: '$documentTitle - $referenceNumber');
  }
}
