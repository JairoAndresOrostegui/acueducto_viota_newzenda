import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumptionRange {
  const ConsumptionRange({
    required this.desde,
    required this.hasta,
    required this.valorUnitario,
  });

  final int desde;
  final int? hasta;
  final int valorUnitario;

  Map<String, dynamic> toMap() {
    return {
      'desde': desde,
      'hasta': hasta,
      'valorUnitario': valorUnitario,
    };
  }

  factory ConsumptionRange.fromMap(Map<String, dynamic> data) {
    return ConsumptionRange(
      desde: data['desde'] as int? ?? 0,
      hasta: data['hasta'] as int?,
      valorUnitario: data['valorUnitario'] as int? ?? 0,
    );
  }
}

class AdditionalBillingValue {
  const AdditionalBillingValue({
    required this.periodoId,
    required this.periodoNombre,
    required this.concepto,
    required this.valor,
    this.codigoUsuario,
  });

  final String periodoId;
  final String periodoNombre;
  final String concepto;
  final int valor;
  final String? codigoUsuario;

  bool get isMassive => (codigoUsuario ?? '').trim().isEmpty;

  bool appliesTo({
    required String periodId,
    required String userCode,
  }) {
    if (periodoId.trim() != periodId.trim()) {
      return false;
    }
    final code = (codigoUsuario ?? '').trim().toUpperCase();
    return code.isEmpty || code == userCode.trim().toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'periodoId': periodoId,
      'periodoNombre': periodoNombre,
      'concepto': concepto,
      'valor': valor,
      'codigoUsuario': codigoUsuario,
    };
  }

  factory AdditionalBillingValue.fromMap(Map<String, dynamic> data) {
    return AdditionalBillingValue(
      periodoId: data['periodoId'] as String? ?? '',
      periodoNombre: data['periodoNombre'] as String? ?? '',
      concepto: data['concepto'] as String? ?? '',
      valor: data['valor'] as int? ?? 0,
      codigoUsuario: data['codigoUsuario'] as String?,
    );
  }
}

class BillingValueConfig {
  const BillingValueConfig({
    required this.id,
    required this.estado,
    required this.version,
    required this.cargoFijo,
    required this.reconexion,
    required this.rangos,
    this.valoresAdicionales = const [],
    required this.actorUid,
    required this.actorNombre,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  final String id;
  final String estado;
  final int version;
  final int cargoFijo;
  final int reconexion;
  final List<ConsumptionRange> rangos;
  final List<AdditionalBillingValue> valoresAdicionales;
  final String actorUid;
  final String actorNombre;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  bool get isActive => estado == 'activo';

  factory BillingValueConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final ranges = (data['rangos'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ConsumptionRange.fromMap)
        .toList();
    final additionalValues =
        (data['valoresAdicionales'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AdditionalBillingValue.fromMap)
            .where(
              (item) =>
                  item.periodoId.trim().isNotEmpty &&
                  item.concepto.trim().isNotEmpty &&
                  item.valor > 0,
            )
            .toList();

    return BillingValueConfig(
      id: doc.id,
      estado: data['estado'] as String? ?? 'activo',
      version: data['version'] as int? ?? 1,
      cargoFijo: data['cargoFijo'] as int? ?? 0,
      reconexion: data['reconexion'] as int? ?? 0,
      rangos: ranges,
      valoresAdicionales: additionalValues,
      actorUid: data['actorUid'] as String? ?? '',
      actorNombre: data['actorNombre'] as String? ?? '',
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
      fechaActualizacion: _toDateTime(data['fechaActualizacion']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'estado': estado,
      'version': version,
      'cargoFijo': cargoFijo,
      'reconexion': reconexion,
      'rangos': rangos.map((item) => item.toMap()).toList(),
      'valoresAdicionales':
          valoresAdicionales.map((item) => item.toMap()).toList(),
      'actorUid': actorUid,
      'actorNombre': actorNombre,
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
