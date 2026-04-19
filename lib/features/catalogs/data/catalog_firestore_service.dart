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

  Future<void> ensureDefaults(List<CatalogItem> defaults) async {
    final existing = await _collection.limit(1).get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final item in defaults) {
      batch.set(_collection.doc(item.id), item.toFirestore());
    }
    await batch.commit();
  }
}

class DocumentTypeCatalogService extends CatalogFirestoreService {
  DocumentTypeCatalogService({FirebaseFirestore? firestore})
      : super('tipos_documento', firestore: firestore);

  static List<CatalogItem> defaultItems() {
    final now = DateTime.now();
    return [
      CatalogItem(
        id: 'cc',
        valor: 'cc',
        nombre: 'cedula de ciudadania',
        estado: 'activo',
        fechaCreacion: now,
      ),
      CatalogItem(
        id: 'ce',
        valor: 'ce',
        nombre: 'cedula de extranjeria',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 1)),
      ),
      CatalogItem(
        id: 'nit',
        valor: 'nit',
        nombre: 'numero de identificacion tributaria',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 2)),
      ),
      CatalogItem(
        id: 'ppt',
        valor: 'ppt',
        nombre: 'permiso por proteccion temporal',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 3)),
      ),
      CatalogItem(
        id: 'pas',
        valor: 'pas',
        nombre: 'pasaporte',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 4)),
      ),
    ];
  }
}

class RoleCatalogService extends CatalogFirestoreService {
  RoleCatalogService({FirebaseFirestore? firestore})
      : super('roles', firestore: firestore);

  static List<CatalogItem> defaultItems() {
    final now = DateTime.now();
    return [
      CatalogItem(
        id: 'administrador',
        valor: 'administrador',
        nombre: 'administrador',
        estado: 'activo',
        fechaCreacion: now,
      ),
      CatalogItem(
        id: 'cliente',
        valor: 'cliente',
        nombre: 'cliente',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 1)),
      ),
      CatalogItem(
        id: 'contador',
        valor: 'contador',
        nombre: 'contador',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 2)),
      ),
      CatalogItem(
        id: 'operario',
        valor: 'operario',
        nombre: 'operario',
        estado: 'activo',
        fechaCreacion: now.add(const Duration(seconds: 3)),
      ),
    ];
  }
}

class SectorCatalogService extends CatalogFirestoreService {
  SectorCatalogService({FirebaseFirestore? firestore})
      : super('sectores', firestore: firestore);
}
