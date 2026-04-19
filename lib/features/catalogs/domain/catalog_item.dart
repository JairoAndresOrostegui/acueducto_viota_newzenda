import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.valor,
    required this.nombre,
    required this.estado,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  final String id;
  final String valor;
  final String nombre;
  final String estado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  bool get isActive => estado == 'activo';

  CatalogItem copyWith({
    String? id,
    String? valor,
    String? nombre,
    String? estado,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      valor: valor ?? this.valor,
      nombre: nombre ?? this.nombre,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  factory CatalogItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CatalogItem(
      id: doc.id,
      valor: data['valor'] as String? ?? doc.id,
      nombre: data['nombre'] as String? ?? '',
      estado: data['estado'] as String? ?? 'activo',
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
      fechaActualizacion: _toDateTime(data['fechaActualizacion']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'valor': valor,
      'nombre': nombre,
      'estado': estado,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': fechaActualizacion == null
          ? null
          : Timestamp.fromDate(fechaActualizacion!),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
