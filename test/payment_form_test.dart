import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/data/billing_account_functions_service.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/data/invoice_firestore_service.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/domain/invoice.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/presentation/widgets/invoice_payment_dialog.dart';
import 'package:frontacueductonewzenda/features/billing/payment_methods/data/payment_method_firestore_service.dart';
import 'package:frontacueductonewzenda/features/billing/payment_methods/domain/payment_method.dart';
import 'package:frontacueductonewzenda/features/billing/periods/data/billing_period_firestore_service.dart';
import 'package:frontacueductonewzenda/features/billing/periods/domain/billing_period.dart';
import 'package:frontacueductonewzenda/features/consumptions/presentation/pages/consumption_payments_page.dart';
import 'package:frontacueductonewzenda/features/users/domain/app_user.dart';

Invoice fixture() => Invoice.fromFirestore('10008', {
  'periodo': '2026-07',
  'codigoUsuario': '25A',
  'codigoContador': '10008',
  'nombreUsuario': 'Cliente de prueba',
  'total': 27300,
  'saldoAnterior': 116000,
  'valorPagado': 116000,
  'estado': 'en_mora',
  'pagado': false,
});

void main() {
  Future<void> size(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openForm(
    WidgetTester tester,
    ValueChanged<InvoicePaymentResult?> onResult,
  ) async {
    await size(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  onResult(
                    await showDialog<InvoicePaymentResult>(
                      context: context,
                      builder: (_) => InvoicePaymentDialog(
                        invoice: fixture(),
                        paymentMethods: const [],
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a partial payment opens a new abono without clearing old payments',
    (tester) async {
      InvoicePaymentResult? result;
      await openForm(tester, (value) => result = value);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Abonos acumulados: \$116.000'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un valor válido en pesos.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('payment-amount')),
        '1000',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(result?.mode, 'add');
      expect(result?.amount, 1000);
    },
  );

  testWidgets(
    'correcting the total requires a reason and submits the total, not an added abono',
    (tester) async {
      InvoicePaymentResult? result;
      await openForm(tester, (value) => result = value);
      await tester.tap(find.text('Nuevo abono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corregir total registrado').last);
      await tester.pumpAndSettle();
      expect(find.text('116000'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('payment-amount')),
        '126000',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Indica el motivo de la operación.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('payment-observations')),
        'Corrección del soporte',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(result?.mode, 'set');
      expect(result?.amount, 126000);
    },
  );

  testWidgets('an annulment is an explicit action with a required reason', (
    tester,
  ) async {
    InvoicePaymentResult? result;
    await openForm(tester, (value) => result = value);
    await tester.tap(find.text('Nuevo abono'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular abonos del recibo').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-amount')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('payment-observations')),
      'Abono asignado por error',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(result?.mode, 'reverse');
    expect(result?.amount, 0);
  });

  testWidgets(
    'duplicate warning can be confirmed and spinner stays until cascade finishes',
    (tester) async {
      await size(tester);
      final service = FakePaymentsService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConsumptionPaymentsPage(
              currentUser: AppUser.fromMap('admin', {
                'nombre': 'Administrador',
                'rol': 'administrador',
              }),
              invoiceService: service,
              periodService: FakePeriods(),
              paymentMethodService: FakeMethods(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar o corregir pago'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payment-amount')),
        '116000',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Revisar operación de pago'), findsOneWidget);
      expect(find.text('Ya existe un abono de este valor.'), findsOneWidget);
      await tester.tap(find.text('Confirmar y continuar'));
      await tester.pump();
      expect(
        find.text('Guardando el pago y actualizando los recibos posteriores…'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(service.lastRequest?['confirmWarnings'], true);
      service.completion.complete({
        'requiresConfirmation': false,
        'updatedInvoices': 2,
      });
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Operación guardada. Recibos actualizados: 2.'),
        findsOneWidget,
      );
    },
  );
}

class FakePaymentsService extends InvoiceFirestoreService {
  final completion = Completer<Map<String, dynamic>>();
  Map<String, dynamic>? lastRequest;

  @override
  Future<List<Invoice>> fetchInvoicesForPeriod(String period) async => [
    fixture(),
  ];

  @override
  String createPaymentRequestId() => 'test-payment-request';

  @override
  Future<PaymentPreview> previewPayment(Map<String, dynamic> request) async =>
      PaymentPreview(
        token: 'test-token',
        warnings: request['amount'] == 1
            ? []
            : ['Ya existe un abono de este valor.'],
        currentPaid: 116000,
        nextPaid: 232000,
        pending: 27300,
        affectedPeriods: ['2026-07', '2026-08'],
        priorBalance: 116000,
        currentStatus: 'en_mora',
        settled: false,
      );

  @override
  Future<Map<String, dynamic>> applyPayment(Map<String, dynamic> request) {
    lastRequest = request;
    return completion.future;
  }
}

class FakePeriods extends BillingPeriodFirestoreService {
  @override
  Future<List<BillingPeriod>> fetchOperationalPeriods() async => [
    BillingPeriod(
      id: '2026-07',
      ano: 2026,
      mes: 7,
      clave: '2026-07',
      nombre: 'Julio',
      vigente: true,
      fechaCreacion: DateTime(2026, 7),
    ),
  ];
}

class FakeMethods extends PaymentMethodFirestoreService {
  @override
  Future<List<PaymentMethod>> fetchItems({int limit = 200}) async => [];
}
