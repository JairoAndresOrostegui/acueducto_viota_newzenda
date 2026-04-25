import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.descripcion,
    required this.valorUnitario,
    required this.cantidad,
    required this.valorTotal,
  });

  final String descripcion;
  final int valorUnitario;
  final int cantidad;
  final int valorTotal;

  Map<String, dynamic> toMap() {
    return {
      'descripcion': descripcion,
      'valorUnitario': valorUnitario,
      'cantidad': cantidad,
      'valorTotal': valorTotal,
    };
  }

  factory InvoiceLineItem.fromMap(Map<String, dynamic> data) {
    return InvoiceLineItem(
      descripcion: data['descripcion'] as String? ?? '',
      valorUnitario: data['valorUnitario'] as int? ?? 0,
      cantidad: data['cantidad'] as int? ?? 0,
      valorTotal: data['valorTotal'] as int? ?? 0,
    );
  }
}

class InvoiceAppliedObservation {
  const InvoiceAppliedObservation({
    required this.id,
    required this.descripcion,
    required this.tipo,
    this.periodo,
    this.codigoUsuario,
    this.nombreUsuario,
    this.siempre = false,
  });

  final String id;
  final String descripcion;
  final String tipo;
  final String? periodo;
  final String? codigoUsuario;
  final String? nombreUsuario;
  final bool siempre;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descripcion': descripcion,
      'tipo': tipo,
      'periodo': periodo,
      'codigoUsuario': codigoUsuario,
      'nombreUsuario': nombreUsuario,
      'siempre': siempre,
    };
  }

  factory InvoiceAppliedObservation.fromMap(Map<String, dynamic> data) {
    return InvoiceAppliedObservation(
      id: data['id'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      tipo: data['tipo'] as String? ?? 'masiva',
      periodo: data['periodo'] as String?,
      codigoUsuario: data['codigoUsuario'] as String?,
      nombreUsuario: data['nombreUsuario'] as String?,
      siempre: data['siempre'] as bool? ?? false,
    );
  }
}

class Invoice {
  const Invoice({
    required this.id,
    required this.periodo,
    required this.codigoUsuario,
    required this.codigoContador,
    required this.nombreUsuario,
    required this.sector,
    required this.lecturaAnterior,
    required this.lecturaActual,
    required this.consumoM3,
    required this.fechaGeneracion,
    required this.fechaVencimiento,
    required this.cargoFijo,
    required this.reconexion,
    required this.saldoAnterior,
    required this.lineas,
    required this.mediosPagoTexto,
    required this.mediosPago,
    required this.estado,
    required this.valorConfigId,
    required this.valorConfigVersion,
    required this.total,
    required this.pagado,
    required this.valorPagado,
    required this.actorUid,
    required this.actorNombre,
    required this.observaciones,
    this.fechaPago,
    this.medioPagoId,
    this.medioPagoDescripcion,
    this.observacionesPago,
    this.estadoPeriodoAnterior,
    this.avisoFacturacion,
    this.mensaje,
  });

  final String id;
  final String periodo;
  final String codigoUsuario;
  final String codigoContador;
  final String nombreUsuario;
  final String sector;
  final int? lecturaAnterior;
  final int lecturaActual;
  final int consumoM3;
  final DateTime fechaGeneracion;
  final DateTime fechaVencimiento;
  final int cargoFijo;
  final int reconexion;
  final int saldoAnterior;
  final List<InvoiceLineItem> lineas;
  final String mediosPagoTexto;
  final List<String> mediosPago;
  final String estado;
  final String valorConfigId;
  final int valorConfigVersion;
  final int total;
  final bool pagado;
  final int? valorPagado;
  final DateTime? fechaPago;
  final String? medioPagoId;
  final String? medioPagoDescripcion;
  final String? observacionesPago;
  final String actorUid;
  final String actorNombre;
  final List<InvoiceAppliedObservation> observaciones;
  final String? estadoPeriodoAnterior;
  final String? avisoFacturacion;
  final String? mensaje;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'periodo': periodo,
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
      'sector': sector,
      'lecturaAnterior': lecturaAnterior,
      'lecturaActual': lecturaActual,
      'consumoM3': consumoM3,
      'fechaGeneracion': Timestamp.fromDate(fechaGeneracion),
      'fechaVencimiento': Timestamp.fromDate(fechaVencimiento),
      'cargoFijo': cargoFijo,
      'reconexion': reconexion,
      'saldoAnterior': saldoAnterior,
      'lineas': lineas.map((item) => item.toMap()).toList(),
      'mediosPagoTexto': mediosPagoTexto,
      'mediosPago': mediosPago,
      'estado': estado,
      'valorConfigId': valorConfigId,
      'valorConfigVersion': valorConfigVersion,
      'total': total,
      'pagado': pagado,
      'valorPagado': valorPagado,
      'fechaPago': fechaPago == null ? null : Timestamp.fromDate(fechaPago!),
      'medioPagoId': medioPagoId,
      'medioPagoDescripcion': medioPagoDescripcion,
      'observacionesPago': observacionesPago,
      'actorUid': actorUid,
      'actorNombre': actorNombre,
      'observaciones':
          observaciones.map((item) => item.toMap()).toList(),
      'estadoPeriodoAnterior': estadoPeriodoAnterior,
      'avisoFacturacion': avisoFacturacion,
      'mensaje': mensaje,
    };
  }

  factory Invoice.fromFirestore(String id, Map<String, dynamic> data) {
    return Invoice(
      id: data['id'] as String? ?? id,
      periodo: data['periodo'] as String? ?? '',
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      sector: data['sector'] as String? ?? '',
      lecturaAnterior: data['lecturaAnterior'] as int?,
      lecturaActual: data['lecturaActual'] as int? ?? 0,
      consumoM3: data['consumoM3'] as int? ?? 0,
      fechaGeneracion: _toDateTime(data['fechaGeneracion']) ?? DateTime.now(),
      fechaVencimiento: _toDateTime(data['fechaVencimiento']) ?? DateTime.now(),
      cargoFijo: data['cargoFijo'] as int? ?? 0,
      reconexion: data['reconexion'] as int? ?? 0,
      saldoAnterior: data['saldoAnterior'] as int? ?? 0,
      lineas: (data['lineas'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceLineItem.fromMap)
          .toList(),
      mediosPagoTexto: data['mediosPagoTexto'] as String? ?? '',
      mediosPago: (data['mediosPago'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      estado: data['estado'] as String? ??
          ((data['pagado'] as bool? ?? false) ? 'pagado' : 'facturado'),
      valorConfigId: data['valorConfigId'] as String? ?? '',
      valorConfigVersion: data['valorConfigVersion'] as int? ?? 0,
      total: data['total'] as int? ?? 0,
      pagado: data['pagado'] as bool? ?? false,
      valorPagado: data['valorPagado'] as int?,
      fechaPago: _toDateTime(data['fechaPago']),
      medioPagoId: data['medioPagoId'] as String?,
      medioPagoDescripcion: data['medioPagoDescripcion'] as String?,
      observacionesPago: data['observacionesPago'] as String?,
      actorUid: data['actorUid'] as String? ?? '',
      actorNombre: data['actorNombre'] as String? ?? '',
      observaciones: (data['observaciones'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceAppliedObservation.fromMap)
          .toList(),
      estadoPeriodoAnterior: data['estadoPeriodoAnterior'] as String?,
      avisoFacturacion: data['avisoFacturacion'] as String?,
      mensaje: data['mensaje'] as String?,
    );
  }

  Invoice copyWith({
    String? estado,
    bool? pagado,
    int? valorPagado,
    Object? avisoFacturacion = _sentinel,
    Object? fechaPago = _sentinel,
    Object? medioPagoId = _sentinel,
    Object? medioPagoDescripcion = _sentinel,
    Object? observacionesPago = _sentinel,
  }) {
    return Invoice(
      id: id,
      periodo: periodo,
      codigoUsuario: codigoUsuario,
      codigoContador: codigoContador,
      nombreUsuario: nombreUsuario,
      sector: sector,
      lecturaAnterior: lecturaAnterior,
      lecturaActual: lecturaActual,
      consumoM3: consumoM3,
      fechaGeneracion: fechaGeneracion,
      fechaVencimiento: fechaVencimiento,
      cargoFijo: cargoFijo,
      reconexion: reconexion,
      saldoAnterior: saldoAnterior,
      lineas: lineas,
      mediosPagoTexto: mediosPagoTexto,
      mediosPago: mediosPago,
      estado: estado ?? this.estado,
      valorConfigId: valorConfigId,
      valorConfigVersion: valorConfigVersion,
      total: total,
      pagado: pagado ?? this.pagado,
      valorPagado: valorPagado ?? this.valorPagado,
      fechaPago: identical(fechaPago, _sentinel)
          ? this.fechaPago
          : fechaPago as DateTime?,
      medioPagoId: identical(medioPagoId, _sentinel)
          ? this.medioPagoId
          : medioPagoId as String?,
      medioPagoDescripcion: identical(medioPagoDescripcion, _sentinel)
          ? this.medioPagoDescripcion
          : medioPagoDescripcion as String?,
      observacionesPago: identical(observacionesPago, _sentinel)
          ? this.observacionesPago
          : observacionesPago as String?,
      actorUid: actorUid,
      actorNombre: actorNombre,
      observaciones: observaciones,
      estadoPeriodoAnterior: estadoPeriodoAnterior,
      avisoFacturacion: identical(avisoFacturacion, _sentinel)
          ? this.avisoFacturacion
          : avisoFacturacion as String?,
      mensaje: mensaje,
    );
  }

  static const Object _sentinel = Object();

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
