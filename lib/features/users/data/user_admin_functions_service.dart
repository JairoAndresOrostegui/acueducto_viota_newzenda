import 'package:cloud_functions/cloud_functions.dart';

import '../domain/app_user.dart';

class UserAdminFunctionsService {
  UserAdminFunctionsService({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _client => _functions ?? FirebaseFunctions.instance;

  Future<String> createManagedUser({
    required AppUser user,
    required String password,
  }) async {
    final callable = _client.httpsCallable('createManagedUser');
    final result = await callable.call({
      'nombre': user.nombre,
      'tipoDocumento': user.tipoDocumento,
      'numeroDocumento': user.numeroDocumento,
      'numeroContacto': user.numeroContacto,
      'codigoUsuario': user.codigoUsuario,
      'numeroContador': user.numeroContador,
      'rol': user.rol,
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
      'rol': user.rol,
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
}
