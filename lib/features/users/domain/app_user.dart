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
    required this.codigosUsuario,
    required this.rol,
    required this.tipoCliente,
    required this.sector,
    required this.correo,
    required this.estado,
    required this.superAdmin,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  final String uid;
  final String nombre;
  final String tipoDocumento;
  final String numeroDocumento;
  final String numeroContacto;
  final String codigoUsuario;
  final List<String> numeroContador;
  final List<ClientUserCode> codigosUsuario;
  final String rol;
  final String tipoCliente;
  final String sector;
  final String correo;
  final String estado;
  final bool superAdmin;
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
    List<String>? numeroContador,
    List<ClientUserCode>? codigosUsuario,
    String? rol,
    String? tipoCliente,
    String? sector,
    String? correo,
    String? estado,
    bool? superAdmin,
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
      codigosUsuario: codigosUsuario ?? this.codigosUsuario,
      rol: rol ?? this.rol,
      tipoCliente: tipoCliente ?? this.tipoCliente,
      sector: sector ?? this.sector,
      correo: correo ?? this.correo,
      estado: estado ?? this.estado,
      superAdmin: superAdmin ?? this.superAdmin,
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
      numeroContador: _toMeterList(data['numeroContador']),
      codigosUsuario: _toClientCodes(data),
      rol: data['rol'] as String? ?? '',
      tipoCliente: data['tipoCliente'] as String? ?? 'na',
      sector: data['sector'] as String? ?? '',
      correo: data['correo'] as String? ?? '',
      estado: data['estado'] as String? ?? '',
      superAdmin: data['superAdmin'] == true,
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
      'codigosUsuario': codigosUsuario.map((item) => item.toMap()).toList(),
      'codigosUsuarioValores': codigosUsuario
          .map((item) => item.codigoUsuario)
          .where((item) => item.isNotEmpty && item.toLowerCase() != 'na')
          .toSet()
          .toList(),
      'rol': rol,
      'tipoCliente': tipoCliente,
      'sector': sector,
      'correo': correo,
      'estado': estado,
      'superAdmin': superAdmin,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  static List<String> _toMeterList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item.toLowerCase() != 'na')
          .toList();
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty || normalized.toLowerCase() == 'na') {
        return const [];
      }
      return [normalized];
    }
    return const [];
  }

  static List<ClientUserCode> _toClientCodes(Map<String, dynamic> data) {
    final rawCodes = data['codigosUsuario'];
    if (rawCodes is List) {
      final codes = rawCodes
          .whereType<Map>()
          .map(
            (item) => ClientUserCode.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.isValid)
          .toList();
      if (codes.isNotEmpty) {
        return codes;
      }
    }

    final legacyCode = data['codigoUsuario'] as String? ?? '';
    final legacyMeters = _toMeterList(data['numeroContador']);
    if (legacyCode.trim().isEmpty ||
        legacyCode.trim().toLowerCase() == 'na' ||
        legacyMeters.isEmpty) {
      return const [];
    }
    return [
      ClientUserCode(
        codigoUsuario: legacyCode.trim().toUpperCase(),
        numeroContador: legacyMeters.first.trim().toUpperCase(),
        sector: data['sector'] as String? ?? '',
      ),
    ];
  }
}

class ClientUserCode {
  const ClientUserCode({
    required this.codigoUsuario,
    required this.numeroContador,
    required this.sector,
  });

  final String codigoUsuario;
  final String numeroContador;
  final String sector;

  bool get isValid =>
      codigoUsuario.trim().isNotEmpty &&
      codigoUsuario.trim().toLowerCase() != 'na' &&
      numeroContador.trim().isNotEmpty &&
      numeroContador.trim().toLowerCase() != 'na' &&
      sector.trim().isNotEmpty &&
      sector.trim().toLowerCase() != 'na';

  Map<String, dynamic> toMap() {
    return {
      'codigoUsuario': codigoUsuario.trim().toUpperCase(),
      'numeroContador': numeroContador.trim().toUpperCase(),
      'sector': sector.trim().toLowerCase(),
    };
  }

  factory ClientUserCode.fromMap(Map<String, dynamic> data) {
    return ClientUserCode(
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      numeroContador: data['numeroContador'] as String? ?? '',
      sector: data['sector'] as String? ?? '',
    );
  }
}
