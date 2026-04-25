import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumptionHistoryEntry {
  const ConsumptionHistoryEntry({
    required this.id,
    required this.tipoEvento,
    required this.actorUid,
    required this.actorNombre,
    required this.actorRol,
    required this.fecha,
    this.estadoAnterior,
    this.estadoNuevo,
    this.valorAnterior,
    this.valorNuevo,
    this.motivo,
    this.observaciones,
    this.periodosImpactados = const [],
  });

  final String id;
  final String tipoEvento;
  final String actorUid;
  final String actorNombre;
  final String actorRol;
  final DateTime fecha;
  final String? estadoAnterior;
  final String? estadoNuevo;
  final int? valorAnterior;
  final int? valorNuevo;
  final String? motivo;
  final String? observaciones;
  final List<String> periodosImpactados;

  Map<String, dynamic> toFirestore() {
    return {
      'tipoEvento': tipoEvento,
      'actorUid': actorUid,
      'actorNombre': actorNombre,
      'actorRol': actorRol,
      'fecha': Timestamp.fromDate(fecha),
      'estadoAnterior': estadoAnterior,
      'estadoNuevo': estadoNuevo,
      'valorAnterior': valorAnterior,
      'valorNuevo': valorNuevo,
      'motivo': motivo,
      'observaciones': observaciones,
      'periodosImpactados': periodosImpactados,
    };
  }

  factory ConsumptionHistoryEntry.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDate = data['fecha'];
    return ConsumptionHistoryEntry(
      id: id,
      tipoEvento: data['tipoEvento'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorNombre: data['actorNombre'] as String? ?? '',
      actorRol: data['actorRol'] as String? ?? '',
      fecha: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      estadoAnterior: data['estadoAnterior'] as String?,
      estadoNuevo: data['estadoNuevo'] as String?,
      valorAnterior: data['valorAnterior'] as int?,
      valorNuevo: data['valorNuevo'] as int?,
      motivo: data['motivo'] as String?,
      observaciones: data['observaciones'] as String?,
      periodosImpactados: (data['periodosImpactados'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}
