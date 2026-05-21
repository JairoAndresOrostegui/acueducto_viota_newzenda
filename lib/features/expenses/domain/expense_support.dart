import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSupport {
  const ExpenseSupport({
    required this.id,
    required this.periodoId,
    required this.periodoNombre,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.cargadoPorUid,
    required this.cargadoPorNombre,
    required this.fechaCarga,
    this.editadoPorUid,
    this.editadoPorNombre,
    this.fechaEdicion,
  });

  final String id;
  final String periodoId;
  final String periodoNombre;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String cargadoPorUid;
  final String cargadoPorNombre;
  final DateTime fechaCarga;
  final String? editadoPorUid;
  final String? editadoPorNombre;
  final DateTime? fechaEdicion;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'periodoId': periodoId,
      'periodoNombre': periodoNombre,
      'fileName': fileName,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'cargadoPorUid': cargadoPorUid,
      'cargadoPorNombre': cargadoPorNombre,
      'fechaCarga': Timestamp.fromDate(fechaCarga),
      'editadoPorUid': editadoPorUid,
      'editadoPorNombre': editadoPorNombre,
      'fechaEdicion': fechaEdicion == null
          ? null
          : Timestamp.fromDate(fechaEdicion!),
    };
  }

  factory ExpenseSupport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExpenseSupport(
      id: data['id'] as String? ?? doc.id,
      periodoId: data['periodoId'] as String? ?? doc.id,
      periodoNombre: data['periodoNombre'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      cargadoPorUid: data['cargadoPorUid'] as String? ?? '',
      cargadoPorNombre: data['cargadoPorNombre'] as String? ?? '',
      fechaCarga: _toDateTime(data['fechaCarga']) ?? DateTime.now(),
      editadoPorUid: data['editadoPorUid'] as String?,
      editadoPorNombre: data['editadoPorNombre'] as String?,
      fechaEdicion: _toDateTime(data['fechaEdicion']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
