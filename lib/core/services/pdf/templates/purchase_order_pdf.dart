import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ============================================================================
// PURCHASE ORDER PDF (A4, multi-page)
// Same layout as SalesOrderPdf: margin 30, body 10 / bold 10.5, company 18,
// title 13.5, repeated column header + "(contd.)" line, "Page x of y" footer.
// Vendor address and PAN/VAT lines are skipped when empty.
// ============================================================================

class PurchaseOrderPdf {
  static Future<Uint8List> generate(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pw.Widget dashedLine() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1, color: PdfColors.black),
        );

    final pw.TextStyle bodyStyle = pw.TextStyle(fontSize: 10);
    final pw.TextStyle boldStyle = pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold);
    final pw.TextStyle companyNameStyle = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
    final pw.TextStyle titleStyle = pw.TextStyle(fontSize: 13.5, fontWeight: pw.FontWeight.bold);
    final pw.TextStyle smallStyle = pw.TextStyle(fontSize: 8);

    pw.Widget summaryRow(String label, String value, {pw.TextStyle? style}) {
      final s = style ?? bodyStyle;
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: s),
            pw.Text(value, style: s),
          ],
        ),
      );
    }

    final List<dynamic> items = data['items'] ?? [];
    final List<dynamic> billTerms = data['billTerms'] ?? [];
    final Map<String, dynamic> company = data['companyInfo'] ?? {};

    final String companyName = company['CompanyName'] ?? company['companyName'] ?? 'GMART';
    final String panNo = company['panvatno'] ?? company['PanVatNo'] ?? company['PANVATNO'] ?? '';
    final String address = company['fulladdress'] ?? company['FullAddress'] ?? '';
    final String phone = company['Phone'] ?? company['phone'] ?? '';
    final String email = company['Email'] ?? company['email'] ?? '';

    final String vendorName = data['vendorName'] ?? '';
    final String vendorAddress = '${data['vendorAddress'] ?? ''}'.trim();
    final String vendorPan = '${data['vendorPan'] ?? ''}'.trim();
    final String orderNumber = '${data['orderNumber'] ?? ''}';

    pw.Widget tableHeaderRow() => pw.Row(
          children: [
            pw.Expanded(flex: 1, child: pw.Text('SN.', style: boldStyle)),
            pw.Expanded(flex: 4, child: pw.Text('Particulars', style: boldStyle)),
            pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: boldStyle)),
            pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: boldStyle)),
            pw.Expanded(flex: 2, child: pw.Text('Term Amt', textAlign: pw.TextAlign.right, style: boldStyle)),
            pw.Expanded(flex: 2, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: boldStyle)),
          ],
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text(companyName, style: companyNameStyle)),
                if (address.isNotEmpty) pw.Center(child: pw.Text(address, style: bodyStyle)),
                if (phone.isNotEmpty || email.isNotEmpty)
                  pw.Center(child: pw.Text('Ph: $phone${email.isNotEmpty ? ' | Email: $email' : ''}', style: bodyStyle)),
                if (panNo.isNotEmpty) pw.Center(child: pw.Text('VAT/PAN NO: $panNo', style: bodyStyle)),
                pw.SizedBox(height: 6),
                pw.Center(child: pw.Text('PURCHASE ORDER', style: titleStyle)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Order No: $orderNumber', style: bodyStyle),
                    pw.Text('Date: ${data['orderDate'] ?? ''}', style: bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Vendor: $vendorName', style: bodyStyle),
                    pw.Text('Miti : ${data['miti'] ?? ''}', style: bodyStyle),
                  ],
                ),
                if (vendorAddress.isNotEmpty) pw.Text('Address: $vendorAddress', style: bodyStyle),
                if (vendorPan.isNotEmpty) pw.Text('PAN/VAT No: $vendorPan', style: bodyStyle),
                pw.SizedBox(height: 3),
                pw.Text('Status: ${data['status'] ?? ''}', style: boldStyle),
                dashedLine(),
                tableHeaderRow(),
                dashedLine(),
              ],
            );
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Order No: $orderNumber (contd.)', style: smallStyle),
              pw.SizedBox(height: 4),
              tableHeaderRow(),
              dashedLine(),
            ],
          );
        },
        footer: (pw.Context context) {
          if (context.pagesCount <= 1) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: smallStyle),
          );
        },
        build: (pw.Context context) => [
          ...items.map((item) {
            final String qty = '${item['qty'] ?? ''}';
            final String unit = '${item['unit'] ?? ''}'.trim();
            final String qtyWithUnit = unit.isEmpty ? qty : '$qty $unit';
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 1, child: pw.Text('${item['sno'] ?? ''}.', style: bodyStyle)),
                  pw.Expanded(flex: 4, child: pw.Text('${item['itemName'] ?? ''}', style: bodyStyle)),
                  pw.Expanded(flex: 2, child: pw.Text(qtyWithUnit, textAlign: pw.TextAlign.right, style: bodyStyle)),
                  pw.Expanded(flex: 2, child: pw.Text('${item['rate'] ?? ''}', textAlign: pw.TextAlign.right, style: bodyStyle)),
                  pw.Expanded(flex: 2, child: pw.Text('${item['termAmount'] ?? '0.00'}', textAlign: pw.TextAlign.right, style: bodyStyle)),
                  pw.Expanded(flex: 2, child: pw.Text('${item['amount'] ?? ''}', textAlign: pw.TextAlign.right, style: bodyStyle)),
                ],
              ),
            );
          }),
          dashedLine(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 230,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    summaryRow('Basic Amount:', '${data['basicAmount'] ?? '0.00'}'),
                    ...billTerms.map((t) => summaryRow('${t['name'] ?? ''}:', '${t['amount'] ?? '0.00'}')),
                    dashedLine(),
                    summaryRow('Net Total :', '${data['netAmount'] ?? '0.00'}', style: boldStyle),
                  ],
                ),
              ),
            ],
          ),
          dashedLine(),
          if ((data['remarks'] ?? '').toString().isNotEmpty) ...[
            pw.Text('Remarks: ${data['remarks']}', style: bodyStyle),
            dashedLine(),
          ],
          pw.SizedBox(height: 3),
          pw.Center(child: pw.Text('This is a computer generated Purchase Order', style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic))),
        ],
      ),
    );

    return pdf.save();
  }
}