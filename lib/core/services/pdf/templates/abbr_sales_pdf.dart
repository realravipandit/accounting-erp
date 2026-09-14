import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AbbrSalesPdf {
  static Future<Uint8List> generate(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pw.Widget dashedLine() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1, color: PdfColors.black),
        );

    // Added dottedLine widget for the net total underline
    pw.Widget dottedLine() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Divider(borderStyle: pw.BorderStyle.dotted, thickness: 1, color: PdfColors.black),
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
          final String address = company['fulladdress'] ?? company['FullAddress'] ?? '';
          final String phone = company['Phone'] ?? company['phone'] ?? '';
          final String email = company['Email'] ?? company['email'] ?? '';

          // Extracted customer info for cleaner placement
          final String customerName = data['customerName'] ?? 'Cash Party';
          final String customerAddress = data['customerAddress'] ?? '';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(companyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              if (address.isNotEmpty)
                pw.Center(child: pw.Text(address, style: bodyStyle)),
              if (phone.isNotEmpty || email.isNotEmpty)
                pw.Center(child: pw.Text('Ph: $phone${email.isNotEmpty ? ' | Email: $email' : ''}', style: bodyStyle)),
              pw.Center(child: pw.Text('VAT/PAN NO: $panNo', style: bodyStyle)),
              pw.SizedBox(height: 6),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv No: ${data['voucherId'] ?? ''}', style: bodyStyle),
                  pw.Text('Miti: ${data['miti'] ?? ''}', style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              
              // Moved Customer Name and Address directly below Inv No / Miti
              pw.Text('Customer: $customerName', style: bodyStyle),
              if (customerAddress.isNotEmpty) 
                pw.Text('Address: $customerAddress', style: bodyStyle),
                
              dashedLine(),
              
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
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Basic Amount:', style: bodyStyle), pw.Text('${data['basicAmount'] ?? '0.00'}', style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Net Total :', style: boldStyle), pw.Text('${data['netAmount'] ?? '0.00'}', style: boldStyle)]),
              
              // Inserted Dotted Underline below Net Total
              dashedLine(),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tender Amount :', style: bodyStyle), pw.Text('${data['tenderAmount'] ?? '0.00'}', style: bodyStyle)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Return Amount :', style: bodyStyle), pw.Text('${data['returnAmount'] ?? '0.00'}', style: bodyStyle)]),
              dashedLine(),
              
              // Amount In Words
              pw.Text('In Words: ${data['amountInWords'] ?? ''}', style: bodyStyle),
              pw.SizedBox(height: 2),
              
              // Moved Payment Mode directly below Amount In Words
              pw.Text('Payment Mode: ${data['paymentMode'] ?? 'Cash'}', style: bodyStyle),
              
              dashedLine(),
              
              // Meta Info Section (Counter/Time, Cashier, Remarks)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Counter: ${data['counter'] ?? ''}', style: bodyStyle),
                  pw.Text('Time: ${data['time'] ?? ''}', style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 1),
              pw.Text('Cashier: ${data['cashier'] ?? ''}', style: bodyStyle),
              pw.SizedBox(height: 1),
              pw.Text('Remarks: ${data['remarks'] ?? ''}', style: bodyStyle),
              dashedLine(),
              // Footer
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