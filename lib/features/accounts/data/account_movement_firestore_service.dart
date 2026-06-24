import 'package:cloud_firestore/cloud_firestore.dart';

import '../../billing/invoices/domain/invoice.dart';
import '../../billing/payment_methods/domain/payment_method.dart';
import '../../users/domain/app_user.dart';
import '../domain/account_movement.dart';

class AccountMovementFirestoreService {
  AccountMovementFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('cuentas_movimientos');

  Future<List<AccountMovement>> fetchMovements({
    String? codigoUsuario,
    String? periodo,
    int limit = 500,
  }) async {
    Query<Map<String, dynamic>> query = _collection;
    if ((codigoUsuario ?? '').trim().isNotEmpty) {
      query = query.where(
        'codigoUsuario',
        isEqualTo: codigoUsuario!.trim().toUpperCase(),
      );
    }
    if ((periodo ?? '').trim().isNotEmpty) {
      query = query.where('periodo', isEqualTo: periodo!.trim());
    }
    final snapshot = await query.limit(limit).get();
    final items =
        snapshot.docs
            .map((doc) => AccountMovement.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            final periodCompare = a.periodo.compareTo(b.periodo);
            if (periodCompare != 0) {
              return periodCompare;
            }
            return a.fecha.compareTo(b.fecha);
          });
    return items;
  }

  Future<Map<String, int>> fetchBalancesBeforePeriod({
    required String periodId,
    required Iterable<String> customerCodes,
  }) async {
    final normalizedCodes = customerCodes
        .map(_normalizeUserCode)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedCodes.isEmpty) {
      return const {};
    }

    final snapshot = await _collection
        .where('periodo', isLessThan: periodId.trim())
        .get();
    final balances = <String, int>{};
    for (final doc in snapshot.docs) {
      final movement = AccountMovement.fromFirestore(doc.id, doc.data());
      final code = _normalizeUserCode(movement.codigoUsuario);
      if (!normalizedCodes.contains(code)) {
        continue;
      }
      balances[code] = (balances[code] ?? 0) + movement.valor;
    }
    return balances;
  }

  Future<Map<String, int>> fetchMeterBalancesBeforePeriod({
    required String periodId,
    required Iterable<String> meterCodes,
  }) async {
    final normalizedMeters = meterCodes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedMeters.isEmpty) {
      return const {};
    }

    final snapshot = await _collection
        .where('periodo', isLessThan: periodId.trim())
        .get();
    final balances = <String, int>{};
    for (final doc in snapshot.docs) {
      final movement = AccountMovement.fromFirestore(doc.id, doc.data());
      final meter = movement.codigoContador.trim();
      if (!normalizedMeters.contains(meter)) {
        continue;
      }
      balances[meter] = (balances[meter] ?? 0) + movement.valor;
    }
    return balances;
  }

  void setInvoiceCharge({
    required WriteBatch batch,
    required Invoice invoice,
    required AppUser actor,
    DateTime? createdAt,
  }) {
    final movement = AccountMovement(
      id: invoiceChargeMovementId(invoice),
      tipo: 'factura',
      codigoUsuario: _normalizeUserCode(invoice.codigoUsuario),
      codigoContador: invoice.codigoContador,
      nombreUsuario: invoice.nombreUsuario,
      sector: invoice.sector,
      periodo: invoice.periodo,
      valor: invoice.currentChargeTotal,
      descripcion: 'Factura ${invoice.periodo}',
      fecha: createdAt ?? invoice.fechaGeneracion,
      actorUid: actor.uid,
      actorNombre: actor.nombre,
      reciboId: invoice.id,
    );
    batch.set(
      _collection.doc(movement.id),
      movement.toFirestore(),
      SetOptions(merge: true),
    );
  }

  void addPaymentDelta({
    required WriteBatch batch,
    required Invoice invoice,
    required int deltaPaidAmount,
    required AppUser actor,
    PaymentMethod? paymentMethod,
    String? observations,
    DateTime? paidAt,
  }) {
    if (deltaPaidAmount == 0) {
      return;
    }
    final now = paidAt ?? DateTime.now();
    final isPayment = deltaPaidAmount > 0;
    final movement = AccountMovement(
      id: '${isPayment ? 'pago' : 'reverso_pago'}_${invoice.periodo}_${invoice.codigoContador}_${now.microsecondsSinceEpoch}',
      tipo: isPayment ? 'pago' : 'reverso_pago',
      codigoUsuario: _normalizeUserCode(invoice.codigoUsuario),
      codigoContador: invoice.codigoContador,
      nombreUsuario: invoice.nombreUsuario,
      sector: invoice.sector,
      periodo: invoice.periodo,
      valor: isPayment ? -deltaPaidAmount : deltaPaidAmount.abs(),
      descripcion: isPayment
          ? 'Pago recibido ${invoice.periodo}'
          : 'Reverso de pago ${invoice.periodo}',
      fecha: now,
      actorUid: actor.uid,
      actorNombre: actor.nombre,
      reciboId: invoice.id,
      medioPagoId: isPayment ? paymentMethod?.id : null,
      medioPagoDescripcion: isPayment ? paymentMethod?.descripcion : null,
      observaciones: (observations?.trim().isNotEmpty ?? false)
          ? observations!.trim()
          : null,
    );
    batch.set(_collection.doc(movement.id), movement.toFirestore());
  }

  static String invoiceChargeMovementId(Invoice invoice) {
    return 'factura_${invoice.periodo}_${invoice.codigoContador}';
  }

  static String _normalizeUserCode(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'NA') {
      return '';
    }
    return normalized;
  }
}
