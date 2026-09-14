import 'dart:typed_data';
import 'templates/normal_sales_pdf.dart';
import 'templates/abbr_sales_pdf.dart';
import 'templates/tax_sales_pdf.dart';

class PdfGeneratorService {
  static Future<Uint8List> generateInvoice(Map<String, dynamic> transactionData, String invoiceType) async {
    switch (invoiceType.toLowerCase()) {
      case 'tax':
        return await TaxSalesPdf.generate(transactionData);
      case 'abbr':
      case 'abbreviated':
        return await AbbrSalesPdf.generate(transactionData);
      case 'normal':
      default:
        return await NormalSalesPdf.generate(transactionData);
    }
  }
}