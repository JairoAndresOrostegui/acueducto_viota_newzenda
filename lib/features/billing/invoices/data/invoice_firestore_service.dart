import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../consumptions/domain/consumption_reading.dart';
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
  InvoiceFirestoreService({
    FirebaseFirestore? firestore,
    BillingObservationFirestoreService? observationService,
    UserFirestoreService? userService,
  }) : _firestore = firestore,
       _observationService =
           observationService ??
           BillingObservationFirestoreService(firestore: firestore),
       _userService = userService ?? UserFirestoreService(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final BillingObservationFirestoreService _observationService;
  final UserFirestoreService _userService;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _periodConsumptions(String period) =>
      _db.collection('periodos').doc(period).collection('consumos');

  CollectionReference<Map<String, dynamic>> _periodInvoices(String period) =>
      _db.collection('periodos').doc(period).collection('recibos');

  Future<List<Invoice>> fetchInvoicesForPeriod(String period) async {
    final snapshot = await _periodInvoices(period).get();
    final items = snapshot.docs
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

  Future<Invoice?> fetchLatestPayableInvoiceForClient(String customerCode) async {
    final snapshot = await _db
        .collectionGroup('recibos')
        .where('codigoUsuario', isEqualTo: customerCode)
        .where('pagado', isEqualTo: false)
        .get();
    final items = snapshot.docs
        .map((doc) => Invoice.fromFirestore(doc.id, doc.data()))
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
    final items = snapshot.docs
        .map((doc) => Invoice.fromFirestore(doc.id, doc.data()))
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

    final now = DateTime.now();
    final dueDate = _resolveDueDate(now);
    final paymentLines = paymentMethods
        .map((item) => item.descripcion.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final paymentText = paymentLines.join('\n');
    final previousInvoicesByMeter = await _fetchPreviousInvoicesByMeter(period);
    final observations = await _observationService.fetchItems();
    final usersByCode = await _fetchUsersByCode();

    final batch = _db.batch();
    for (final reading in readings) {
      final invoice = _buildInvoice(
        period: period,
        reading: reading,
        values: values,
        paymentText: paymentText,
        paymentLines: paymentLines,
        generatedAt: now,
        dueDate: dueDate,
        previousInvoice: previousInvoicesByMeter[reading.codigoContador],
        sector: usersByCode[_normalizeUserCode(reading.codigoUsuario)]?.sector ?? '',
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
      batch.set(
        _periodConsumptions(period.id).doc(reading.codigoContador),
        reading
            .copyWith(
              facturado: true,
              pagado: false,
              reciboId: invoice.id,
              estado: 'facturado',
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
    int? paidAmount,
    PaymentMethod? paymentMethod,
    String? observations,
  }) async {
    final updated = invoice.copyWith(
      estado: paid ? 'pagado' : 'facturado',
      pagado: paid,
      valorPagado: paid ? (paidAmount ?? invoice.total) : 0,
      fechaPago: paid ? DateTime.now() : null,
      medioPagoId: paid ? paymentMethod?.id : null,
      medioPagoDescripcion: paid ? paymentMethod?.descripcion : null,
      observacionesPago:
          paid && (observations?.trim().isNotEmpty ?? false)
              ? observations!.trim()
              : null,
    );

    final batch = _db.batch();
    batch.set(
      _periodInvoices(invoice.periodo).doc(invoice.id),
      updated.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      _periodConsumptions(invoice.periodo).doc(invoice.codigoContador),
      {
        'pagado': paid,
        'estado': paid ? 'pagado' : 'facturado',
        'reciboId': invoice.id,
        'valorPagado': paid ? (paidAmount ?? invoice.total) : 0,
        'fechaPago': paid ? Timestamp.fromDate(updated.fechaPago!) : null,
        'medioPagoId': paid ? paymentMethod?.id : null,
        'medioPagoDescripcion': paid ? paymentMethod?.descripcion : null,
        'observacionesPago':
            paid && (observations?.trim().isNotEmpty ?? false)
                ? observations!.trim()
                : null,
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
    final previousInvoicesByMeter = await _fetchPreviousInvoicesByMeter(period);
    final observations = await _observationService.fetchItems();
    final usersByCode = await _fetchUsersByCode();

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
      final invoice = _buildInvoice(
        period: period,
        reading: reading,
        values: values,
        paymentText: paymentText,
        paymentLines: paymentLines,
        generatedAt: now,
        dueDate: dueDate,
        previousInvoice: previousInvoicesByMeter[reading.codigoContador],
        sector: usersByCode[_normalizeUserCode(reading.codigoUsuario)]?.sector ?? '',
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

  Invoice _buildInvoice({
    required BillingPeriod period,
    required ConsumptionReading reading,
    required BillingValueConfig values,
    required String paymentText,
    required List<String> paymentLines,
    required DateTime generatedAt,
    required DateTime dueDate,
    required Invoice? previousInvoice,
    required String sector,
    required List<InvoiceAppliedObservation> appliedObservations,
    required AppUser actor,
    Invoice? existingInvoice,
  }) {
    final previousReading = reading.lecturaAnterior ?? 0;
    final consumption = reading.consumoCalculado ??
        (reading.lecturaActual - previousReading).clamp(0, 1 << 31).toInt();
    final lineItems = <InvoiceLineItem>[
      InvoiceLineItem(
        descripcion: 'Cargo fijo',
        valorUnitario: values.cargoFijo,
        cantidad: 1,
        valorTotal: values.cargoFijo,
      ),
      ..._buildConsumptionLines(consumption, values.rangos),
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
      saldoAnterior: 0,
      lineas: lineItems,
      mediosPagoTexto: paymentText,
      mediosPago: paymentLines,
      estado: 'facturado',
      valorConfigId: values.id,
      valorConfigVersion: values.version,
      total: subtotal,
      pagado: false,
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

  Future<Map<String, Invoice>> _fetchPreviousInvoicesByMeter(
    BillingPeriod period,
  ) async {
    final previousPeriodId = _previousPeriodId(period);
    if (previousPeriodId == null) {
      return const {};
    }
    final items = await fetchInvoicesForPeriod(previousPeriodId);
    return {for (final item in items) item.codigoContador: item};
  }

  Future<Map<String, AppUser>> _fetchUsersByCode() async {
    final users = await _userService.fetchUsers(limit: 5000);
    return {
      for (final user in users)
        if (_normalizeUserCode(user.codigoUsuario).isNotEmpty)
          _normalizeUserCode(user.codigoUsuario): user,
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

  String? _previousPeriodId(BillingPeriod period) {
    if (period.ano <= 0 || period.mes <= 0) {
      return null;
    }
    final current = DateTime(period.ano, period.mes);
    final previous = DateTime(current.year, current.month - 1);
    return '${previous.year}-${previous.month.toString().padLeft(2, '0')}';
  }

  String _resolvePreviousPeriodStatus(Invoice? previousInvoice) {
    if (previousInvoice == null) {
      return 'al_dia';
    }
    final normalized = previousInvoice.estado.trim().toLowerCase();
    if (normalized == 'suspendido') {
      return 'suspendido';
    }
    if (normalized == 'pagado' || previousInvoice.pagado) {
      return 'al_dia';
    }
    return 'en_mora';
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
}
