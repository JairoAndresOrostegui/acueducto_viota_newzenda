import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseConcept {
  const ExpenseConcept({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.creadoPorUid,
    required this.creadoPorNombre,
    required this.fechaCreacion,
    this.descripcion = '',
    this.actualizadoPorUid,
    this.actualizadoPorNombre,
    this.fechaActualizacion,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String estado;
  final String creadoPorUid;
  final String creadoPorNombre;
  final DateTime fechaCreacion;
  final String? actualizadoPorUid;
  final String? actualizadoPorNombre;
  final DateTime? fechaActualizacion;

  bool get activo => estado == 'activo';

  ExpenseConcept copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? estado,
    String? creadoPorUid,
    String? creadoPorNombre,
    DateTime? fechaCreacion,
    String? actualizadoPorUid,
    String? actualizadoPorNombre,
    DateTime? fechaActualizacion,
  }) {
    return ExpenseConcept(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      creadoPorUid: creadoPorUid ?? this.creadoPorUid,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      actualizadoPorUid: actualizadoPorUid ?? this.actualizadoPorUid,
      actualizadoPorNombre:
          actualizadoPorNombre ?? this.actualizadoPorNombre,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'estado': estado,
      'creadoPorUid': creadoPorUid,
      'creadoPorNombre': creadoPorNombre,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'actualizadoPorUid': actualizadoPorUid,
      'actualizadoPorNombre': actualizadoPorNombre,
      'fechaActualizacion': fechaActualizacion == null
          ? null
          : Timestamp.fromDate(fechaActualizacion!),
    };
  }

  factory ExpenseConcept.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExpenseConcept(
      id: data['id'] as String? ?? doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      estado: data['estado'] as String? ?? 'activo',
      creadoPorUid: data['creadoPorUid'] as String? ?? '',
      creadoPorNombre: data['creadoPorNombre'] as String? ?? '',
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
      actualizadoPorUid: data['actualizadoPorUid'] as String?,
      actualizadoPorNombre: data['actualizadoPorNombre'] as String?,
      fechaActualizacion: _toDateTime(data['fechaActualizacion']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
