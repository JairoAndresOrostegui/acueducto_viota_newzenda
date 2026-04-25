import 'package:cloud_firestore/cloud_firestore.dart';

class BillingObservation {
  const BillingObservation({
    required this.id,
    required this.descripcion,
    required this.tipo,
    required this.siempre,
    required this.fechaCreacion,
    this.codigoUsuario,
    this.nombreUsuario,
    this.periodo,
    this.fechaActualizacion,
  });

  final String id;
  final String descripcion;
  final String tipo;
  final bool siempre;
  final DateTime fechaCreacion;
  final String? codigoUsuario;
  final String? nombreUsuario;
  final String? periodo;
  final DateTime? fechaActualizacion;

  bool get isMassive => tipo == 'masiva';
  bool get isIndividual => tipo == 'individual';

  bool appliesTo({
    required String periodo,
    required String codigoUsuario,
  }) {
    final matchesPeriod = siempre || this.periodo == periodo;
    if (!matchesPeriod) {
      return false;
    }
    if (isMassive) {
      return true;
    }
    return this.codigoUsuario == codigoUsuario;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'descripcion': descripcion,
      'tipo': tipo,
      'siempre': siempre,
      'codigoUsuario': codigoUsuario,
      'nombreUsuario': nombreUsuario,
      'periodo': periodo,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': fechaActualizacion == null
          ? null
          : Timestamp.fromDate(fechaActualizacion!),
    };
  }

  factory BillingObservation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return BillingObservation(
      id: doc.id,
      descripcion: data['descripcion'] as String? ?? '',
      tipo: data['tipo'] as String? ?? 'masiva',
      siempre: data['siempre'] as bool? ?? false,
      codigoUsuario: data['codigoUsuario'] as String?,
      nombreUsuario: data['nombreUsuario'] as String?,
      periodo: data['periodo'] as String?,
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
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
