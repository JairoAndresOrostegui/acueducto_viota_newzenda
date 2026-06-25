import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/billing_value_config.dart';

class BillingValueConfigFirestoreService {
  BillingValueConfigFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('valores_facturacion');

  Stream<List<BillingValueConfig>> watchActiveItems() {
    return _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map(BillingValueConfig.fromFirestore)
                  .where((item) => item.isActive)
                  .toList()
                ..sort((a, b) {
                  final periodCompare = b.periodoInicio.compareTo(
                    a.periodoInicio,
                  );
                  if (periodCompare != 0) {
                    return periodCompare;
                  }
                  return b.fechaCreacion.compareTo(a.fechaCreacion);
                });
          return items;
        });
  }

  Stream<BillingValueConfig?> watchActiveItem() {
    return _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          for (final doc in snapshot.docs) {
            final item = BillingValueConfig.fromFirestore(doc);
            if (item.isActive) {
              return item;
            }
          }
          return null;
        });
  }

  Future<BillingValueConfig?> fetchActiveItem() async {
    final snapshot = await _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(50)
        .get();
    for (final doc in snapshot.docs) {
      final item = BillingValueConfig.fromFirestore(doc);
      if (item.isActive) {
        return item;
      }
    }
    return null;
  }

  Future<BillingValueConfig?> fetchApplicableItemForPeriod(
    String periodId,
  ) async {
    final normalizedPeriod = periodId.trim();
    final snapshot = await _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(100)
        .get();
    final items =
        snapshot.docs
            .map(BillingValueConfig.fromFirestore)
            .where(
              (item) => item.isActive && item.appliesToPeriod(normalizedPeriod),
            )
            .toList()
          ..sort((a, b) {
            final periodCompare = b.periodoInicio.compareTo(a.periodoInicio);
            if (periodCompare != 0) {
              return periodCompare;
            }
            return b.fechaCreacion.compareTo(a.fechaCreacion);
          });
    if (items.isNotEmpty) {
      return items.first;
    }
    return fetchActiveItem();
  }

  Future<void> saveNewVersion({
    required BillingValueConfig item,
    BillingValueConfig? previousActive,
  }) async {
    final batch = _db.batch();
    if (previousActive != null) {
      batch.update(_collection.doc(previousActive.id), {
        'estado': 'inactivo',
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    }
    batch.set(
      _collection.doc(item.id),
      item.toFirestore(),
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
