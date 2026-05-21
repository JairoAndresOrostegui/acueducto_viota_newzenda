import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.periodoId,
    required this.periodoNombre,
    required this.conceptoId,
    required this.conceptoNombre,
    required this.valor,
    required this.fechaGasto,
    required this.pagadoANombre,
    required this.pagadoAIdentificacion,
    required this.registradoPorUid,
    required this.registradoPorNombre,
    required this.fechaRegistro,
    this.actualizadoPorUid,
    this.actualizadoPorNombre,
    this.fechaActualizacion,
  });

  final String id;
  final String periodoId;
  final String periodoNombre;
  final String conceptoId;
  final String conceptoNombre;
  final int valor;
  final DateTime fechaGasto;
  final String pagadoANombre;
  final String pagadoAIdentificacion;
  final String registradoPorUid;
  final String registradoPorNombre;
  final DateTime fechaRegistro;
  final String? actualizadoPorUid;
  final String? actualizadoPorNombre;
  final DateTime? fechaActualizacion;

  ExpenseRecord copyWith({
    String? periodoId,
    String? periodoNombre,
    String? conceptoId,
    String? conceptoNombre,
    int? valor,
    DateTime? fechaGasto,
    String? pagadoANombre,
    String? pagadoAIdentificacion,
    String? actualizadoPorUid,
    String? actualizadoPorNombre,
    DateTime? fechaActualizacion,
  }) {
    return ExpenseRecord(
      id: id,
      periodoId: periodoId ?? this.periodoId,
      periodoNombre: periodoNombre ?? this.periodoNombre,
      conceptoId: conceptoId ?? this.conceptoId,
      conceptoNombre: conceptoNombre ?? this.conceptoNombre,
      valor: valor ?? this.valor,
      fechaGasto: fechaGasto ?? this.fechaGasto,
      pagadoANombre: pagadoANombre ?? this.pagadoANombre,
      pagadoAIdentificacion:
          pagadoAIdentificacion ?? this.pagadoAIdentificacion,
      registradoPorUid: registradoPorUid,
      registradoPorNombre: registradoPorNombre,
      fechaRegistro: fechaRegistro,
      actualizadoPorUid: actualizadoPorUid ?? this.actualizadoPorUid,
      actualizadoPorNombre:
          actualizadoPorNombre ?? this.actualizadoPorNombre,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'periodoId': periodoId,
      'periodoNombre': periodoNombre,
      'conceptoId': conceptoId,
      'conceptoNombre': conceptoNombre,
      'valor': valor,
      'fechaGasto': Timestamp.fromDate(fechaGasto),
      'pagadoANombre': pagadoANombre,
      'pagadoAIdentificacion': pagadoAIdentificacion,
      'registradoPorUid': registradoPorUid,
      'registradoPorNombre': registradoPorNombre,
      'fechaRegistro': Timestamp.fromDate(fechaRegistro),
      'actualizadoPorUid': actualizadoPorUid,
      'actualizadoPorNombre': actualizadoPorNombre,
      'fechaActualizacion': fechaActualizacion == null
          ? null
          : Timestamp.fromDate(fechaActualizacion!),
    };
  }

  factory ExpenseRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExpenseRecord(
      id: data['id'] as String? ?? doc.id,
      periodoId: data['periodoId'] as String? ?? '',
      periodoNombre: data['periodoNombre'] as String? ?? '',
      conceptoId: data['conceptoId'] as String? ?? '',
      conceptoNombre: data['conceptoNombre'] as String? ?? '',
      valor: data['valor'] as int? ?? 0,
      fechaGasto: _toDateTime(data['fechaGasto']) ?? DateTime.now(),
      pagadoANombre: data['pagadoANombre'] as String? ?? '',
      pagadoAIdentificacion: data['pagadoAIdentificacion'] as String? ?? '',
      registradoPorUid: data['registradoPorUid'] as String? ?? '',
      registradoPorNombre: data['registradoPorNombre'] as String? ?? '',
      fechaRegistro: _toDateTime(data['fechaRegistro']) ?? DateTime.now(),
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
