import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/expense_support.dart';

class ExpenseSupportService {
  ExpenseSupportService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _bucket => _storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('gastos_soportes');

  Stream<ExpenseSupport?> watchByPeriod(String periodId) {
    return _collection.doc(periodId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return ExpenseSupport.fromFirestore(snapshot);
    });
  }

  Future<ExpenseSupport?> fetchByPeriod(String periodId) async {
    final snapshot = await _collection.doc(periodId).get();
    if (!snapshot.exists) {
      return null;
    }
    return ExpenseSupport.fromFirestore(snapshot);
  }

  Future<ExpenseSupport> createSupport({
    required String periodId,
    required String periodName,
    required String fileName,
    required Uint8List bytes,
    required String actorUid,
    required String actorName,
  }) async {
    final existing = await fetchByPeriod(periodId);
    if (existing != null) {
      throw StateError('Ya existe un soporte cargado para este periodo.');
    }

    final now = DateTime.now();
    final storagePath =
        'gastos_soportes/$periodId/${now.microsecondsSinceEpoch}.pdf';
    final ref = _bucket.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'periodoId': periodId,
          'cargadoPorUid': actorUid,
        },
      ),
    );
    final downloadUrl = await ref.getDownloadURL();
    final support = ExpenseSupport(
      id: periodId,
      periodoId: periodId,
      periodoNombre: periodName,
      fileName: fileName,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      cargadoPorUid: actorUid,
      cargadoPorNombre: actorName,
      fechaCarga: now,
    );
    await _collection.doc(periodId).set(support.toFirestore());
    return support;
  }

  Future<ExpenseSupport> replaceSupport({
    required ExpenseSupport current,
    required String fileName,
    required Uint8List bytes,
    required String actorUid,
    required String actorName,
  }) async {
    final now = DateTime.now();
    final newPath =
        'gastos_soportes/${current.periodoId}/${now.microsecondsSinceEpoch}.pdf';
    final newRef = _bucket.ref(newPath);
    await newRef.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'periodoId': current.periodoId,
          'editadoPorUid': actorUid,
        },
      ),
    );
    final downloadUrl = await newRef.getDownloadURL();
    final updated = ExpenseSupport(
      id: current.id,
      periodoId: current.periodoId,
      periodoNombre: current.periodoNombre,
      fileName: fileName,
      storagePath: newPath,
      downloadUrl: downloadUrl,
      cargadoPorUid: current.cargadoPorUid,
      cargadoPorNombre: current.cargadoPorNombre,
      fechaCarga: current.fechaCarga,
      editadoPorUid: actorUid,
      editadoPorNombre: actorName,
      fechaEdicion: now,
    );
    await _collection.doc(current.periodoId).set(updated.toFirestore());
    if (current.storagePath.isNotEmpty) {
      await _bucket.ref(current.storagePath).delete().catchError((_) {});
    }
    return updated;
  }
}
