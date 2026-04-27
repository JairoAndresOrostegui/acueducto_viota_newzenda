import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';

class UserPageResult {
  const UserPageResult({
    required this.users,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<AppUser> users;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class UserFirestoreService {
  UserFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      (_firestore ?? FirebaseFirestore.instance).collection('usuarios');

  Future<List<AppUser>> fetchUsers({int limit = 200}) async {
    final snapshot = await _usersCollection.orderBy('nombre').limit(limit).get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  Future<UserPageResult> fetchUsersPage({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _usersCollection
        .orderBy('nombre')
        .limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.take(limit).toList() : docs;

    return UserPageResult(
      users: pageDocs.map(AppUser.fromFirestore).toList(),
      lastDocument: pageDocs.isEmpty ? startAfter : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<List<AppUser>> fetchAllUsers({int batchSize = 200}) async {
    final users = <AppUser>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;

    while (true) {
      final page = await fetchUsersPage(limit: batchSize, startAfter: cursor);
      users.addAll(page.users);
      if (!page.hasMore || page.lastDocument == null) {
        break;
      }
      cursor = page.lastDocument;
    }

    return users;
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
