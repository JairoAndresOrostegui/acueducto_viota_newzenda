import 'package:flutter/material.dart';

import '../../../../../core/presentation/text_formatters.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../users/domain/app_user.dart';
import '../../data/invoice_firestore_service.dart';
import '../../domain/invoice.dart';
import '../services/invoice_printing_service.dart';

class ClientInvoicePage extends StatefulWidget {
  const ClientInvoicePage({
    super.key,
    required this.currentUser,
    this.invoiceService,
  });

  final AppUser currentUser;
  final InvoiceFirestoreService? invoiceService;

  @override
  State<ClientInvoicePage> createState() => _ClientInvoicePageState();
}

class _ClientInvoicePageState extends State<ClientInvoicePage> {
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();
  late final InvoicePrintingService _printingService = InvoicePrintingService();

  bool _loading = true;
  String? _error;
  Invoice? _invoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoice = await _invoiceService.fetchLatestPayableInvoiceForClient(
        widget.currentUser.codigoUsuario,
      );
      setState(() => _invoice = invoice);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _printInvoice() async {
    final invoice = _invoice;
    if (invoice == null) {
      return;
    }
    try {
      await _printingService.printInvoice(invoice);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible generar el PDF: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('No fue posible cargar tu recibo: $_error'));
    }

    final invoice = _invoice;
    if (invoice == null) {
      return _EmptyClientInvoice(currentUser: widget.currentUser);
    }

    return SingleChildScrollView(
      child: _ClientInvoiceCard(
        invoice: invoice,
        onPrint: _printInvoice,
      ),
    );
  }
}

class _EmptyClientInvoice extends StatelessWidget {
  const _EmptyClientInvoice({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hola, ${toDisplayUserName(currentUser.nombre)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'No tienes recibos pendientes de pago en este momento.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientInvoiceCard extends StatelessWidget {
  const _ClientInvoiceCard({
    required this.invoice,
    required this.onPrint,
  });

  final Invoice invoice;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recibo pendiente de pago',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ASOCIACIÓN DE USUARIOS DEL ACUEDUCTO DE LAS VEREDAS DE QUITASOL Y JAZMÍN · NIT 808.000.868-7',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _LabelValue(label: 'Usuario', value: toDisplayUserName(invoice.nombreUsuario)),
              _LabelValue(label: 'Código usuario', value: invoice.codigoUsuario),
              _LabelValue(label: 'Contador', value: invoice.codigoContador),
              _LabelValue(label: 'Período', value: invoice.periodo),
              _LabelValue(label: 'Generado', value: _formatDate(invoice.fechaGeneracion)),
              _LabelValue(label: 'Vence', value: _formatDate(invoice.fechaVencimiento)),
              _LabelValue(label: 'Lectura anterior', value: '${invoice.lecturaAnterior ?? 0}'),
              _LabelValue(label: 'Lectura actual', value: '${invoice.lecturaActual}'),
              _LabelValue(label: 'Consumo m³', value: '${invoice.consumoM3}'),
            ],
          ),
          const SizedBox(height: 18),
          ...invoice.lineas.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(item.descripcion)),
                  Text('${item.cantidad} x ${_formatCurrency(item.valorUnitario)}'),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 100,
                    child: Text(
                      _formatCurrency(item.valorTotal),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 28),
          if (invoice.mediosPagoTexto.isNotEmpty) ...[
            Text('Medios de pago', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(invoice.mediosPagoTexto),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(child: Text(invoice.mensaje ?? '')),
              const SizedBox(width: 16),
              Text(
                'Total: ${_formatCurrency(invoice.total)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 220, child: Text('$label: $value'));
  }
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
