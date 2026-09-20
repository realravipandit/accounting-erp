import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ============================================================================
// SALES ORDER PDF (A4, multi-page)
//
//   * A4 sizing: margin 30, body 10 / bold 10.5, company name 18, title 13.5
//   * pw.MultiPage: rows flow to further pages on their own based on content
//     height, not a fixed item count
//   * page 1 only: company header, "SALES ORDER" title, order no/date,
//     customer/miti, address, status
//   * page 2+: small "Order No: ... (contd.)" line + repeated column header
//   * footer: "Page x of y", shown only when there is more than one page
//   * totals block, remarks and the generated-by note sit after the last
//     row, on the last page
// ============================================================================

class SalesOrderPdf {
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

    final String customerName = data['customerName'] ?? 'Cash Party';
    final String customerAddress = data['customerAddress'] ?? '';
    final String orderNumber = '${data['orderNumber'] ?? ''}';

    // --- table header row, reused on page 1 and every continuation page ---
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

        // ------------------------------------------------------------
        // HEADER: full block on page 1, compact "(contd.)" line + the
        // column header repeated on every page after that.
        // ------------------------------------------------------------
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
                pw.Center(child: pw.Text('SALES ORDER', style: titleStyle)),
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
                    pw.Text('Customer: $customerName', style: bodyStyle),
                    pw.Text('miti : ${data['miti'] ?? ''}', style: bodyStyle),
                  ],
                ),
                if (customerAddress.isNotEmpty) pw.Text('Address: $customerAddress', style: bodyStyle),
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

        // ------------------------------------------------------------
        // FOOTER: "Page x of y", only when there's more than one page.
        // ------------------------------------------------------------
        footer: (pw.Context context) {
          if (context.pagesCount <= 1) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: smallStyle),
          );
        },

        // ------------------------------------------------------------
        // BODY: item rows first (these are what flow across pages),
        // then totals / remarks / note at the very end (last page).
        // ------------------------------------------------------------
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
          pw.Center(child: pw.Text('This is a computer generated Sales Order', style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic))),
        ],
      ),
    );

    return pdf.save();
  }
}