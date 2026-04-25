import 'package:cloud_firestore/cloud_firestore.dart';

import 'consumption_irregularity.dart';

class ConsumptionReading {
  static const Object _sentinel = Object();

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
    required this.lecturaAnterior,
    required this.consumoCalculado,
    required this.facturado,
    required this.pagado,
    this.conflictoId,
    this.detalleEstado,
    this.observacionesOperario,
    this.observacionesAdmin,
    this.reciboId,
    this.irregularidad,
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
  final int? lecturaAnterior;
  final int? consumoCalculado;
  final bool facturado;
  final bool pagado;
  final String? conflictoId;
  final String? detalleEstado;
  final String? observacionesOperario;
  final String? observacionesAdmin;
  final String? reciboId;
  final ConsumptionIrregularity? irregularidad;

  bool get isSynced => estado == 'sincronizado';
  bool get isBlocked => estado == 'bloqueado';
  bool get isEditableByAdmin => !pagado;
  bool get hasIrregularity => irregularidad != null;

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
      'lecturaAnterior': lecturaAnterior,
      'consumoCalculado': consumoCalculado,
      'facturado': facturado,
      'pagado': pagado,
      'conflictoId': conflictoId,
      'detalleEstado': detalleEstado,
      'observacionesOperario': observacionesOperario,
      'observacionesAdmin': observacionesAdmin,
      'reciboId': reciboId,
      'irregularidad': irregularidad?.toMap(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
      'lecturaActual': lecturaActual,
      'periodoActual': periodoActual,
      'fecha': Timestamp.fromDate(fecha),
      'nombreOperario': nombreOperario,
      'actorUid': actorUid,
      'estado': estado,
      'lecturaAnterior': lecturaAnterior,
      'consumoCalculado': consumoCalculado,
      'facturado': facturado,
      'pagado': pagado,
      'conflictoId': conflictoId,
      'detalleEstado': detalleEstado,
      'observacionesOperario': observacionesOperario,
      'observacionesAdmin': observacionesAdmin,
      'reciboId': reciboId,
      'irregularidad': irregularidad?.toMap(),
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
      estado: data['estado'] as String? ?? 'pendiente_local',
      lecturaAnterior: data['lecturaAnterior'] as int?,
      consumoCalculado: data['consumoCalculado'] as int?,
      facturado: data['facturado'] as bool? ?? false,
      pagado: data['pagado'] as bool? ?? false,
      conflictoId: data['conflictoId'] as String?,
      detalleEstado: data['detalleEstado'] as String?,
      observacionesOperario: data['observacionesOperario'] as String?,
      observacionesAdmin: data['observacionesAdmin'] as String?,
      reciboId: data['reciboId'] as String?,
      irregularidad: _irregularityFromDynamic(data['irregularidad']),
    );
  }

  factory ConsumptionReading.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final fecha = data['fecha'];
    final resolvedId =
        data['id'] as String? ??
        '${data['periodoActual'] as String? ?? ''}|${data['codigoContador'] as String? ?? id}';
    return ConsumptionReading(
      id: resolvedId,
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      lecturaActual: data['lecturaActual'] as int? ?? 0,
      periodoActual: data['periodoActual'] as String? ?? '',
      fecha: fecha is Timestamp ? fecha.toDate() : DateTime.now(),
      nombreOperario: data['nombreOperario'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      estado: data['estado'] as String? ?? 'sincronizado',
      lecturaAnterior: data['lecturaAnterior'] as int?,
      consumoCalculado: data['consumoCalculado'] as int?,
      facturado: data['facturado'] as bool? ?? false,
      pagado: data['pagado'] as bool? ?? false,
      conflictoId: data['conflictoId'] as String?,
      detalleEstado: data['detalleEstado'] as String?,
      observacionesOperario: data['observacionesOperario'] as String?,
      observacionesAdmin: data['observacionesAdmin'] as String?,
      reciboId: data['reciboId'] as String?,
      irregularidad: _irregularityFromDynamic(data['irregularidad']),
    );
  }

  ConsumptionReading copyWith({
    int? lecturaActual,
    String? estado,
    DateTime? fecha,
    String? nombreOperario,
    String? actorUid,
    Object? conflictoId = _sentinel,
    Object? detalleEstado = _sentinel,
    int? lecturaAnterior,
    int? consumoCalculado,
    bool? facturado,
    bool? pagado,
    Object? observacionesOperario = _sentinel,
    Object? observacionesAdmin = _sentinel,
    Object? reciboId = _sentinel,
    Object? irregularidad = _sentinel,
  }) {
    return ConsumptionReading(
      id: id,
      codigoUsuario: codigoUsuario,
      codigoContador: codigoContador,
      nombreUsuario: nombreUsuario,
      lecturaActual: lecturaActual ?? this.lecturaActual,
      periodoActual: periodoActual,
      fecha: fecha ?? this.fecha,
      nombreOperario: nombreOperario ?? this.nombreOperario,
      actorUid: actorUid ?? this.actorUid,
      estado: estado ?? this.estado,
      lecturaAnterior: lecturaAnterior ?? this.lecturaAnterior,
      consumoCalculado: consumoCalculado ?? this.consumoCalculado,
      facturado: facturado ?? this.facturado,
      pagado: pagado ?? this.pagado,
      conflictoId: identical(conflictoId, _sentinel)
          ? this.conflictoId
          : conflictoId as String?,
      detalleEstado: identical(detalleEstado, _sentinel)
          ? this.detalleEstado
          : detalleEstado as String?,
      observacionesOperario: identical(observacionesOperario, _sentinel)
          ? this.observacionesOperario
          : observacionesOperario as String?,
      observacionesAdmin: identical(observacionesAdmin, _sentinel)
          ? this.observacionesAdmin
          : observacionesAdmin as String?,
      reciboId: identical(reciboId, _sentinel)
          ? this.reciboId
          : reciboId as String?,
      irregularidad: identical(irregularidad, _sentinel)
          ? this.irregularidad
          : irregularidad as ConsumptionIrregularity?,
    );
  }

  static ConsumptionIrregularity? _irregularityFromDynamic(Object? value) {
    if (value is! Map) {
      return null;
    }
    return ConsumptionIrregularity.fromMap(Map<String, dynamic>.from(value));
  }
}
