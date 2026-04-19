import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/catalog_item.dart';

String normalizeCatalogValue(String value) => value.trim().toLowerCase();

class CatalogFirestoreService {
  CatalogFirestoreService(
    this.collectionName, {
    FirebaseFirestore? firestore,
  }) : _firestore = firestore;

  final String collectionName;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(collectionName);

  Stream<List<CatalogItem>> watchItems({int limit = 200}) {
    return _collection
        .orderBy('fechaCreacion')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CatalogItem.fromFirestore).toList());
  }

  Future<List<CatalogItem>> fetchActiveItems({int limit = 100}) async {
    final snapshot = await _collection
        .where('estado', isEqualTo: 'activo')
        .orderBy('fechaCreacion')
        .limit(limit)
        .get();

    return snapshot.docs.map(CatalogItem.fromFirestore).toList();
  }

  Future<void> saveItem(CatalogItem item) {
    final normalized = item.copyWith(
      valor: normalizeCatalogValue(item.valor),
      nombre: normalizeCatalogValue(item.nombre),
      estado: normalizeCatalogValue(item.estado),
    );

    return _collection
        .doc(normalized.id)
        .set(normalized.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) {
    return _collection.doc(id).delete();
  }
}

class DocumentTypeCatalogService extends CatalogFirestoreService {
  DocumentTypeCatalogService({FirebaseFirestore? firestore})
      : super('tipos_documento', firestore: firestore);
}

class RoleCatalogService extends CatalogFirestoreService {
  RoleCatalogService({FirebaseFirestore? firestore})
      : super('roles', firestore: firestore);
}

class SectorCatalogService extends CatalogFirestoreService {
  SectorCatalogService({FirebaseFirestore? firestore})
      : super('sectores', firestore: firestore);
}
