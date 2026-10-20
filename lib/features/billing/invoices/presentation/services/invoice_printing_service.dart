import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/invoice.dart';
import 'pdf_file_exporter.dart';

part 'invoice_receipt_page.dart';

class InvoicePrintingService {
  Future<void> printInvoice(Invoice invoice) async {
    final bytes = await buildPdf(invoice);
    await PdfFileExporter.save(bytes: bytes, fileName: _fileName(invoice));
  }

  Future<void> printInvoices(
    List<Invoice> invoices, {
    required String fileName,
  }) async {
    if (invoices.isEmpty) {
      return;
    }
    final bytes = await buildCombinedPdf(invoices, title: fileName);
    await PdfFileExporter.save(bytes: bytes, fileName: fileName);
  }

  Future<void> shareInvoicesIndividually(List<Invoice> invoices) async {
    for (final invoice in invoices) {
      final bytes = await buildPdf(invoice);
      await PdfFileExporter.save(bytes: bytes, fileName: _fileName(invoice));
    }
  }

  Future<Uint8List> buildPdf(
    Invoice invoice, {
    PdfPageFormat format = PdfPageFormat.letter,
  }) async {
    return _buildDocument(
      invoices: [invoice],
      format: format,
      title: 'Recibo ${invoice.codigoUsuario}',
      subject: 'Recibo de pago ${invoice.periodo}',
    );
  }

  Future<Uint8List> buildCombinedPdf(
    List<Invoice> invoices, {
    PdfPageFormat format = PdfPageFormat.letter,
    required String title,
  }) async {
    return _buildDocument(
      invoices: invoices,
      format: format,
      title: title,
      subject:
          'Recibos de pago ${invoices.isEmpty ? '' : invoices.first.periodo}',
    );
  }

  Future<Uint8List> _buildDocument({
    required List<Invoice> invoices,
    required PdfPageFormat format,
    required String title,
    required String subject,
  }) async {
    final assets = await _loadAssets();
    final document = pw.Document(
      title: title,
      author: 'frontAcueductoNewzenda',
      subject: subject,
      theme: pw.ThemeData.withFont(
        base: assets.regularFont,
        bold: assets.boldFont,
      ),
    );

    for (final invoice in invoices) {
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(22),
          build: (context) => _ReceiptPage(
            invoice: invoice,
            logo: assets.logo,
            regularFont: assets.regularFont,
            boldFont: assets.boldFont,
          ),
        ),
      );
    }

    return document.save();
  }

  Future<_PdfAssets> _loadAssets() async {
    final logoBytes = await rootBundle.load('images/imgAcueducto.png');
    final regularFontBytes = await rootBundle.load('assets/fonts/arial.ttf');
    final boldFontBytes = await rootBundle.load('assets/fonts/arialbd.ttf');
    return _PdfAssets(
      logo: pw.MemoryImage(logoBytes.buffer.asUint8List()),
      regularFont: pw.Font.ttf(regularFontBytes),
      boldFont: pw.Font.ttf(boldFontBytes),
    );
  }

  static String fileNameForInvoice(Invoice invoice) => _fileName(invoice);

  static String fileNameForPeriod(String period) => 'recibos_$period.pdf';

  static String detachablePeriodLabel(String period) {
    return 'PERÍODO FACTURADO: $period';
  }

  static String fileNameForSector(String period, String sector) {
    final normalized = sector.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    return 'recibos_${period}_$normalized.pdf';
  }

  static String _fileName(Invoice invoice) {
    return 'recibo_${invoice.periodo}_${invoice.codigoUsuario}_${invoice.codigoContador}.pdf';
  }
}

class _PdfAssets {
  const _PdfAssets({
    required this.logo,
    required this.regularFont,
    required this.boldFont,
  });

  final pw.MemoryImage logo;
  final pw.Font regularFont;
  final pw.Font boldFont;
}
