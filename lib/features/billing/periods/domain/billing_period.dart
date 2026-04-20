import 'package:cloud_firestore/cloud_firestore.dart';

class BillingPeriod {
  const BillingPeriod({
    required this.id,
    required this.ano,
    required this.mes,
    required this.clave,
    required this.nombre,
    required this.vigente,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  final String id;
  final int ano;
  final int mes;
  final String clave;
  final String nombre;
  final bool vigente;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  factory BillingPeriod.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return BillingPeriod(
      id: doc.id,
      ano: data['ano'] as int? ?? 0,
      mes: data['mes'] as int? ?? 0,
      clave: data['clave'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      vigente: data['vigente'] as bool? ?? false,
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
      fechaActualizacion: _toDateTime(data['fechaActualizacion']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ano': ano,
      'mes': mes,
      'clave': clave,
      'nombre': nombre,
      'vigente': vigente,
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
