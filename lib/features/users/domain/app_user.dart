import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.nombre,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.numeroContacto,
    required this.codigoUsuario,
    required this.numeroContador,
    required this.rol,
    required this.sector,
    required this.correo,
    required this.estado,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  final String uid;
  final String nombre;
  final String tipoDocumento;
  final String numeroDocumento;
  final String numeroContacto;
  final String codigoUsuario;
  final String numeroContador;
  final String rol;
  final String sector;
  final String correo;
  final String estado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  bool get isAdmin => rol == 'administrador';
  bool get isClient => rol == 'cliente';

  String get nombreCorto {
    final parts = nombre.trim().split(RegExp(r'\s+'));
    if (parts.length <= 2) {
      return nombre;
    }
    return '${parts.first} ${parts[1]}';
  }

  AppUser copyWith({
    String? uid,
    String? nombre,
    String? tipoDocumento,
    String? numeroDocumento,
    String? numeroContacto,
    String? codigoUsuario,
    String? numeroContador,
    String? rol,
    String? sector,
    String? correo,
    String? estado,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      numeroContacto: numeroContacto ?? this.numeroContacto,
      codigoUsuario: codigoUsuario ?? this.codigoUsuario,
      numeroContador: numeroContador ?? this.numeroContador,
      rol: rol ?? this.rol,
      sector: sector ?? this.sector,
      correo: correo ?? this.correo,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      nombre: data['nombre'] as String? ?? '',
      tipoDocumento: data['tipoDocumento'] as String? ?? '',
      numeroDocumento: data['numeroDocumento'] as String? ?? '',
      numeroContacto: data['numeroContacto'] as String? ?? '',
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      numeroContador: data['numeroContador'] as String? ?? '',
      rol: data['rol'] as String? ?? '',
      sector: data['sector'] as String? ?? '',
      correo: data['correo'] as String? ?? '',
      estado: data['estado'] as String? ?? '',
      fechaCreacion: _toDateTime(data['fechaCreacion']) ?? DateTime.now(),
      fechaActualizacion: _toDateTime(data['fechaActualizacion']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      ...toPlainMap(),
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': fechaActualizacion == null
          ? null
          : Timestamp.fromDate(fechaActualizacion!),
    };
  }

  Map<String, dynamic> toPlainMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'tipoDocumento': tipoDocumento,
      'numeroDocumento': numeroDocumento,
      'numeroContacto': numeroContacto,
      'codigoUsuario': codigoUsuario,
      'numeroContador': numeroContador,
      'rol': rol,
      'sector': sector,
      'correo': correo,
      'estado': estado,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
