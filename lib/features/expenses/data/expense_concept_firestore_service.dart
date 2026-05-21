import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/expense_concept.dart';

class ExpenseConceptFirestoreService {
  ExpenseConceptFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('gastos_conceptos');

  Stream<List<ExpenseConcept>> watchItems({int limit = 300}) {
    return _collection
        .orderBy('nombre')
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ExpenseConcept.fromFirestore).toList(),
        );
  }

  Future<List<ExpenseConcept>> fetchActiveItems({int limit = 300}) async {
    final snapshot = await _collection
        .where('estado', isEqualTo: 'activo')
        .orderBy('nombre')
        .limit(limit)
        .get();
    return snapshot.docs.map(ExpenseConcept.fromFirestore).toList();
  }

  Future<void> saveItem(ExpenseConcept item) {
    return _collection.doc(item.id).set(
          item.toFirestore(),
          SetOptions(merge: true),
        );
  }
}
