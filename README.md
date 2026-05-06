# Acueducto Viota Newzenda

Aplicacion Flutter/Firebase para la operacion del acueducto veredal de Quitasol y Jazmin, municipio de Viota, Cundinamarca.

## Resumen tecnico

- Plataformas objetivo: `Web` y `Android`.
- Frontend: Flutter.
- Autenticacion: Firebase Authentication.
- Datos: Cloud Firestore.
- Backend administrativo: Cloud Functions 2nd gen.
- Hosting web: Firebase Hosting.
- PDF de recibos: paquetes `pdf` y `printing`.
- Importaciones y exportaciones Excel: paquetes `excel` y `file_picker`.
- Cache operativa del operador: SharedPreferences.

## Estado funcional

El sistema cubre el flujo operativo principal:

- inicio de sesion y validacion de perfil activo en `usuarios/{uid}`;
- panel por rol;
- CRUD de usuarios con varios codigos de usuario por cliente;
- importacion y unificacion de usuarios cliente desde Excel;
- catalogos de tipos de documento, roles, sectores y medios de pago;
- auditoria de usuarios;
- periodos mensuales con periodo base `2025-12`;
- registro local, importacion y sincronizacion de consumos;
- deteccion, resolucion e historico de conflictos;
- facturacion masiva e individual desde `2026-01`;
- regeneracion masiva e individual de recibos no pagados;
- PDF por recibo, periodo y sector;
- valores de facturacion versionados;
- observaciones de facturacion;
- cuentas, pagos reales, saldos en mora y saldos a favor;
- cartera por periodo o consolidada;
- suspension automatica por mora y suspension/des-suspension administrativa;
- reportes separados de facturacion, consumos y cartera;
- consulta de recibos pendientes por cliente.

## Macromodulos

### Usuarios

Pantallas:

- Usuarios
- Importar usuarios
- Tipos documento, solo visible para `superAdmin`
- Roles, solo visible para `superAdmin`
- Sectores
- Logs, solo visible para `superAdmin`

El usuario con `superAdmin = true` puede omitir campos vacios en el CRUD de usuarios y acceder a acciones restringidas, como la limpieza de cuenta de prueba.

### Consumos

Pantallas:

- Conflictos
- Registrar consumos
- Importar consumos
- Suspensiones

El modulo contiene el flujo de lecturas, conflictos, importacion y suspension. Los pagos y reportes ya no viven aqui como pantallas principales.

### Cuentas

Pantallas:

- Cuentas
- Registrar pagos
- Extraordinarios

Este modulo contiene el flujo financiero operativo:

- registro de pagos reales;
- abonos parciales;
- saldos pendientes;
- saldos a favor;
- movimientos en `cuentas_movimientos`;
- visualizacion de cuenta por periodo;
- cargos extraordinarios guardados como valores adicionales de facturacion.

### Facturacion

Pantallas:

- Facturacion
- Periodos
- Medios de pago
- Observaciones
- Valores

Genera y regenera recibos. La generacion de PDF se mantiene en este modulo.

### Reportes

Pantallas:

- Facturacion
- Consumos
- Cartera

Cada reporte tiene responsabilidad separada:

- Facturacion: recibos emitidos, valores facturados, estados y exportacion Excel.
- Consumos: lecturas, consumo m3, irregularidades y estado de facturacion.
- Cartera: saldos pendientes, pagos, saldos a favor, suspendidos y cartera consolidada.

## Roles implementados

- `administrador`: acceso completo a los macromodulos administrativos.
- `operador`: acceso directo a registrar consumos.
- `cliente`: acceso a sus recibos pendientes.
- `contador`: acceso de consulta a reportes.
- `fiscal`: acceso de consulta a reportes.

## Reglas funcionales importantes

- Todo usuario autenticado requiere perfil en `usuarios/{uid}`.
- Solo usuarios con `estado = activo` pueden operar.
- Un cliente puede tener varios codigos de usuario; cada codigo se asocia a un contador y sector.
- La facturacion contable inicia en `2026-01`.
- `2025-12` existe solo como lectura base historica; no se selecciona en modulos operativos salvo importacion/registro de consumos cuando aplica.
- Los recibos se generan solo para lecturas facturables y no bloqueadas.
- La regeneracion no modifica recibos pagados.
- Los pagos crean movimientos contables en `cuentas_movimientos`.
- Si un usuario paga menos que el recibo, queda saldo pendiente y se arrastra como saldo anterior.
- Si paga mas que el recibo, queda saldo a favor y se aplica al siguiente recibo.
- Al tercer periodo de mora, el recibo puede pasar a `suspendido`; los cobros siguen acumulando.
- El estado `suspendido` se levanta pagando o desde la pantalla de suspensiones.
- El cliente solo ve recibos asociados a sus codigos de usuario.
- El contador y fiscal tienen acceso de solo lectura.
- La eliminacion de usuario exige confirmacion escribiendo `ELIMINAR`.
- Administradores no pueden eliminar otros administradores.

## Colecciones principales

- `usuarios`
- `usuarios_logs`
- `tipos_documento`
- `roles`
- `sectores`
- `periodos`
- `periodos/{periodo}/consumos`
- `periodos/{periodo}/consumos/{contador}/historial`
- `periodos/{periodo}/recibos`
- `consumos_conflictos`
- `medios_pago`
- `valores_facturacion`
- `facturacion_observaciones`
- `cuentas_movimientos`

## Cloud Functions principales

- `createManagedUser`
- `updateManagedUser`
- `deleteManagedUser`
- `resetClientAccountData`
- `signInWithClientCode`
- `importMigratedUsers`
- `mergeClientUsersByDocument`
- `normalizeImportedUserPlaceholders`
- `importConsumptionReadings`

## Comandos utiles

En este repositorio se recomienda usar los scripts seguros cuando Flutter se quede colgado dentro del sandbox:

```bash
flutter pub get
flutter analyze
flutter build web
firebase deploy --only firestore --project frontacueductonewzenda
firebase deploy --only functions --project frontacueductonewzenda
firebase deploy --only hosting --project frontacueductonewzenda
```

Script de analisis seguro usado durante la entrega:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\flutter_analyze_safe.ps1 -Target . -SkipGlobalCleanup
```

## Despliegue actual

- Proyecto Firebase: `frontacueductonewzenda`
- Hosting: `https://frontacueductonewzenda.web.app`
- Rama principal: `main`

## Estado de entrega

Actualizado el 2026-05-06. El sistema queda desplegado y alineado con los modulos actuales de Usuarios, Consumos, Cuentas, Facturacion y Reportes.
