import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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
    final payload = {
      'nombre': user.nombre,
      'tipoDocumento': user.tipoDocumento,
      'numeroDocumento': user.numeroDocumento,
      'numeroContacto': user.numeroContacto,
      'codigoUsuario': user.codigoUsuario,
      'numeroContador': user.numeroContador,
      'rol': user.rol,
      'tipoCliente': user.tipoCliente,
      'sector': user.sector,
      'correo': user.correo,
      'estado': user.estado,
      'password': password,
    };

    debugPrint('createManagedUser payload: $payload');

    try {
      final result = await callable.call(payload);
      debugPrint('createManagedUser result: ${result.data}');
      return result.data['uid'] as String;
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'createManagedUser FirebaseFunctionsException'
        ' code=${error.code}'
        ' message=${error.message}'
        ' details=${error.details}',
      );
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('createManagedUser unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateManagedUser({
    required AppUser user,
    String? password,
  }) async {
    final callable = _client.httpsCallable('updateManagedUser');
    final payload = {
      'uid': user.uid,
      'nombre': user.nombre,
      'tipoDocumento': user.tipoDocumento,
      'numeroDocumento': user.numeroDocumento,
      'numeroContacto': user.numeroContacto,
      'codigoUsuario': user.codigoUsuario,
      'numeroContador': user.numeroContador,
      'rol': user.rol,
      'tipoCliente': user.tipoCliente,
      'sector': user.sector,
      'correo': user.correo,
      'estado': user.estado,
      'password': password,
    };

    debugPrint('updateManagedUser payload: $payload');

    try {
      final result = await callable.call(payload);
      debugPrint('updateManagedUser result: ${result.data}');
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'updateManagedUser FirebaseFunctionsException'
        ' code=${error.code}'
        ' message=${error.message}'
        ' details=${error.details}',
      );
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('updateManagedUser unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteManagedUser(String uid) async {
    final callable = _client.httpsCallable('deleteManagedUser');
    await callable.call({'uid': uid});
  }
}
