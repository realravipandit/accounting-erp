import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class NormalSalesPdf {
  static Future<Uint8List> generate(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(child: pw.Text('Normal Sales Invoice (Template Pending)'));
        },
      ),
    );
    return pdf.save();
  }
}