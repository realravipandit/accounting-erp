import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/services/pdf/pdf_generator_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> transactionData;
  final String invoiceType;

  const PdfPreviewScreen({
    super.key, 
    required this.transactionData, 
    required this.invoiceType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: PdfPreview(
        build: (format) => PdfGeneratorService.generateInvoice(transactionData, invoiceType),
        maxPageWidth: 400, // <-- Add this line to prevent the preview from over-stretching
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}