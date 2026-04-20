import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/payment_method.dart';

class PaymentMethodFirestoreService {
  PaymentMethodFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('medios_pago');

  Stream<List<PaymentMethod>> watchItems({int limit = 200}) {
    return _collection
        .orderBy('fechaCreacion', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PaymentMethod.fromFirestore).toList());
  }

  Future<void> saveItem(PaymentMethod item) {
    return _collection.doc(item.id).set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) {
    return _collection.doc(id).delete();
  }
}
