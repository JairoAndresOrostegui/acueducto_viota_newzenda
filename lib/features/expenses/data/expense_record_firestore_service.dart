import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/expense_record.dart';

class ExpenseRecordFirestoreService {
  ExpenseRecordFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('gastos');

  Stream<List<ExpenseRecord>> watchByPeriod(String periodId, {int limit = 500}) {
    return _collection
        .where('periodoId', isEqualTo: periodId)
        .orderBy('fechaGasto', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ExpenseRecord.fromFirestore).toList(),
        );
  }

  Future<List<ExpenseRecord>> fetchByPeriod(String periodId, {int limit = 500}) async {
    final snapshot = await _collection
        .where('periodoId', isEqualTo: periodId)
        .orderBy('fechaGasto', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(ExpenseRecord.fromFirestore).toList();
  }

  Future<void> saveItem(ExpenseRecord item) {
    return _collection.doc(item.id).set(
          item.toFirestore(),
          SetOptions(merge: true),
        );
  }
}
