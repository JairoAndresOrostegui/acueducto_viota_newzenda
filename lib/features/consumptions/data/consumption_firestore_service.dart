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

  Future<ConsumptionReading?> fetchReadingById(String readingId) async {
    final snapshot = await _collection.doc(readingId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return ConsumptionReading.fromFirestore(snapshot.id, snapshot.data()!);
  }

  Future<ConsumptionReading?> fetchLatestPreviousReading({
    required String meterCode,
    required String currentPeriod,
  }) async {
    final snapshot = await _collection
        .where('codigoContador', isEqualTo: meterCode)
        .get();
    final readings = snapshot.docs
        .map((doc) => ConsumptionReading.fromFirestore(doc.id, doc.data()))
        .where((item) => item.periodoActual.compareTo(currentPeriod) < 0)
        .toList()
      ..sort((a, b) => b.periodoActual.compareTo(a.periodoActual));
    return readings.isEmpty ? null : readings.first;
  }

  Future<void> saveReading(ConsumptionReading reading) {
    return _collection
        .doc(reading.id)
        .set(reading.toFirestore(), SetOptions(merge: true));
  }
}
