import 'package:flutter_test/flutter_test.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/domain/invoice.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/presentation/services/invoice_printing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Invoice balances', () {
    test('adds current total, previous balance, and reconnection', () {
      final invoice = _invoice(
        total: 42_000,
        saldoAnterior: 18_000,
        reconexion: 10_000,
      );

      expect(invoice.totalAPagar, 70_000);
      expect(invoice.saldoPendiente, 70_000);
    });

    test('never exposes a negative total when credit exceeds charges', () {
      final invoice = _invoice(total: 20_000, saldoAnterior: -30_000);

      expect(invoice.totalAPagar, 0);
      expect(invoice.saldoPendiente, 0);
    });

    test('subtracts partial payments from the outstanding balance', () {
      final invoice = _invoice(total: 50_000, valorPagado: 15_000);

      expect(invoice.saldoPendiente, 35_000);
    });

    test('a paid status always clears the outstanding balance', () {
      final invoice = _invoice(
        total: 50_000,
        valorPagado: 10_000,
        estado: 'pagado',
      );

      expect(invoice.estaPagado, isTrue);
      expect(invoice.saldoPendiente, 0);
    });

    test('accepts legacy numeric strings from Firestore', () {
      final invoice = Invoice.fromFirestore('invoice-id', {
        'periodo': '2026-07',
        'lecturaAnterior': '100',
        'lecturaActual': '112',
        'consumoM3': '12',
        'cargoFijo': '15000',
        'reconexion': '10000',
        'saldoAnterior': '5000',
        'valorConfigVersion': '2',
        'total': '39000',
        'valorPagado': '9000',
      });

      expect(invoice.lecturaAnterior, 100);
      expect(invoice.lecturaActual, 112);
      expect(invoice.consumoM3, 12);
      expect(invoice.totalAPagar, 54_000);
      expect(invoice.saldoPendiente, 45_000);
    });
  });

  test('detachable receipt label includes the billed period', () {
    expect(
      InvoicePrintingService.detachablePeriodLabel('2026-07'),
      'PERÍODO FACTURADO: 2026-07',
    );
  });

  test('builds the receipt PDF with the detachable period', () async {
    final bytes = await InvoicePrintingService().buildPdf(
      _invoice(total: 42_000, saldoAnterior: 8_000),
    );

    expect(bytes, isNotEmpty);
  });
}

Invoice _invoice({
  int total = 0,
  int saldoAnterior = 0,
  int reconexion = 0,
  int? valorPagado,
  String estado = 'facturado',
}) {
  return Invoice(
    id: 'invoice-id',
    periodo: '2026-07',
    codigoUsuario: '1001',
    codigoContador: 'M-1001',
    nombreUsuario: 'Cliente',
    sector: 'quitasol',
    lecturaAnterior: 100,
    lecturaActual: 110,
    consumoM3: 10,
    fechaGeneracion: DateTime(2026, 7, 1),
    fechaVencimiento: DateTime(2026, 7, 31),
    cargoFijo: 0,
    reconexion: reconexion,
    saldoAnterior: saldoAnterior,
    lineas: const [],
    mediosPagoTexto: '',
    mediosPago: const [],
    estado: estado,
    valorConfigId: 'config',
    valorConfigVersion: 1,
    total: total,
    pagado: false,
    valorPagado: valorPagado,
    actorUid: 'admin',
    actorNombre: 'Administrador',
    observaciones: const [],
  );
}
