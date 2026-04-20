import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/billing_value_config.dart';

class BillingValueConfigFirestoreService {
  BillingValueConfigFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('valores_facturacion');

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
    batch.set(_collection.doc(item.id), item.toFirestore(), SetOptions(merge: true));
    await batch.commit();
  }
}
