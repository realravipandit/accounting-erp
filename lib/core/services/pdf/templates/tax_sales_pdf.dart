import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TaxSalesPdf {
  static Future<Uint8List> generate(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pw.Widget dashedLine() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1, color: PdfColors.black),
        );

    final pw.TextStyle bodyStyle = pw.TextStyle(fontSize: 9);
    final pw.TextStyle boldStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(15), 
        build: (pw.Context context) {
          final List<dynamic> items = data['items'] ?? [];
          final Map<String, dynamic> company = data['companyInfo'] ?? {};
          
          final String companyName = company['CompanyName'] ?? company['companyName'] ?? 'GMART';
          final String panNo = company['panvatno'] ?? company['PanVatNo'] ?? company['PANVATNO'] ?? '';
          final String companyAddress = company['fulladdress'] ?? company['FullAddress'] ?? '';
          final String phone = company['Phone'] ?? company['phone'] ?? '';
          final String email = company['Email'] ?? company['email'] ?? '';

          // 1. Dynamically sum the exact item amounts printed in the table above
          double itemsTotalAmount = 0.0;
          for (var item in items) {
            itemsTotalAmount += double.tryParse(item['amount'].toString()) ?? 0.0;
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header Section
              pw.Center(child: pw.Text(companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              if (companyAddress.isNotEmpty)
                pw.Center(child: pw.Text(companyAddress, style: bodyStyle)),
              if (phone.isNotEmpty || email.isNotEmpty)
                pw.Center(child: pw.Text('Ph: $phone${email.isNotEmpty ? ' | Email: $email' : ''}', style: bodyStyle)),
              pw.Center(child: pw.Text('VAT NO: $panNo', style: bodyStyle)),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text(data['printStatus'] ?? 'Original', style: bodyStyle)),
              pw.SizedBox(height: 6),
              
              // Invoice Meta Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv No: ${data['voucherId'] ?? ''}', style: bodyStyle),
                  pw.Text('Miti: ${data['miti'] ?? ''}', style: bodyStyle),
                ],
              ),
              pw.Text('Customer: ${data['customerName'] ?? 'Cash Party'}', style: bodyStyle),
              
              // Print customer address if it exists
              if ((data['customerAddress'] ?? '').toString().trim().isNotEmpty)
                pw.Text('Address: ${data['customerAddress']}', style: bodyStyle),
              dashedLine(),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 1, child: pw.Text('SN.', style: boldStyle)),
                  pw.Expanded(flex: 4, child: pw.Text('Particulars', style: boldStyle)),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: boldStyle)),
                  pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: boldStyle)),
                  pw.Expanded(flex: 2, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: boldStyle)),
                ],
              ),
              dashedLine(),

              // Items List
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 1, child: pw.Text('${item['sno'] ?? ''}.', style: bodyStyle)),
                      pw.Expanded(flex: 4, child: pw.Text('${item['itemName'] ?? ''}', style: bodyStyle)),
                      pw.Expanded(flex: 1, child: pw.Text('${item['qty'] ?? ''}', textAlign: pw.TextAlign.right, style: bodyStyle)),
                      pw.Expanded(flex: 2, child: pw.Text('${item['rate'] ?? ''}', textAlign: pw.TextAlign.right, style: bodyStyle)),
                      pw.Expanded(flex: 2, child: pw.Text('${item['amount'] ?? ''}', textAlign: pw.TextAlign.right, style: bodyStyle)),
                    ],
                  ),
                );
              }),
              dashedLine(),

              // Tax Summary Totals Section
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total:', style: bodyStyle), pw.Text(itemsTotalAmount.toStringAsFixed(2), style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tax Exempted Value:', style: bodyStyle), pw.Text('${data['taxExemptedValue'] ?? '0.00'}', style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Taxable Value:', style: bodyStyle), pw.Text('${data['taxableValue'] ?? '0.00'}', style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Vat (13%) :', style: bodyStyle), pw.Text('${data['vatAmount'] ?? '0.00'}', style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Net Bill Amount:', style: boldStyle), pw.Text('${data['netAmount'] ?? '0.00'}', style: boldStyle)]),
              
              // Added Dashed line below Net Bill Amount
              dashedLine(),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tender Amount:', style: bodyStyle), pw.Text('${data['tenderAmount'] ?? '0.00'}', style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Return Amount :', style: bodyStyle), pw.Text('${data['returnAmount'] ?? '0.00'}', style: bodyStyle)]),
              dashedLine(),

              // Amount In Words
              pw.Text('Amount In Word: ${data['amountInWords'] ?? ''}', style: bodyStyle),
              pw.Text('Payment Mode: ${data['paymentMode'] ?? 'Cash'}', style: bodyStyle),
              
              // Added Dashed line after Payment Mode
              dashedLine(),

              // Meta Info Section (Counter and Time in same row)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Counter: ${data['counter'] ?? ''}', style: bodyStyle),
                  pw.Text('Time: ${data['time'] ?? ''}', style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              
              // Cashier in next row
              pw.Text('Cashier: ${data['cashier'] ?? ''}', style: bodyStyle),
              
              if ((data['remarks'] ?? '').toString().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Remarks: ${data['remarks']}', style: bodyStyle),
              ],
              dashedLine(),
              // Footer Section
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text('THANK YOU & VISIT AGAIN !!!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}