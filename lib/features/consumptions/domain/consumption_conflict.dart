import 'package:cloud_firestore/cloud_firestore.dart';

import 'consumption_reading.dart';

class ConsumptionConflict {
  const ConsumptionConflict({
    required this.id,
    required this.lecturaId,
    required this.lecturaPropuesta,
    required this.motivo,
    required this.mensaje,
    required this.estado,
    required this.fecha,
    this.lecturaExistente,
    this.lecturaAnterior,
    this.lecturaFinal,
    this.resueltoPorUid,
    this.resueltoPorNombre,
    this.fechaResolucion,
  });

  final String id;
  final String lecturaId;
  final ConsumptionReading lecturaPropuesta;
  final ConsumptionReading? lecturaExistente;
  final ConsumptionReading? lecturaAnterior;
  final ConsumptionReading? lecturaFinal;
  final String motivo;
  final String mensaje;
  final String estado;
  final DateTime fecha;
  final String? resueltoPorUid;
  final String? resueltoPorNombre;
  final DateTime? fechaResolucion;

  bool get isResolved => estado == 'resuelto';

  Map<String, dynamic> toFirestore() {
    return {
      'lecturaId': lecturaId,
      'lecturaPropuesta': lecturaPropuesta.toMap(),
      'lecturaExistente': lecturaExistente?.toMap(),
      'lecturaAnterior': lecturaAnterior?.toMap(),
      'lecturaFinal': lecturaFinal?.toMap(),
      'motivo': motivo,
      'mensaje': mensaje,
      'estado': estado,
      'fecha': Timestamp.fromDate(fecha),
      'resueltoPorUid': resueltoPorUid,
      'resueltoPorNombre': resueltoPorNombre,
      'fechaResolucion': fechaResolucion == null
          ? null
          : Timestamp.fromDate(fechaResolucion!),
      'actorUid': lecturaPropuesta.actorUid,
      'codigoUsuario': lecturaPropuesta.codigoUsuario,
      'codigoContador': lecturaPropuesta.codigoContador,
      'nombreUsuario': lecturaPropuesta.nombreUsuario,
      'periodoActual': lecturaPropuesta.periodoActual,
    };
  }

  factory ConsumptionConflict.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final createdAt = data['fecha'];
    final resolvedAt = data['fechaResolucion'];
    return ConsumptionConflict(
      id: id,
      lecturaId: data['lecturaId'] as String? ?? '',
      lecturaPropuesta: _readingFromDynamic(data['lecturaPropuesta']),
      lecturaExistente: _readingFromDynamicOrNull(data['lecturaExistente']),
      lecturaAnterior: _readingFromDynamicOrNull(data['lecturaAnterior']),
      lecturaFinal: _readingFromDynamicOrNull(data['lecturaFinal']),
      motivo: data['motivo'] as String? ?? '',
      mensaje: data['mensaje'] as String? ?? '',
      estado: data['estado'] as String? ?? 'pendiente',
      fecha: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      resueltoPorUid: data['resueltoPorUid'] as String?,
      resueltoPorNombre: data['resueltoPorNombre'] as String?,
      fechaResolucion: resolvedAt is Timestamp ? resolvedAt.toDate() : null,
    );
  }

  ConsumptionConflict copyWith({
    ConsumptionReading? lecturaFinal,
    String? estado,
    String? resueltoPorUid,
    String? resueltoPorNombre,
    DateTime? fechaResolucion,
  }) {
    return ConsumptionConflict(
      id: id,
      lecturaId: lecturaId,
      lecturaPropuesta: lecturaPropuesta,
      lecturaExistente: lecturaExistente,
      lecturaAnterior: lecturaAnterior,
      lecturaFinal: lecturaFinal ?? this.lecturaFinal,
      motivo: motivo,
      mensaje: mensaje,
      estado: estado ?? this.estado,
      fecha: fecha,
      resueltoPorUid: resueltoPorUid ?? this.resueltoPorUid,
      resueltoPorNombre: resueltoPorNombre ?? this.resueltoPorNombre,
      fechaResolucion: fechaResolucion ?? this.fechaResolucion,
    );
  }

  static ConsumptionReading _readingFromDynamic(Object? value) {
    return ConsumptionReading.fromMap(
      Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
    );
  }

  static ConsumptionReading? _readingFromDynamicOrNull(Object? value) {
    if (value is! Map) {
      return null;
    }
    return ConsumptionReading.fromMap(Map<String, dynamic>.from(value));
  }
}
