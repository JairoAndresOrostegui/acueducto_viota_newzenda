# Modulo Usuarios

## Alcance

Ruta de acceso para administrador:

- `Panel principal > Usuarios`

Pantallas implementadas:

1. `Usuarios`
2. `Tipos documento`
3. `Roles`
4. `Sectores`
5. `Logs`

Servicios involucrados:

- `UserFirestoreService`
- `UserAdminFunctionsService`
- `DocumentTypeCatalogService`
- `RoleCatalogService`
- `SectorCatalogService`
- `UserAuditLogService`

Backend relacionado:

- `functions/index.js`
- Cloud Functions: `createManagedUser`, `updateManagedUser`, `deleteManagedUser`

Colecciones relacionadas:

- `usuarios`
- `usuarios_logs`
- `tipos_documento`
- `roles`
- `sectores`

## Pantalla Usuarios

Archivo principal:

- `lib/features/users/presentation/pages/users_admin_page.dart`

### Objetivo

Administrar usuarios del sistema y sus datos operativos.

### Que muestra

- Metricas de usuarios cargados, activos y clientes.
- Busqueda por nombre, correo, rol, tipo cliente, documento, estado, contador o sector.
- Tarjetas por usuario con acciones de editar y eliminar.

### Campos del formulario

- Correo
- Nombre completo
- Tipo de documento
- Numero de documento
- Numero de contacto
- Rol
- Tipo de cliente
- Estado
- Clave
- Codigo de usuario
- Numero de contador
- Sector

### Reglas reales del formulario

- Solo se usan catalogos activos de tipos de documento, roles y sectores.
- `correo` es obligatorio y se guarda en minuscula.
- La clave es obligatoria al crear y debe tener minimo 8 caracteres.
- El rol es obligatorio.
- Si el rol es `cliente`:
  - `codigoUsuario` es obligatorio y numerico.
  - `numeroContador` es obligatorio.
  - `sector` es obligatorio.
  - `tipoCliente` debe ser `socio` o `suscriptor`.
- Si el rol no es `cliente`, el formulario fuerza:
  - `codigoUsuario = na`
  - `numeroContador = NA`
  - `tipoCliente = na`
  - `sector = na`
- El administrador autenticado no puede eliminarse a si mismo desde la lista.

### Validaciones de backend

Cloud Functions agrega validaciones adicionales:

- Solo administradores activos pueden gestionar usuarios.
- El tipo de documento, rol y sector deben existir y estar activos.
- El numero de documento no puede repetirse en otro usuario.
- El correo no puede repetirse en Firebase Authentication.
- Para clientes:
  - `codigoUsuario` debe ser unico.
  - cada contador debe ser unico.
  - no se permiten contadores repetidos en el mismo usuario.

### Flujo de crear usuario

1. Entrar a `Usuarios > Usuarios`.
2. Presionar `Nuevo usuario`.
3. Diligenciar los datos obligatorios.
4. Si el rol es `cliente`, diligenciar codigo de usuario, contadores, tipo de cliente y sector.
5. Guardar.
6. El frontend llama `createManagedUser`.
7. La funcion crea el usuario en Authentication y el perfil en `usuarios`.

### Flujo de editar usuario

1. Buscar el usuario.
2. Presionar `Editar`.
3. Ajustar los datos.
4. Si hace falta, ingresar una nueva clave.
5. Guardar.
6. El frontend llama `updateManagedUser`.
7. La funcion actualiza Authentication y Firestore.

### Flujo de eliminar usuario

1. Buscar el usuario.
2. Presionar `Eliminar`.
3. Confirmar la accion.
4. El frontend llama `deleteManagedUser`.
5. La funcion elimina el usuario administrado.

### Casos de prueba recomendados

1. Crear un administrador activo.
2. Crear un operador activo.
3. Crear un cliente con varios contadores.
4. Intentar crear cliente sin sectores activos.
5. Intentar crear usuario con correo repetido.
6. Intentar crear cliente con contador ya asignado a otro usuario.
7. Editar un usuario y cambiar su estado.
8. Cambiar la clave de un usuario existente.
9. Intentar eliminar al usuario autenticado.

## Pantalla Tipos documento

Archivo principal:

- `lib/features/catalogs/presentation/pages/catalog_admin_page.dart`

Servicio:

- `DocumentTypeCatalogService`

### Objetivo

Administrar el catalogo usado por el formulario de usuarios.

### Que muestra

- Encabezado con descripcion.
- Contador de registros filtrados y totales.
- Busqueda por valor, nombre o estado.
- Lista con acciones de editar y eliminar.

### Reglas

- `valor`, `nombre` y `estado` se normalizan a minuscula al guardar.
- Solo los registros `activo` se usan fuera del modulo.

### Flujo

1. Presionar `Nuevo`.
2. Diligenciar nombre visible y valor BD.
3. Seleccionar estado.
4. Guardar.

## Pantalla Roles

Archivo principal:

- `lib/features/catalogs/presentation/pages/catalog_admin_page.dart`

Servicio:

- `RoleCatalogService`

### Objetivo

Administrar perfiles permitidos para usuarios gestionados.

### Reglas

- Solo roles `activo` se ofrecen en el formulario de usuarios.
- El valor BD es el que gobierna la navegacion por rol en `HomePage`.

### Roles observados en el codigo

- `administrador`
- `operador`
- `cliente`
- `contador`

## Pantalla Sectores

Archivo principal:

- `lib/features/catalogs/presentation/pages/catalog_admin_page.dart`

Servicio:

- `SectorCatalogService`

### Objetivo

Administrar sectores asignables a clientes.

### Reglas

- Solo los sectores `activo` se muestran al crear o editar usuarios cliente.
- El valor BD puede autogenerarse desde el nombre.
- Los sectores no aplican a roles distintos de cliente.

## Pantalla Logs

Archivo principal:

- `lib/features/users/presentation/pages/user_logs_page.dart`

Servicio:

- `UserAuditLogService`

### Objetivo

Consultar la auditoria de cambios sobre usuarios administrados.

### Que muestra

- Accion realizada.
- Usuario afectado.
- Responsable.
- Fecha y hora.
- Bloque `Anterior`.
- Bloque `Nuevo`.

### Reglas reales

- La busqueda usa solo la primera palabra escrita.
- El servicio devuelve hasta 50 registros.
- El filtro trabaja con `searchTokens` almacenados en `usuarios_logs`.

### Eventos esperados

- Edicion de usuario.
- Eliminacion de usuario.

## Resumen funcional del modulo

- El CRUD de usuarios no escribe directo a Authentication desde Flutter.
- La gestion sensible depende de Cloud Functions.
- Los catalogos y logs si operan directo contra Firestore.
- El modulo esta operativo y coherente con el panel del administrador.
