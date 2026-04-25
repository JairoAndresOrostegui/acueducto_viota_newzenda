import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/billing_observation.dart';

class BillingObservationFirestoreService {
  BillingObservationFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('facturacion_observaciones');

  Stream<List<BillingObservation>> watchItems({int limit = 300}) {
    return _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BillingObservation.fromFirestore)
              .toList(),
        );
  }

  Future<List<BillingObservation>> fetchItems({int limit = 300}) async {
    final snapshot = await _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(BillingObservation.fromFirestore).toList();
  }

  Future<void> saveItem(BillingObservation item) {
    return _collection.doc(item.id).set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) {
    return _collection.doc(id).delete();
  }
}
