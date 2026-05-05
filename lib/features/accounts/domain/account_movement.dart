import 'package:cloud_firestore/cloud_firestore.dart';

class AccountMovement {
  const AccountMovement({
    required this.id,
    required this.tipo,
    required this.codigoUsuario,
    required this.codigoContador,
    required this.nombreUsuario,
    required this.sector,
    required this.periodo,
    required this.valor,
    required this.descripcion,
    required this.fecha,
    required this.actorUid,
    required this.actorNombre,
    this.reciboId,
    this.medioPagoId,
    this.medioPagoDescripcion,
    this.observaciones,
  });

  final String id;
  final String tipo;
  final String codigoUsuario;
  final String codigoContador;
  final String nombreUsuario;
  final String sector;
  final String periodo;
  final int valor;
  final String descripcion;
  final DateTime fecha;
  final String actorUid;
  final String actorNombre;
  final String? reciboId;
  final String? medioPagoId;
  final String? medioPagoDescripcion;
  final String? observaciones;

  bool get isDebit => valor > 0;
  bool get isCredit => valor < 0;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'tipo': tipo,
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
      'sector': sector,
      'periodo': periodo,
      'valor': valor,
      'descripcion': descripcion,
      'fecha': Timestamp.fromDate(fecha),
      'actorUid': actorUid,
      'actorNombre': actorNombre,
      'reciboId': reciboId,
      'medioPagoId': medioPagoId,
      'medioPagoDescripcion': medioPagoDescripcion,
      'observaciones': observaciones,
    };
  }

  factory AccountMovement.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final fecha = data['fecha'];
    return AccountMovement(
      id: data['id'] as String? ?? id,
      tipo: data['tipo'] as String? ?? '',
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      sector: data['sector'] as String? ?? '',
      periodo: data['periodo'] as String? ?? '',
      valor: data['valor'] as int? ?? 0,
      descripcion: data['descripcion'] as String? ?? '',
      fecha: fecha is Timestamp ? fecha.toDate() : DateTime.now(),
      actorUid: data['actorUid'] as String? ?? '',
      actorNombre: data['actorNombre'] as String? ?? '',
      reciboId: data['reciboId'] as String?,
      medioPagoId: data['medioPagoId'] as String?,
      medioPagoDescripcion: data['medioPagoDescripcion'] as String?,
      observaciones: data['observaciones'] as String?,
    );
  }
}
