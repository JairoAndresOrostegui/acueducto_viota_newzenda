import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.descripcion,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  final String id;
  final String descripcion;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  factory PaymentMethod.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return PaymentMethod(
      id: doc.id,
      descripcion: data['descripcion'] as String? ?? '',
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
      fechaActualizacion: _toDateTime(data['fechaActualizacion']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'descripcion': descripcion,
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
