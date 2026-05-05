import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/billing_period.dart';

class BillingPeriodFirestoreService {
  BillingPeriodFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  static const int firstAllowedYear = 2025;
  static const int firstAllowedMonth = 12;
  static const int firstOperationalYear = 2026;
  static const int firstOperationalMonth = 1;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('periodos');

  Stream<List<BillingPeriod>> watchPeriods() {
    return _collection.snapshots().map((snapshot) {
      return _sortPeriods(snapshot.docs.map(BillingPeriod.fromFirestore).toList());
    });
  }

  Future<List<BillingPeriod>> fetchPeriods() async {
    final snapshot = await _collection.get();
    return _sortPeriods(snapshot.docs.map(BillingPeriod.fromFirestore).toList());
  }

  Stream<List<BillingPeriod>> watchOperationalPeriods() {
    return watchPeriods().map(_filterOperationalPeriods);
  }

  Future<List<BillingPeriod>> fetchOperationalPeriods() async {
    return _filterOperationalPeriods(await fetchPeriods());
  }

  Future<BillingPeriod?> fetchActivePeriod() async {
    final snapshot = await _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(50)
        .get();
    for (final doc in snapshot.docs) {
      final item = BillingPeriod.fromFirestore(doc);
      if (item.vigente) {
        return item;
      }
    }
    return null;
  }

  Future<void> createPeriod({
    required int ano,
    required int mes,
  }) async {
    _validateAllowedPeriod(ano, mes);
    final docId = _docId(ano, mes);
    final docRef = _collection.doc(docId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        return;
      }

      final now = DateTime.now();
      final period = BillingPeriod(
        id: docId,
        ano: ano,
        mes: mes,
        clave: docId,
        nombre: _periodName(ano, mes),
        vigente: false,
        fechaCreacion: now,
      );
      transaction.set(docRef, period.toFirestore());
    });
  }

  Future<void> createPeriodsForYear({
    required int ano,
    required List<int> meses,
  }) async {
    final missingMonths = meses
        .where((mes) => isAllowedPeriod(ano, mes))
        .toSet()
        .toList()
      ..sort();
    if (missingMonths.isEmpty) {
      return;
    }

    final batch = _db.batch();
    final now = DateTime.now();
    for (final mes in missingMonths) {
      final docId = _docId(ano, mes);
      final period = BillingPeriod(
        id: docId,
        ano: ano,
        mes: mes,
        clave: docId,
        nombre: _periodName(ano, mes),
        vigente: false,
        fechaCreacion: now,
      );
      batch.set(_collection.doc(docId), period.toFirestore());
    }
    await batch.commit();
  }

  Future<void> setCurrentPeriod(String periodId) async {
    final selectedRef = _collection.doc(periodId);
    await _db.runTransaction((transaction) async {
      final selectedSnapshot = await transaction.get(selectedRef);
      if (!selectedSnapshot.exists) {
        throw StateError('El período seleccionado no existe.');
      }

      final currentSnapshot = await _collection
          .where('vigente', isEqualTo: true)
          .limit(1)
          .get();

      for (final doc in currentSnapshot.docs) {
        if (doc.id != periodId) {
          transaction.update(doc.reference, {
            'vigente': false,
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.update(selectedRef, {
        'vigente': true,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    });
  }

  static String docId(int ano, int mes) => _docId(ano, mes);

  static String periodName(int ano, int mes) => _periodName(ano, mes);

  static bool isAllowedPeriod(int ano, int mes) {
    if (ano < firstAllowedYear) {
      return false;
    }
    if (ano == firstAllowedYear && mes < firstAllowedMonth) {
      return false;
    }
    return mes >= 1 && mes <= 12;
  }

  static bool isBasePeriod(BillingPeriod period) {
    return period.ano == firstAllowedYear && period.mes == firstAllowedMonth;
  }

  static bool isOperationalPeriod(BillingPeriod period) {
    if (period.ano < firstOperationalYear) {
      return false;
    }
    if (period.ano == firstOperationalYear &&
        period.mes < firstOperationalMonth) {
      return false;
    }
    return period.mes >= 1 && period.mes <= 12;
  }

  static List<BillingPeriod> _filterOperationalPeriods(
    List<BillingPeriod> items,
  ) {
    return items.where(isOperationalPeriod).toList();
  }

  static void _validateAllowedPeriod(int ano, int mes) {
    if (!isAllowedPeriod(ano, mes)) {
      throw StateError('El historial de facturacion inicia en diciembre 2025.');
    }
  }

  static String _docId(int ano, int mes) => '$ano-${mes.toString().padLeft(2, '0')}';

  static String _periodName(int ano, int mes) {
    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${monthNames[mes - 1]} $ano';
  }

  static List<BillingPeriod> _sortPeriods(List<BillingPeriod> items) {
    items.sort((a, b) {
      final yearCompare = b.ano.compareTo(a.ano);
      if (yearCompare != 0) {
        return yearCompare;
      }
      return a.mes.compareTo(b.mes);
    });
    return items;
  }
}
