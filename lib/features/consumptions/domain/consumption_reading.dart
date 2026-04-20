import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumptionReading {
  const ConsumptionReading({
    required this.id,
    required this.codigoUsuario,
    required this.codigoContador,
    required this.nombreUsuario,
    required this.lecturaActual,
    required this.periodoActual,
    required this.fecha,
    required this.nombreOperario,
    required this.actorUid,
    required this.estado,
  });

  final String id;
  final String codigoUsuario;
  final String codigoContador;
  final String nombreUsuario;
  final int lecturaActual;
  final String periodoActual;
  final DateTime fecha;
  final String nombreOperario;
  final String actorUid;
  final String estado;

  bool get isSynced => estado == 'sincronizado';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
      'lecturaActual': lecturaActual,
      'periodoActual': periodoActual,
      'fecha': fecha.toIso8601String(),
      'nombreOperario': nombreOperario,
      'actorUid': actorUid,
      'estado': estado,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
      'lecturaActual': lecturaActual,
      'periodoActual': periodoActual,
      'fecha': Timestamp.fromDate(fecha),
      'nombreOperario': nombreOperario,
      'actorUid': actorUid,
      'estado': estado,
    };
  }

  factory ConsumptionReading.fromMap(Map<String, dynamic> data) {
    return ConsumptionReading(
      id: data['id'] as String? ?? '',
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      lecturaActual: data['lecturaActual'] as int? ?? 0,
      periodoActual: data['periodoActual'] as String? ?? '',
      fecha: DateTime.tryParse(data['fecha'] as String? ?? '') ?? DateTime.now(),
      nombreOperario: data['nombreOperario'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      estado: data['estado'] as String? ?? 'pendiente',
    );
  }

  factory ConsumptionReading.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final fecha = data['fecha'];
    return ConsumptionReading(
      id: id,
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      lecturaActual: data['lecturaActual'] as int? ?? 0,
      periodoActual: data['periodoActual'] as String? ?? '',
      fecha: fecha is Timestamp ? fecha.toDate() : DateTime.now(),
      nombreOperario: data['nombreOperario'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      estado: data['estado'] as String? ?? 'sincronizado',
    );
  }

  ConsumptionReading copyWith({
    String? estado,
    DateTime? fecha,
  }) {
    return ConsumptionReading(
      id: id,
      codigoUsuario: codigoUsuario,
      codigoContador: codigoContador,
      nombreUsuario: nombreUsuario,
      lecturaActual: lecturaActual,
      periodoActual: periodoActual,
      fecha: fecha ?? this.fecha,
      nombreOperario: nombreOperario,
      actorUid: actorUid,
      estado: estado ?? this.estado,
    );
  }
}
