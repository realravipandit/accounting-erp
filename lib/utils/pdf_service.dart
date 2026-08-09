// import 'dart:io';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:sas_akount_login/models/sales.dart';
// import 'package:sas_akount_login/models/purchase.dart';

// class PdfService {
//   // Existing sales invoice generation
//   static Future<File> generateInvoice(Sales sale) async {
//     final pdf = pw.Document();
//     pdf.addPage(_buildInvoicePage(sale));
//     return _saveDocument(name: 'invoice_${sale.invoiceNumber}.pdf', pdf: pdf);
//   }

//   // New purchase invoice generation
//   static Future<File> generatePurchaseInvoice(Purchase purchase) async {
//     final pdf = pw.Document();
//     pdf.addPage(_buildPurchaseInvoicePage(purchase));
//     return _saveDocument(name: 'purchase_${purchase.id}.pdf', pdf: pdf);
//   }

//   // Generic report generation for sharing
//   static Future<void> generateAndShareReport({
//     required String title,
//     required List<Map<String, dynamic>> data,
//     required List<String> headers,
//   }) async {
//     final pdf = pw.Document();
//     pdf.addPage(
//       pw.Page(
//         build: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Header(level: 0, child: pw.Text(title)),
//               pw.SizedBox(height: 20),
//               pw.Table.fromTextArray(
//                 context: context,
//                 headers: headers,
//                 data: data
//                     .map((item) =>
//                         headers.map((h) => item[h].toString()).toList())
//                     .toList(),
//                 cellAlignment: pw.Alignment.centerLeft,
//                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//               ),
//               pw.SizedBox(height: 20),
//               pw.Text('Generated on: ${DateTime.now().toString()}',
//                   style: const pw.TextStyle(fontSize: 10)),
//             ],
//           );
//         },
//       ),
//     );

//     final bytes = await pdf.save();
//     final dir = await getTemporaryDirectory();
//     final file = File(
//         '${dir.path}/${title.toLowerCase().replaceAll(' ', '_')}_report.pdf');
//     await file.writeAsBytes(bytes);
//     Share.shareXFiles([XFile(file.path)]);
//   }

//   static pw.Page _buildInvoicePage(Sales sale) {
//     return pw.Page(
//       pageFormat: PdfPageFormat.a4,
//       build: (pw.Context context) {
//         return pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             _buildInvoiceHeader(sale, 'Sales Invoice'),
//             pw.SizedBox(height: 20),
//             _buildItemsTable(
//                 sale.items
//                     .map((item) => [
//                           item.productName ?? 'N/A',
//                           '${item.quantity}',
//                           'Rs. ${item.price?.toStringAsFixed(2)}',
//                           'Rs. ${((item.quantity ?? 0) * (item.price ?? 0)).toStringAsFixed(2)}'
//                         ])
//                     .toList(),
//                 ['Product', 'Quantity', 'Price', 'Total']),
//             pw.SizedBox(height: 30),
//             _buildTotalSection(sale.totalAmount ?? 0, 'Total:'),
//             pw.SizedBox(height: 50),
//             _buildFooter(),
//           ],
//         );
//       },
//     );
//   }

//   static pw.Page _buildPurchaseInvoicePage(Purchase purchase) {
//     return pw.Page(
//       pageFormat: PdfPageFormat.a4,
//       build: (pw.Context context) {
//         return pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             _buildInvoiceHeaderForPurchase(purchase),
//             pw.SizedBox(height: 20),
//             _buildItemsTable(
//                 purchase.items
//                     .map((item) => [
//                           item.productName,
//                           '${item.quantity}',
//                           'Rs. ${item.price.toStringAsFixed(2)}',
//                           'Rs. ${(item.quantity * item.price).toStringAsFixed(2)}'
//                         ])
//                     .toList(),
//                 ['Product', 'Quantity', 'Price', 'Total']),
//             pw.SizedBox(height: 30),
//             _buildTotalSection(purchase.totalAmount, 'Total:'),
//             pw.SizedBox(height: 50),
//             _buildFooter(),
//           ],
//         );
//       },
//     );
//   }

//   static pw.Widget _buildInvoiceHeaderForPurchase(Purchase purchase) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Text('Vendor: ${purchase.vendorName}',
//                     style: const pw.TextStyle(fontSize: 16)),
//                 pw.Text('Purchase #: ${purchase.id}',
//                     style: const pw.TextStyle(fontSize: 16)),
//                 pw.Text(
//                     'Date: ${DateFormat('yyyy-MM-dd').format(purchase.date!)}',
//                     style: const pw.TextStyle(fontSize: 16)),
//               ],
//             ),
//             pw.Container(
//               height: 100,
//               width: 100,
//               child: pw.FlutterLogo(),
//             ),
//           ],
//         ),
//         pw.Divider(),
//       ],
//     );
//   }

//   static pw.Widget _buildInvoiceHeader(Sales sale, String title) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Text('Customer: ${sale.customerName ?? 'N/A'}',
//                     style: const pw.TextStyle(fontSize: 16)),
//                 pw.Text('Invoice: ${sale.invoiceNumber}',
//                     style: const pw.TextStyle(fontSize: 16)),
//                 pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(sale.date!)}',
//                     style: const pw.TextStyle(fontSize: 16)),
//               ],
//             ),
//             pw.Container(
//               height: 100,
//               width: 100,
//               child: pw.FlutterLogo(),
//             ),
//           ],
//         ),
//         pw.Divider(),
//       ],
//     );
//   }

//   static pw.Widget _buildItemsTable(
//       List<List<String>> data, List<String> headers) {
//     return pw.Table.fromTextArray(
//       headers: headers,
//       headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
//       headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
//       cellAlignment: pw.Alignment.centerLeft,
//       cellStyle: const pw.TextStyle(fontSize: 12),
//       data: data,
//     );
//   }

//   static pw.Widget _buildTotalSection(double totalAmount, String label) {
//     return pw.Align(
//       alignment: pw.Alignment.centerRight,
//       child: pw.Container(
//         width: 200,
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.end,
//           children: [
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Text(label,
//                     style: pw.TextStyle(
//                         fontSize: 16, fontWeight: pw.FontWeight.bold)),
//                 pw.Text('Rs. ${totalAmount.toStringAsFixed(2)}',
//                     style: pw.TextStyle(
//                         fontSize: 16, fontWeight: pw.FontWeight.bold)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   static pw.Widget _buildFooter() {
//     return pw.Center(
//       child: pw.Text(
//         'Thank you for your business!',
//         style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
//       ),
//     );
//   }

//   static Future<File> _saveDocument({
//     required String name,
//     required pw.Document pdf,
//   }) async {
//     final bytes = await pdf.save();
//     final dir = await getApplicationDocumentsDirectory();
//     final file = File('${dir.path}/$name');
//     await file.writeAsBytes(bytes);
//     return file;
//   }
// }

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:sas_akount_login/models/sales.dart';
import 'package:sas_akount_login/models/purchase.dart';
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
}
