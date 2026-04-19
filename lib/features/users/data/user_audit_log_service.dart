import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_audit_log.dart';

class UserAuditLogService {
  UserAuditLogService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('usuarios_logs');

  Stream<List<UserAuditLog>> watchLogs({
    String? query,
    int limit = 50,
  }) {
    final normalized = _normalizeQuery(query);
    Query<Map<String, dynamic>> base = _collection;

    if (normalized != null) {
      base = base.where('searchTokens', arrayContains: normalized);
    }

    return base
        .orderBy('fecha', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserAuditLog.fromFirestore).toList());
  }

  String? _normalizeQuery(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return text.split(RegExp(r'\s+')).first;
  }
}
