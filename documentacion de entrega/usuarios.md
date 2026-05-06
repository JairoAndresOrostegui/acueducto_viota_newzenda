# Modulo Usuarios

## Alcance

Ruta:

- `Panel principal > Usuarios`

Pantallas:

1. `Usuarios`
2. `Importar usuarios`
3. `Tipos documento`, visible solo para `superAdmin`
4. `Roles`, visible solo para `superAdmin`
5. `Sectores`
6. `Logs`, visible solo para `superAdmin`

## Servicios y backend

Servicios Flutter:

- `UserFirestoreService`
- `UserAdminFunctionsService`
- `DocumentTypeCatalogService`
- `RoleCatalogService`
- `SectorCatalogService`
- `UserAuditLogService`

Cloud Functions:

- `createManagedUser`
- `updateManagedUser`
- `deleteManagedUser`
- `resetClientAccountData`
- `importMigratedUsers`
- `mergeClientUsersByDocument`
- `normalizeImportedUserPlaceholders`

Colecciones:

- `usuarios`
- `usuarios_logs`
- `tipos_documento`
- `roles`
- `sectores`

## CRUD de usuarios

Archivo:

- `lib/features/users/presentation/pages/users_admin_page.dart`

El CRUD administra perfiles y delega operaciones sensibles a Cloud Functions. No escribe usuarios de Authentication directamente desde Flutter.

### Busquedas

Permite buscar por:

- nombre
- correo
- rol
- tipo cliente
- documento
- estado
- codigo de usuario
- contador
- sector

### Clientes con varios codigos

Un cliente puede tener varios registros en `codigosUsuario`. Cada registro contiene:

- `codigoUsuario`
- `numeroContador`
- `sector`

Tambien se mantiene `codigosUsuarioValores` para busquedas y reglas.

## Reglas del formulario

- Solo se usan catalogos activos.
- Para usuarios internos se exige correo y clave temporal, salvo accion de `superAdmin` cuando aplique.
- Para clientes se exige codigo de usuario, contador, sector y tipo de cliente, salvo flujo de `superAdmin` autorizado.
- Al crear o actualizar, si el campo `superAdmin` no existe se conserva o se deja en `false` por defecto.
- Los usuarios con rol administrador no pueden eliminar otros administradores.
- La eliminacion exige escribir `ELIMINAR`.
- El usuario autenticado no puede eliminarse a si mismo.

## superAdmin

El campo `superAdmin = true` habilita funciones restringidas:

- ver `Tipos documento`, `Roles` y `Logs`;
- omitir campos vacios en el CRUD cuando se necesite corregir/importar informacion;
- ejecutar limpieza de cuenta de prueba para usuarios cliente.

Si el campo no existe en usuarios antiguos, el sistema lo interpreta como `false`.

## Limpieza de cuenta de prueba

Boton:

- `Limpiar cuenta`

Visibilidad:

- solo para usuario autenticado con `superAdmin = true`;
- solo sobre usuarios con rol `cliente`.

Confirmacion:

- exige escribir `LIMPIAR`.

Cloud Function:

- `resetClientAccountData`

La accion:

- conserva el usuario;
- conserva los consumos/lecturas;
- borra recibos asociados a todos los codigos y contadores del usuario;
- borra movimientos en `cuentas_movimientos`;
- limpia campos derivados de pago/facturacion en consumos;
- deja los consumos como lecturas normales `sincronizado`;
- registra auditoria en `usuarios_logs`.

No modifica:

- datos principales del usuario;
- codigos de usuario;
- contadores;
- sectores;
- lecturas actuales o historicas.

## Importar usuarios

Archivo:

- `lib/features/users/presentation/pages/users_import_page.dart`

Columnas del importador principal:

- `tipousuario`
- `sector`
- `numcontador`
- `codigousuario`
- `documento`
- `celular`
- `nombre`
- `correo`

Importacion/unificacion temporal para migracion:

- cabeceras esperadas: `sector`, `numcontador`, `codigousuario`, `documento`, `nombre`;
- unifica clientes repetidos por documento;
- deja un solo usuario con varios codigos, contadores y sectores;
- no crea usuarios cliente en Authentication durante esa migracion.

## Logs

Eventos esperados:

- creacion
- edicion
- eliminacion
- importacion
- migracion/unificacion
- limpieza de cuenta de prueba

## Estado

El modulo queda operativo para usuarios simples, clientes con varios codigos, administracion restringida por `superAdmin`, auditoria y limpieza controlada de datos de prueba.
