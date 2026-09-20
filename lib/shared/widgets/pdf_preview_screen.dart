import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../core/services/pdf/pdf_generator_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> transactionData;
  final String invoiceType;
  final Future<Uint8List> Function(PdfPageFormat format)? pdfBuilder;
  final String title;

  // Optional explicit file name (e.g. 'salesorder_SO-000004.pdf'). When not
  // given, sales invoice previews (the default generateInvoice path) are named
  // salesinvoice_<voucher no>.pdf from transactionData['voucherId'].
  final String? fileName;

  const PdfPreviewScreen({
    super.key,
    required this.transactionData,
    required this.invoiceType,
    this.pdfBuilder,
    this.title = 'Invoice Preview',
    this.fileName,
  });

  // Characters that are not allowed in file names (\ / : * ? " < > |) become '-'.
  String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

  String? _resolveFileName() {
    if (fileName != null && fileName!.trim().isNotEmpty) return fileName;

    // Custom builders (e.g. the Sales Order preview) pass their own name via
    // [fileName]; only the invoice path is named here.
    if (pdfBuilder != null) return null;

    final voucherId = transactionData['voucherId']?.toString().trim() ?? '';
    if (voucherId.isEmpty) return null;

    return 'salesinvoice_${_safe(voucherId)}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: pdfBuilder ?? (format) => PdfGeneratorService.generateInvoice(transactionData, invoiceType),
        pdfFileName: _resolveFileName(),
        maxPageWidth: 400, // <-- Add this line to prevent the preview from over-stretching
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}