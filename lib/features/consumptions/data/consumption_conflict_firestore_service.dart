import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/consumption_conflict.dart';
import '../domain/consumption_reading.dart';

class ConsumptionConflictFirestoreService {
  ConsumptionConflictFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('consumos_conflictos');

  Future<String> registerConflict({
    required ConsumptionReading proposedReading,
    ConsumptionReading? existingReading,
    ConsumptionReading? previousReading,
    required String motivo,
    required String mensaje,
  }) async {
    final conflictId = '${proposedReading.id}|${proposedReading.actorUid}';
    final conflict = ConsumptionConflict(
      id: conflictId,
      lecturaId: proposedReading.id,
      lecturaPropuesta: proposedReading.copyWith(estado: 'bloqueado'),
      lecturaExistente: existingReading,
      lecturaAnterior: previousReading,
      motivo: motivo,
      mensaje: mensaje,
      estado: 'pendiente',
      fecha: DateTime.now(),
    );
    await _collection.doc(conflictId).set(conflict.toFirestore());
    return conflictId;
  }

  Future<ConsumptionConflict?> fetchConflictById(String conflictId) async {
    final snapshot = await _collection.doc(conflictId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return ConsumptionConflict.fromFirestore(snapshot.id, snapshot.data()!);
  }

  Future<List<ConsumptionConflict>> fetchPendingConflicts() async {
    final snapshot = await _collection.where('estado', isEqualTo: 'pendiente').get();
    final items = snapshot.docs
        .map((doc) => ConsumptionConflict.fromFirestore(doc.id, doc.data()))
        .toList();
    items.sort((a, b) => b.fecha.compareTo(a.fecha));
    return items;
  }

  Future<void> resolveConflict({
    required ConsumptionConflict conflict,
    required ConsumptionReading finalReading,
    required String adminUid,
    required String adminName,
  }) {
    return _collection.doc(conflict.id).update({
      'estado': 'resuelto',
      'lecturaFinal': finalReading.toMap(),
      'resueltoPorUid': adminUid,
      'resueltoPorNombre': adminName,
      'fechaResolucion': Timestamp.fromDate(DateTime.now()),
    });
  }
}
