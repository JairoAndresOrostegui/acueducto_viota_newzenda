import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';

class UserFirestoreService {
  UserFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      (_firestore ?? FirebaseFirestore.instance).collection('usuarios');

  Stream<List<AppUser>> watchUsers({int limit = 200}) {
    return _usersCollection
        .orderBy('nombre')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppUser.fromFirestore).toList());
  }

  Future<List<AppUser>> fetchUsers({int limit = 200}) async {
    final snapshot = await _usersCollection.orderBy('nombre').limit(limit).get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  Future<List<AppUser>> fetchActiveClients({int limit = 500}) async {
    final snapshot = await _usersCollection
        .where('rol', isEqualTo: 'cliente')
        .where('estado', isEqualTo: 'activo')
        .limit(limit)
        .get();
    final users = snapshot.docs.map(AppUser.fromFirestore).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return users
        .where((user) => user.codigoUsuario != 'na')
        .where((user) => user.numeroContador.isNotEmpty)
        .toList();
  }

  Future<AppUser?> getUser(String uid) async {
    final snapshot = await _usersCollection.doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }
    return AppUser.fromFirestore(snapshot);
  }
}
