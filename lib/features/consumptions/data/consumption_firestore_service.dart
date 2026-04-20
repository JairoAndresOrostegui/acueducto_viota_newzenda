import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/consumption_reading.dart';

class ConsumptionFirestoreService {
  ConsumptionFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('consumos');

  Future<List<ConsumptionReading>> fetchReadingsForPeriod(String period) async {
    final snapshot = await _collection
        .where('periodoActual', isEqualTo: period)
        .get();
    return snapshot.docs
        .map((doc) => ConsumptionReading.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<void> saveReading(ConsumptionReading reading) {
    return _collection.doc(reading.id).set(reading.toFirestore(), SetOptions(merge: true));
  }
}
