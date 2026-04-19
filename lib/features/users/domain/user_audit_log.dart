import 'package:cloud_firestore/cloud_firestore.dart';

class UserAuditLog {
  const UserAuditLog({
    required this.id,
    required this.accion,
    required this.actorNombre,
    required this.actorUid,
    required this.usuarioObjetivoUid,
    required this.usuarioObjetivoNombre,
    required this.fecha,
    required this.searchTokens,
    this.anterior,
    this.nuevo,
  });

  final String id;
  final String accion;
  final String actorNombre;
  final String actorUid;
  final String usuarioObjetivoUid;
  final String usuarioObjetivoNombre;
  final DateTime fecha;
  final List<String> searchTokens;
  final Map<String, dynamic>? anterior;
  final Map<String, dynamic>? nuevo;

  bool matchesText(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    return searchTokens.contains(normalized);
  }

  factory UserAuditLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserAuditLog(
      id: doc.id,
      accion: data['accion'] as String? ?? '',
      actorNombre: data['actorNombre'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      usuarioObjetivoUid: data['usuarioObjetivoUid'] as String? ?? '',
      usuarioObjetivoNombre: data['usuarioObjetivoNombre'] as String? ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      searchTokens: (data['searchTokens'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      anterior: _mapValue(data['anterior']),
      nuevo: _mapValue(data['nuevo']),
    );
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    return value;
  }
}
