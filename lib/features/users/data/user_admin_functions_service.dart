import 'package:cloud_functions/cloud_functions.dart';

import '../domain/app_user.dart';

class UserAdminFunctionsService {
  UserAdminFunctionsService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _client => _functions ?? FirebaseFunctions.instance;

  Future<String> createManagedUser({
    required AppUser user,
    String? password,
  }) async {
    final callable = _client.httpsCallable('createManagedUser');
    final result = await callable.call({
      'nombre': user.nombre,
      'tipoDocumento': user.tipoDocumento,
      'numeroDocumento': user.numeroDocumento,
      'numeroContacto': user.numeroContacto,
      'codigoUsuario': user.codigoUsuario,
      'numeroContador': user.numeroContador,
      'codigosUsuario': user.codigosUsuario
          .map((item) => item.toMap())
          .toList(),
      'rol': user.rol,
      'tipoCliente': user.tipoCliente,
      'sector': user.sector,
      'correo': user.correo,
      'estado': user.estado,
      'password': password,
    });
    return result.data['uid'] as String;
  }

  Future<void> updateManagedUser({
    required AppUser user,
    String? password,
  }) async {
    final callable = _client.httpsCallable('updateManagedUser');
    await callable.call({
      'uid': user.uid,
      'nombre': user.nombre,
      'tipoDocumento': user.tipoDocumento,
      'numeroDocumento': user.numeroDocumento,
      'numeroContacto': user.numeroContacto,
      'codigoUsuario': user.codigoUsuario,
      'numeroContador': user.numeroContador,
      'codigosUsuario': user.codigosUsuario
          .map((item) => item.toMap())
          .toList(),
      'rol': user.rol,
      'tipoCliente': user.tipoCliente,
      'sector': user.sector,
      'correo': user.correo,
      'estado': user.estado,
      'password': password,
    });
  }

  Future<void> deleteManagedUser(String uid) async {
    final callable = _client.httpsCallable('deleteManagedUser');
    await callable.call({'uid': uid});
  }

  Future<UserImportSummary> importMigratedUsers(
    List<Map<String, String>> rows,
  ) async {
    final callable = _client.httpsCallable(
      'importMigratedUsers',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 30)),
    );
    final result = await callable.call({'rows': rows});
    final data = Map<String, dynamic>.from(result.data as Map);
    return UserImportSummary.fromMap(data);
  }

  Future<UserImportSummary> mergeClientUsersByDocument(
    List<Map<String, String>> rows,
  ) async {
    final callable = _client.httpsCallable(
      'mergeClientUsersByDocument',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 30)),
    );
    final result = await callable.call({'rows': rows});
    final data = Map<String, dynamic>.from(result.data as Map);
    return UserImportSummary.fromMap(data);
  }
}

class UserImportSummary {
  const UserImportSummary({
    required this.imported,
    required this.failed,
    required this.results,
  });

  final int imported;
  final int failed;
  final List<UserImportRowResult> results;

  factory UserImportSummary.fromMap(Map<String, dynamic> data) {
    final rawResults = data['results'] as List<dynamic>? ?? const [];
    return UserImportSummary(
      imported: data['imported'] as int? ?? 0,
      failed: data['failed'] as int? ?? 0,
      results: rawResults
          .map(
            (item) => UserImportRowResult.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class UserImportRowResult {
  const UserImportRowResult({
    required this.rowNumber,
    required this.ok,
    this.codigoUsuario,
    this.message,
  });

  final int rowNumber;
  final bool ok;
  final String? codigoUsuario;
  final String? message;

  factory UserImportRowResult.fromMap(Map<String, dynamic> data) {
    return UserImportRowResult(
      rowNumber: data['rowNumber'] as int? ?? 0,
      ok: data['ok'] == true,
      codigoUsuario: data['codigoUsuario'] as String?,
      message: data['message'] as String?,
    );
  }
}
