import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../consumptions/domain/consumption_reading.dart';
import '../../../accounts/data/account_movement_firestore_service.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/domain/app_user.dart';
import '../../observations/data/billing_observation_firestore_service.dart';
import '../../observations/domain/billing_observation.dart';
import '../../payment_methods/domain/payment_method.dart';
import '../../periods/domain/billing_period.dart';
import '../../values/domain/billing_value_config.dart';
import '../domain/invoice.dart';

class RegenerateInvoicesResult {
  const RegenerateInvoicesResult({
    required this.regeneratedCount,
    required this.skippedPaidCount,
  });

  final int regeneratedCount;
  final int skippedPaidCount;
}

class InvoiceFirestoreService {
  static const String _accountingStartPeriodId = '2026-01';

  InvoiceFirestoreService({
    FirebaseFirestore? firestore,
    BillingObservationFirestoreService? observationService,
    AccountMovementFirestoreService? accountMovementService,
    UserFirestoreService? userService,
  }) : _firestore = firestore,
       _observationService =
           observationService ??
           BillingObservationFirestoreService(firestore: firestore),
       _accountMovementService =
           accountMovementService ??
           AccountMovementFirestoreService(firestore: firestore),
       _userService = userService ?? UserFirestoreService(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final BillingObservationFirestoreService _observationService;
  final AccountMovementFirestoreService _accountMovementService;
  final UserFirestoreService _userService;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _periodConsumptions(
    String period,
  ) => _db.collection('periodos').doc(period).collection('consumos');

  CollectionReference<Map<String, dynamic>> _periodInvoices(String period) =>
      _db.collection('periodos').doc(period).collection('recibos');

  Future<List<Invoice>> fetchInvoicesForPeriod(String period) async {
    if (!_isAccountingPeriodId(period)) {
      return const [];
    }
    final snapshot = await _periodInvoices(period).get();
    final items =
        snapshot.docs
            .map((doc) => Invoice.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            final userCompare = a.codigoUsuario.compareTo(b.codigoUsuario);
            if (userCompare != 0) {
              return userCompare;
            }
            return a.codigoContador.compareTo(b.codigoContador);
          });
    return items;
  }

  Future<Invoice?> fetchLatestPayableInvoiceForClient(
    String customerCode,
  ) async {
    final snapshot = await _db
        .collectionGroup('recibos')
        .where('codigoUsuario', isEqualTo: customerCode)
        .where('pagado', isEqualTo: false)
        .get();
    final items =
        snapshot.docs
            .map((doc) => Invoice.fromFirestore(doc.id, doc.data()))
            .where((item) => _isAccountingPeriodId(item.periodo))
            .toList()
          ..sort((a, b) {
            final periodCompare = b.periodo.compareTo(a.periodo);
            if (periodCompare != 0) {
              return periodCompare;
            }
            return b.fechaGeneracion.compareTo(a.fechaGeneracion);
          });
    return items.isEmpty ? null : items.first;
  }

  Future<Invoice?> fetchLatestPayableInvoiceForClientCodes(
    Iterable<String> customerCodes,
  ) async {
    final invoices = await fetchLatestPayableInvoicesForClientCodes(
      customerCodes,
    );
    return invoices.isEmpty ? null : invoices.first;
  }

  Future<List<Invoice>> fetchLatestPayableInvoicesForClientCodes(
    Iterable<String> customerCodes,
  ) async {
    final codes = customerCodes
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty && item != 'NA')
        .toSet()
        .toList();
    if (codes.isEmpty) {
      return const [];
    }
    final invoices = <Invoice>[];
    for (final code in codes) {
      final invoice = await fetchLatestPayableInvoiceForClient(code);
      if (invoice != null) {
        invoices.add(invoice);
      }
    }
    invoices.sort((a, b) {
      final periodCompare = b.periodo.compareTo(a.periodo);
      if (periodCompare != 0) {
        return periodCompare;
      }
      return b.fechaGeneracion.compareTo(a.fechaGeneracion);
    });
    return invoices;
  }

  Future<List<Invoice>> fetchPendingInvoicesReport({
    String? period,
    String? customerCode,
  }) async {
    final normalizedPeriod = period?.trim();
    final normalizedCustomer = customerCode?.trim();

    if (normalizedPeriod != null && normalizedPeriod.isNotEmpty) {
      final items = await fetchInvoicesForPeriod(normalizedPeriod);
      return items
          .where((item) => !item.pagado)
          .where(
            (item) => normalizedCustomer == null || normalizedCustomer.isEmpty
                ? true
                : item.codigoUsuario == normalizedCustomer,
          )
          .toList();
    }

    var query = _db
        .collectionGroup('recibos')
        .where('pagado', isEqualTo: false);
    if (normalizedCustomer != null && normalizedCustomer.isNotEmpty) {
      query = query.where('codigoUsuario', isEqualTo: normalizedCustomer);
    }
    final snapshot = await query.get();
    final items =
        snapshot.docs
            .map((doc) => Invoice.fromFirestore(doc.id, doc.data()))
            .where((item) => _isAccountingPeriodId(item.periodo))
            .toList()
          ..sort((a, b) {
            final periodCompare = a.periodo.compareTo(b.periodo);
            if (periodCompare != 0) {
              return periodCompare;
            }
            return a.codigoUsuario.compareTo(b.codigoUsuario);
          });
    return items;
  }

  Future<void> generateInvoicesForReadings({
    required BillingPeriod period,
    required List<ConsumptionReading> readings,
    required BillingValueConfig values,
    required List<PaymentMethod> paymentMethods,
    required AppUser actor,
  }) async {
    if (readings.isEmpty) {
      return;
    }
    _ensureAccountingPeriod(period.id);

    final now = DateTime.now();
    final dueDate = _resolveDueDate(now);
    final paymentLines = paymentMethods
        .map((item) => item.descripcion.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final paymentText = paymentLines.join('\n');
    final previousInvoicesByMeter = await _fetchPreviousInvoiceHistoryByMeter(
      period,
    );
    final observations = await _observationService.fetchItems();
    final usersByCode = await _fetchUsersByCode();
    final accountBalancesByMeter = await _accountMovementService
        .fetchMeterBalancesBeforePeriod(
          periodId: period.id,
          meterCodes: readings.map((item) => item.codigoContador),
        );

    final batch = _db.batch();
    for (final reading in readings) {
      final previousInvoices =
          previousInvoicesByMeter[reading.codigoContador] ?? const <Invoice>[];
      final invoice = _buildInvoice(
        period: period,
        reading: reading,
        values: values,
        paymentText: paymentText,
        paymentLines: paymentLines,
        generatedAt: now,
        dueDate: dueDate,
        previousInvoices: previousInvoices,
        accountBalance: accountBalancesByMeter[reading.codigoContador.trim()],
        sector:
            usersByCode[_normalizeUserCode(reading.codigoUsuario)]?.sector ??
            '',
        appliedObservations: _resolveAppliedObservations(
          observations,
          periodId: period.id,
          reading: reading,
        ),
        actor: actor,
      );
      batch.set(
        _periodInvoices(period.id).doc(invoice.id),
        invoice.toFirestore(),
        SetOptions(merge: true),
      );
      _accountMovementService.setInvoiceCharge(
        batch: batch,
        invoice: invoice,
        actor: actor,
        createdAt: now,
      );
      batch.set(
        _periodConsumptions(period.id).doc(reading.codigoContador),
        reading
            .copyWith(
              facturado: true,
              pagado: false,
              reciboId: invoice.id,
              estado: invoice.estado,
            )
            .toFirestore(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> updatePaymentStatus({
    required Invoice invoice,
    required bool paid,
    required AppUser actor,
    int? paidAmount,
    PaymentMethod? paymentMethod,
    String? observations,
  }) async {
    _ensureAccountingPeriod(invoice.periodo);
    final previousPaidAmount = invoice.valorPagado ?? 0;
    final newPaidAmount = paid ? (paidAmount ?? invoice.totalAPagar) : 0;
    final newStatus = _resolvePaymentStatus(
      invoice: invoice,
      paidAmount: newPaidAmount,
    );
    final paidAt = DateTime.now();
    final updated = invoice.copyWith(
      estado: newStatus,
      pagado: newPaidAmount >= invoice.totalAPagar && invoice.totalAPagar > 0,
      valorPagado: newPaidAmount,
      fechaPago: newPaidAmount > 0 ? paidAt : null,
      medioPagoId: paid ? paymentMethod?.id : null,
      medioPagoDescripcion: paid ? paymentMethod?.descripcion : null,
      observacionesPago: paid && (observations?.trim().isNotEmpty ?? false)
          ? observations!.trim()
          : null,
    );

    final batch = _db.batch();
    _accountMovementService.setInvoiceCharge(
      batch: batch,
      invoice: invoice,
      actor: actor,
    );
    _accountMovementService.addPaymentDelta(
      batch: batch,
      invoice: invoice,
      deltaPaidAmount: newPaidAmount - previousPaidAmount,
      actor: actor,
      paymentMethod: paymentMethod,
      observations: observations,
      paidAt: paidAt,
    );
    batch.set(
      _periodInvoices(invoice.periodo).doc(invoice.id),
      updated.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      _periodConsumptions(invoice.periodo).doc(invoice.codigoContador),
      {
        'pagado': updated.pagado,
        'estado': newStatus,
        'reciboId': invoice.id,
        'valorPagado': newPaidAmount,
        'fechaPago': updated.fechaPago == null
            ? null
            : Timestamp.fromDate(updated.fechaPago!),
        'medioPagoId': paid ? paymentMethod?.id : null,
        'medioPagoDescripcion': paid ? paymentMethod?.descripcion : null,
        'observacionesPago': paid && (observations?.trim().isNotEmpty ?? false)
            ? observations!.trim()
            : null,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> suspendInvoice({
    required Invoice invoice,
    required AppUser actor,
    String? observations,
  }) async {
    _ensureAccountingPeriod(invoice.periodo);
    if (invoice.estaSuspendido) {
      return;
    }

    final updated = invoice.copyWith(estado: 'suspendido');
    final batch = _db.batch();
    batch.set(
      _periodInvoices(invoice.periodo).doc(invoice.id),
      updated.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      _periodConsumptions(invoice.periodo).doc(invoice.codigoContador),
      {
        'estado': 'suspendido',
        'reciboId': invoice.id,
        'pagado': invoice.pagado,
        'facturado': true,
        'detalleEstado': 'Suspendido por ${actor.nombre}',
        if ((observations?.trim().isNotEmpty ?? false))
          'observacionesAdmin': observations!.trim(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> restoreSuspendedInvoice({
    required Invoice invoice,
    required AppUser actor,
  }) async {
    _ensureAccountingPeriod(invoice.periodo);
    if (!invoice.estaSuspendido) {
      return;
    }

    final restoredStatus = invoice.pagado ? 'pagado' : 'facturado';
    final updated = invoice.copyWith(estado: restoredStatus);
    final batch = _db.batch();
    batch.set(
      _periodInvoices(invoice.periodo).doc(invoice.id),
      updated.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      _periodConsumptions(invoice.periodo).doc(invoice.codigoContador),
      {
        'estado': restoredStatus,
        'reciboId': invoice.id,
        'pagado': invoice.pagado,
        'facturado': true,
        'detalleEstado': 'Suspension levantada por ${actor.nombre}',
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<RegenerateInvoicesResult> regenerateInvoicesForPeriod({
    required BillingPeriod period,
    required BillingValueConfig values,
    required List<PaymentMethod> paymentMethods,
    required AppUser actor,
  }) async {
    _ensureAccountingPeriod(period.id);
    final existingInvoices = await fetchInvoicesForPeriod(period.id);
    if (existingInvoices.isEmpty) {
      return const RegenerateInvoicesResult(
        regeneratedCount: 0,
        skippedPaidCount: 0,
      );
    }

    final readings = await _periodConsumptions(period.id).get();
    final readingsByMeter = {
      for (final doc in readings.docs)
        doc.id: ConsumptionReading.fromFirestore(doc.id, doc.data()),
    };

    final now = DateTime.now();
    final dueDate = _resolveDueDate(now);
    final paymentLines = paymentMethods
        .map((item) => item.descripcion.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final paymentText = paymentLines.join('\n');
    final previousInvoicesByMeter = await _fetchPreviousInvoiceHistoryByMeter(
      period,
    );
    final observations = await _observationService.fetchItems();
    final usersByCode = await _fetchUsersByCode();
    final accountBalancesByMeter = await _accountMovementService
        .fetchMeterBalancesBeforePeriod(
          periodId: period.id,
          meterCodes: readingsByMeter.values.map((item) => item.codigoContador),
        );

    var regeneratedCount = 0;
    var skippedPaidCount = 0;
    final batch = _db.batch();

    for (final existing in existingInvoices) {
      if (existing.pagado || existing.estado.trim().toLowerCase() == 'pagado') {
        skippedPaidCount++;
        continue;
      }
      final reading = readingsByMeter[existing.codigoContador];
      if (reading == null) {
        continue;
      }
      final previousInvoices =
          previousInvoicesByMeter[reading.codigoContador] ?? const <Invoice>[];
      final invoice = _buildInvoice(
        period: period,
        reading: reading,
        values: values,
        paymentText: paymentText,
        paymentLines: paymentLines,
        generatedAt: now,
        dueDate: dueDate,
        previousInvoices: previousInvoices,
        accountBalance: accountBalancesByMeter[reading.codigoContador.trim()],
        sector:
            usersByCode[_normalizeUserCode(reading.codigoUsuario)]?.sector ??
            '',
        appliedObservations: _resolveAppliedObservations(
          observations,
          periodId: period.id,
          reading: reading,
        ),
        actor: actor,
        existingInvoice: existing,
      );
      batch.set(
        _periodInvoices(period.id).doc(invoice.id),
        invoice.toFirestore(),
        SetOptions(merge: true),
      );
      _accountMovementService.setInvoiceCharge(
        batch: batch,
        invoice: invoice,
        actor: actor,
        createdAt: now,
      );
      batch.set(
        _periodConsumptions(period.id).doc(reading.codigoContador),
        {
          'estado': invoice.estado,
          'reciboId': invoice.id,
          'pagado': invoice.pagado,
          'facturado': true,
        },
        SetOptions(merge: true),
      );
      regeneratedCount++;
    }

    if (regeneratedCount > 0) {
      await batch.commit();
    }

    return RegenerateInvoicesResult(
      regeneratedCount: regeneratedCount,
      skippedPaidCount: skippedPaidCount,
    );
  }

  Future<void> regenerateInvoice({
    required BillingPeriod period,
    required Invoice existing,
    required BillingValueConfig values,
    required List<PaymentMethod> paymentMethods,
    required AppUser actor,
  }) async {
    _ensureAccountingPeriod(period.id);
    if (existing.pagado || existing.estado.trim().toLowerCase() == 'pagado') {
      throw StateError('No se puede regenerar un recibo pagado.');
    }

    final readingSnapshot = await _periodConsumptions(
      period.id,
    ).doc(existing.codigoContador).get();
    if (!readingSnapshot.exists || readingSnapshot.data() == null) {
      throw StateError('No se encontro la lectura asociada al recibo.');
    }

    final reading = ConsumptionReading.fromFirestore(
      readingSnapshot.id,
      readingSnapshot.data()!,
    );
    final now = DateTime.now();
    final dueDate = _resolveDueDate(now);
    final paymentLines = paymentMethods
        .map((item) => item.descripcion.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final observations = await _observationService.fetchItems();
    final usersByCode = await _fetchUsersByCode();
    final previousInvoicesByMeter = await _fetchPreviousInvoiceHistoryByMeter(
      period,
    );
    final accountBalancesByMeter = await _accountMovementService
        .fetchMeterBalancesBeforePeriod(
          periodId: period.id,
          meterCodes: [reading.codigoContador],
        );
    final previousInvoices =
        previousInvoicesByMeter[reading.codigoContador] ?? const <Invoice>[];
    final invoice = _buildInvoice(
      period: period,
      reading: reading,
      values: values,
      paymentText: paymentLines.join('\n'),
      paymentLines: paymentLines,
      generatedAt: now,
      dueDate: dueDate,
      previousInvoices: previousInvoices,
      accountBalance: accountBalancesByMeter[reading.codigoContador.trim()],
      sector:
          usersByCode[_normalizeUserCode(reading.codigoUsuario)]?.sector ?? '',
      appliedObservations: _resolveAppliedObservations(
        observations,
        periodId: period.id,
        reading: reading,
      ),
      actor: actor,
      existingInvoice: existing,
    );

    final batch = _db.batch();
    batch.set(
      _periodInvoices(period.id).doc(invoice.id),
      invoice.toFirestore(),
      SetOptions(merge: true),
    );
    _accountMovementService.setInvoiceCharge(
      batch: batch,
      invoice: invoice,
      actor: actor,
      createdAt: now,
    );
    batch.set(
      _periodConsumptions(period.id).doc(invoice.codigoContador),
      {
        'estado': invoice.estado,
        'reciboId': invoice.id,
        'pagado': invoice.pagado,
        'facturado': true,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Invoice _buildInvoice({
    required BillingPeriod period,
    required ConsumptionReading reading,
    required BillingValueConfig values,
    required String paymentText,
    required List<String> paymentLines,
    required DateTime generatedAt,
    required DateTime dueDate,
    required List<Invoice> previousInvoices,
    required int? accountBalance,
    required String sector,
    required List<InvoiceAppliedObservation> appliedObservations,
    required AppUser actor,
    Invoice? existingInvoice,
  }) {
    final previousInvoice = previousInvoices.isEmpty
        ? null
        : previousInvoices.first;
    final previousReading = reading.lecturaAnterior ?? 0;
    final consumption =
        reading.consumoCalculado ??
        (reading.lecturaActual - previousReading).clamp(0, 1 << 31).toInt();
    final lineItems = <InvoiceLineItem>[
      InvoiceLineItem(
        descripcion: 'Cargo fijo',
        valorUnitario: values.cargoFijo,
        cantidad: 1,
        valorTotal: values.cargoFijo,
      ),
      ..._buildConsumptionLines(consumption, values.rangos),
      ..._buildAdditionalValueLines(
        period.id,
        reading.codigoUsuario,
        values.valoresAdicionales,
      ),
    ];
    final subtotal = lineItems.fold<int>(
      0,
      (previous, item) => previous + item.valorTotal,
    );
    final avisoFacturacion = _buildBillingChangeNotice(
      existingInvoice: existingInvoice,
      values: values,
      lineItems: lineItems,
      total: subtotal,
    );
    final previousBalance = _resolvePreviousBalance(
      previousInvoice: previousInvoice,
      accountBalance: accountBalance,
    );
    final isCoveredByCredit = subtotal + previousBalance <= 0;

    return Invoice(
      id: reading.codigoContador,
      periodo: period.id,
      codigoUsuario: reading.codigoUsuario,
      codigoContador: reading.codigoContador,
      nombreUsuario: reading.nombreUsuario,
      sector: sector,
      lecturaAnterior: previousReading,
      lecturaActual: reading.lecturaActual,
      consumoM3: consumption,
      fechaGeneracion: generatedAt,
      fechaVencimiento: dueDate,
      cargoFijo: values.cargoFijo,
      reconexion: 0,
      saldoAnterior: previousBalance,
      lineas: lineItems,
      mediosPagoTexto: paymentText,
      mediosPago: paymentLines,
      estado: isCoveredByCredit
          ? 'pagado'
          : _resolveCurrentInvoiceStatus(previousInvoices, existingInvoice),
      valorConfigId: values.id,
      valorConfigVersion: values.version,
      total: subtotal,
      pagado: isCoveredByCredit,
      valorPagado: 0,
      actorUid: actor.uid,
      actorNombre: actor.nombre,
      observaciones: appliedObservations,
      estadoPeriodoAnterior: _resolvePreviousPeriodStatus(previousInvoice),
      avisoFacturacion: avisoFacturacion,
      mensaje:
          'Estimado usuario, si realiza su pago por consignacion bancaria favor enviar el soporte indicando el codigo de usuario.',
    );
  }

  Future<Map<String, List<Invoice>>> _fetchPreviousInvoiceHistoryByMeter(
    BillingPeriod period,
  ) async {
    final previousPeriodIds = await _fetchPreviousBillablePeriodIds(period.id);
    if (previousPeriodIds.isEmpty) {
      return const {};
    }
    final result = <String, List<Invoice>>{};
    for (final previousPeriodId in previousPeriodIds) {
      final items = await fetchInvoicesForPeriod(previousPeriodId);
      for (final item in items) {
        result.putIfAbsent(item.codigoContador, () => <Invoice>[]).add(item);
      }
    }
    for (final invoices in result.values) {
      invoices.sort((a, b) => b.periodo.compareTo(a.periodo));
    }
    return result;
  }

  Future<Map<String, AppUser>> _fetchUsersByCode() async {
    final users = await _userService.fetchUsers(limit: 5000);
    return {
      for (final user in users)
        for (final code in user.codigosUsuario)
          if (_normalizeUserCode(code.codigoUsuario).isNotEmpty)
            _normalizeUserCode(code.codigoUsuario): user.copyWith(
              sector: code.sector,
            ),
    };
  }

  String _normalizeUserCode(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'NA') {
      return '';
    }
    return normalized;
  }

  List<InvoiceAppliedObservation> _resolveAppliedObservations(
    List<BillingObservation> observations, {
    required String periodId,
    required ConsumptionReading reading,
  }) {
    return observations
        .where(
          (item) => item.appliesTo(
            periodo: periodId,
            codigoUsuario: reading.codigoUsuario,
          ),
        )
        .map(
          (item) => InvoiceAppliedObservation(
            id: item.id,
            descripcion: item.descripcion,
            tipo: item.tipo,
            periodo: item.periodo,
            codigoUsuario: item.codigoUsuario,
            nombreUsuario: item.nombreUsuario,
            siempre: item.siempre,
          ),
        )
        .toList();
  }

  DateTime _resolveDueDate(DateTime generatedAt) {
    if (generatedAt.day > 20) {
      return generatedAt.add(const Duration(days: 15));
    }
    return DateTime(generatedAt.year, generatedAt.month, 24);
  }

  String _resolvePreviousPeriodStatus(Invoice? previousInvoice) {
    if (previousInvoice == null ||
        !_isAccountingPeriodId(previousInvoice.periodo)) {
      return 'al_dia';
    }
    final normalized = previousInvoice.estado.trim().toLowerCase();
    if (normalized == 'suspendido') {
      return 'suspendido';
    }
    if (previousInvoice.saldoPendiente <= 0 ||
        normalized == 'pagado' ||
        previousInvoice.estaPagado) {
      return 'al_dia';
    }
    return 'en_mora';
  }

  String _resolveCurrentInvoiceStatus(
    List<Invoice> previousInvoices,
    Invoice? existingInvoice,
  ) {
    if (existingInvoice?.estaSuspendido == true) {
      return 'suspendido';
    }
    if (_shouldAutoSuspend(previousInvoices)) {
      return 'suspendido';
    }
    return 'facturado';
  }

  bool _shouldAutoSuspend(List<Invoice> previousInvoices) {
    if (previousInvoices.isEmpty) {
      return false;
    }
    if (previousInvoices.first.estaSuspendido) {
      return true;
    }
    var consecutiveDebtPeriods = 0;
    for (final invoice in previousInvoices) {
      if (_isDebtInvoice(invoice)) {
        consecutiveDebtPeriods++;
        if (consecutiveDebtPeriods >= 2) {
          return true;
        }
        continue;
      }
      break;
    }
    return false;
  }

  bool _isDebtInvoice(Invoice invoice) {
    if (!_isAccountingPeriodId(invoice.periodo)) {
      return false;
    }
    if (invoice.estaPagado || invoice.saldoPendiente <= 0) {
      return false;
    }
    return true;
  }

  int _resolvePreviousBalance({
    required Invoice? previousInvoice,
    required int? accountBalance,
  }) {
    if (accountBalance != null && accountBalance != 0) {
      return accountBalance;
    }
    if (previousInvoice == null ||
        !_isAccountingPeriodId(previousInvoice.periodo)) {
      return 0;
    }
    return previousInvoice.saldoPendiente;
  }

  String _resolvePaymentStatus({
    required Invoice invoice,
    required int paidAmount,
  }) {
    if (paidAmount >= invoice.totalAPagar && invoice.totalAPagar > 0) {
      return 'pagado';
    }
    if (invoice.estaSuspendido) {
      return 'suspendido';
    }
    if (paidAmount > 0) {
      return 'en_mora';
    }
    return 'facturado';
  }

  Future<List<String>> _fetchPreviousBillablePeriodIds(
    String currentPeriodId,
  ) async {
    final snapshot = await _db.collection('periodos').get();
    final ids =
        snapshot.docs
            .map((doc) => doc.id)
            .where(
              (periodId) =>
                  _isAccountingPeriodId(periodId) &&
                  periodId.compareTo(currentPeriodId) < 0,
            )
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return ids;
  }

  bool _isAccountingPeriodId(String periodId) {
    return periodId.trim().compareTo(_accountingStartPeriodId) >= 0;
  }

  void _ensureAccountingPeriod(String periodId) {
    if (!_isAccountingPeriodId(periodId)) {
      throw StateError(
        'El periodo $periodId no es contable. La facturacion inicia en 2026-01.',
      );
    }
  }

  String? _buildBillingChangeNotice({
    required Invoice? existingInvoice,
    required BillingValueConfig values,
    required List<InvoiceLineItem> lineItems,
    required int total,
  }) {
    if (existingInvoice == null) {
      return null;
    }
    final changed = _hasBillingValuesChanged(
      existingInvoice: existingInvoice,
      values: values,
      lineItems: lineItems,
      total: total,
    );
    if (!changed) {
      return null;
    }
    return 'Recibo regenerado con valores de facturación actualizados. Versión vigente: ${values.version}.';
  }

  bool _hasBillingValuesChanged({
    required Invoice existingInvoice,
    required BillingValueConfig values,
    required List<InvoiceLineItem> lineItems,
    required int total,
  }) {
    if (existingInvoice.valorConfigId.isNotEmpty &&
        existingInvoice.valorConfigId != values.id) {
      return true;
    }
    if (existingInvoice.valorConfigVersion != 0 &&
        existingInvoice.valorConfigVersion != values.version) {
      return true;
    }
    if (existingInvoice.cargoFijo != values.cargoFijo) {
      return true;
    }
    if (existingInvoice.total != total) {
      return true;
    }
    if (existingInvoice.lineas.length != lineItems.length) {
      return true;
    }
    for (var index = 0; index < lineItems.length; index++) {
      final a = existingInvoice.lineas[index];
      final b = lineItems[index];
      if (a.descripcion != b.descripcion ||
          a.valorUnitario != b.valorUnitario ||
          a.cantidad != b.cantidad ||
          a.valorTotal != b.valorTotal) {
        return true;
      }
    }
    return false;
  }

  List<InvoiceLineItem> _buildConsumptionLines(
    int consumption,
    List<ConsumptionRange> ranges,
  ) {
    if (consumption <= 0 || ranges.isEmpty) {
      return const [];
    }

    final sorted = [...ranges]..sort((a, b) => a.desde.compareTo(b.desde));
    final items = <InvoiceLineItem>[];
    for (final range in sorted) {
      final start = range.desde;
      final end = range.hasta;
      if (consumption < start) {
        continue;
      }

      final cappedConsumption = end == null || consumption < end
          ? consumption
          : end;
      final units = start == 0
          ? cappedConsumption
          : cappedConsumption - start + 1;
      if (units <= 0) {
        continue;
      }

      final description = end == null
          ? 'Consumo superior a ${start - 1} m3'
          : start == 0
          ? 'Consumo hasta $end m3'
          : 'Consumo entre $start y $end m3';
      items.add(
        InvoiceLineItem(
          descripcion: description,
          valorUnitario: range.valorUnitario,
          cantidad: units,
          valorTotal: units * range.valorUnitario,
        ),
      );
    }
    return items;
  }

  List<InvoiceLineItem> _buildAdditionalValueLines(
    String periodId,
    String codigoUsuario,
    List<AdditionalBillingValue> values,
  ) {
    return values
        .where(
          (item) =>
              item.concepto.trim().isNotEmpty &&
              item.valor > 0 &&
              item.appliesTo(periodId: periodId, userCode: codigoUsuario),
        )
        .map(
          (item) => InvoiceLineItem(
            descripcion: 'Valor adicional - ${item.concepto.trim()}',
            valorUnitario: item.valor,
            cantidad: 1,
            valorTotal: item.valor,
          ),
        )
        .toList();
  }
}
