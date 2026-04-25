import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/invoice.dart';

class InvoicePrintingService {
  Future<void> printInvoice(Invoice invoice) async {
    await Printing.layoutPdf(
      name: _fileName(invoice),
      onLayout: (format) => buildPdf(invoice, format: format),
    );
  }

  Future<void> printInvoices(
    List<Invoice> invoices, {
    required String fileName,
  }) async {
    if (invoices.isEmpty) {
      return;
    }
    await Printing.layoutPdf(
      name: fileName,
      onLayout: (format) => buildCombinedPdf(
        invoices,
        format: format,
        title: fileName,
      ),
    );
  }

  Future<void> shareInvoicesIndividually(List<Invoice> invoices) async {
    for (final invoice in invoices) {
      final bytes = await buildPdf(invoice);
      await Printing.sharePdf(bytes: bytes, filename: _fileName(invoice));
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
      subject: 'Recibos de pago ${invoices.isEmpty ? '' : invoices.first.periodo}',
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

  static String fileNameForSector(String period, String sector) {
    final normalized = sector
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_');
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

class _ReceiptPage extends pw.StatelessWidget {
  _ReceiptPage({
    required this.invoice,
    required this.logo,
    required this.regularFont,
    required this.boldFont,
  });

  final Invoice invoice;
  final pw.MemoryImage logo;
  final pw.Font regularFont;
  final pw.Font boldFont;

  pw.TextStyle get _labelStyle => pw.TextStyle(font: boldFont, fontSize: 7.8);
  pw.TextStyle get _valueStyle => pw.TextStyle(font: regularFont, fontSize: 9.8);

  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(),
        pw.SizedBox(height: 10),
        _identitySection(),
        pw.SizedBox(height: 10),
        _chargesTable(),
        pw.SizedBox(height: 10),
        _detailAndSummarySection(),
        pw.SizedBox(height: 6),
        _footSection(),
      ],
    );
  }

  pw.Widget _header() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.2),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 58,
                height: 58,
                alignment: pw.Alignment.center,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ASOCIACIÓN DE USUARIOS DEL ACUEDUCTO DE LAS VEREDAS DE QUITASOL Y JAZMÍN MUNICIPIO DE VIOTÁ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: boldFont, fontSize: 10.4),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'NIT 808.000.868-7',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: regularFont, fontSize: 9.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            color: PdfColors.grey300,
            child: pw.Text(
              'RECIBO DE PAGO',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: boldFont, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _identitySection() {
    return pw.Column(
      children: [
        _boxedTable(
          columnWidths: const {
            0: pw.FlexColumnWidth(2.8),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(1.6),
          },
          rows: [
            [
              _boxValue('USUARIO', invoice.nombreUsuario.toUpperCase()),
              _boxValue('CÓDIGO USUARIO', invoice.codigoUsuario),
              _boxValue('NÚMERO CONTADOR', invoice.codigoContador),
            ],
            [
              _boxValue('PERÍODO FACTURADO', invoice.periodo),
              _boxValue('GENERADO', _formatDate(invoice.fechaGeneracion)),
              _boxValue('VENCE', _formatDate(invoice.fechaVencimiento)),
            ],
          ],
        ),
        pw.SizedBox(height: 6),
        _boxedTable(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.1),
          },
          rows: [
            [
              _boxValue('LECTURA ANTERIOR', '${invoice.lecturaAnterior ?? 0}'),
              _boxValue('LECTURA SIGUIENTE', '${invoice.lecturaActual}'),
              _boxValue('CONSUMO', '${invoice.consumoM3} m³'),
              _statusBox(),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _chargesTable() {
    final rows = invoice.lineas
        .map(
          (item) => [
            item.descripcion,
            _formatCurrency(item.valorUnitario),
            '${item.cantidad}',
            _formatCurrency(item.valorTotal),
          ],
        )
        .toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableHeader('DESCRIPCIÓN'),
            _tableHeader('VALOR UNITARIO'),
            _tableHeader('CANT.'),
            _tableHeader('VALOR TOTAL'),
          ],
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: [
              _tableCell(row[0], align: pw.TextAlign.left),
              _tableCell(row[1]),
              _tableCell(row[2]),
              _tableCell(row[3]),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _detailAndSummarySection() {
    final serviceCharge = invoice.lineas.fold<int>(0, (sum, item) {
      return item.descripcion.toLowerCase().contains('cargo fijo')
          ? sum + item.valorTotal
          : sum;
    });
    final consumptionValue = invoice.lineas.fold<int>(0, (sum, item) {
      return item.descripcion.toLowerCase().contains('cargo fijo')
          ? sum
          : sum + item.valorTotal;
    });
    final totalToPay = invoice.total + invoice.saldoAnterior + invoice.reconexion;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _boxedListText('MEDIOS DE PAGO', _paymentMethodLines(), minHeight: 84),
              pw.SizedBox(height: 8),
              _boxedListText('OBSERVACIONES', _observationLines(), minHeight: 56),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Container(
          width: 220,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black),
          ),
          child: pw.Column(
            children: [
              _summaryRow('CARGO FIJO', _formatCurrency(serviceCharge)),
              _summaryRow('CONSUMO', _formatCurrency(consumptionValue)),
              _summaryRow('SALDO ANTERIOR', _formatCurrency(invoice.saldoAnterior)),
              _summaryRow('RECONEXIÓN', _formatCurrency(invoice.reconexion)),
              _summaryRow(
                'TOTAL A PAGAR',
                _formatCurrency(totalToPay),
                highlighted: true,
              ),
              _summaryRow(
                'VALOR PAGADO',
                invoice.pagado ? 'PAGADO' : '__________________',
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _footSection() {
    return pw.Column(
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: pw.Text(
                  'ESPACIO ACUEDUCTO',
                  style: pw.TextStyle(font: boldFont, fontSize: 9),
                ),
              ),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.black),
                  verticalInside: pw.BorderSide(color: PdfColors.black),
                  top: pw.BorderSide(color: PdfColors.black),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _footCell('USUARIO', invoice.nombreUsuario),
                      _footCell('VALOR FACTURADO', _formatCurrency(invoice.total)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _footCodeAndSectorCell(),
                      _footCell('VALOR PAGADO', '__________________'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: const pw.BorderSide(color: PdfColors.black),
              right: const pw.BorderSide(color: PdfColors.black),
              bottom: const pw.BorderSide(color: PdfColors.black),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'RECAUDADO POR:',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  height: 14,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _boxedTable({
    required List<List<pw.Widget>> rows,
    required Map<int, pw.TableColumnWidth> columnWidths,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black),
      columnWidths: columnWidths,
      children: rows
          .map(
            (row) => pw.TableRow(
              children: row
                  .map(
                    (cell) => pw.Container(
                      padding: const pw.EdgeInsets.all(0),
                      child: cell,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _boxValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: _labelStyle),
          pw.SizedBox(height: 4),
          pw.Text(value, style: _valueStyle),
        ],
      ),
    );
  }

  pw.Widget _statusBox() {
    final status = _statusPresentation(invoice.estadoPeriodoAnterior);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ESTADO', style: _labelStyle),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: status.color,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              status.label,
              style: pw.TextStyle(
                font: boldFont,
                color: PdfColors.white,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _boxedListText(
    String title,
    List<String> items, {
    double minHeight = 60,
  }) {
    return pw.Container(
      constraints: pw.BoxConstraints(minHeight: minHeight),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 9)),
          pw.SizedBox(height: 6),
          ...items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1, right: 6),
                    child: pw.Text('*', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      item,
                      style: pw.TextStyle(font: regularFont, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableHeader(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: boldFont, fontSize: 8),
      ),
    );
  }

  pw.Widget _tableCell(String value, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(font: regularFont, fontSize: 9),
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value, {bool highlighted = false}) {
    final style = pw.TextStyle(
      font: highlighted ? boldFont : regularFont,
      fontSize: highlighted ? 11 : 9,
    );
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: highlighted ? PdfColors.grey300 : null,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _footCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: _labelStyle),
          pw.SizedBox(height: 4),
          pw.Text(value, style: _valueStyle),
        ],
      ),
    );
  }

  pw.Widget _footCodeAndSectorCell() {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CÓDIGO DE USUARIO', style: _labelStyle),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.codigoUsuario, style: _valueStyle),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('SECTOR', style: _labelStyle, textAlign: pw.TextAlign.right),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _displaySector(invoice.sector),
                      style: _valueStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _paymentMethodLines() {
    final snapshotLines = invoice.mediosPago
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (snapshotLines.isNotEmpty) {
      return snapshotLines;
    }
    final fallback = invoice.mediosPagoTexto
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return fallback.isEmpty
        ? const ['No se registraron medios de pago.']
        : fallback;
  }

  List<String> _observationLines() {
    final snapshotLines = [
      if ((invoice.avisoFacturacion ?? '').trim().isNotEmpty)
        invoice.avisoFacturacion!.trim(),
      ...invoice.observaciones
          .map((item) => item.descripcion.trim())
          .where((item) => item.isNotEmpty),
    ];
    if (snapshotLines.isNotEmpty) {
      return snapshotLines;
    }
    final fallback = invoice.mensaje?.trim();
    return [
      if (fallback != null && fallback.isNotEmpty) fallback,
      if (fallback == null || fallback.isEmpty)
        'Sin observaciones registradas para este recibo.',
    ];
  }

  _StatusPresentation _statusPresentation(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'suspendido':
        return const _StatusPresentation('Suspendido', PdfColors.red800);
      case 'en_mora':
        return const _StatusPresentation('En mora', PdfColors.orange800);
      default:
        return const _StatusPresentation('Al día', PdfColors.green700);
    }
  }

  String _displaySector(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'na') {
      return 'No registrado';
    }
    final words = normalized
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    return words
        .map((item) => item[0].toUpperCase() + item.substring(1).toLowerCase())
        .join(' ');
  }
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.color);

  final String label;
  final PdfColor color;
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatCurrency(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final reverseIndex = digits.length - index;
    buffer.write(digits[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$${buffer.toString()}';
}
