# Acueducto Viota Newzenda

Aplicacion Flutter/Firebase para la operacion del acueducto veredal de Quitasol y Jazmin, municipio de Viota, Cundinamarca.

## Resumen tecnico

- Plataformas objetivo: `Android` y `Web`
- Autenticacion: `Firebase Authentication`
- Datos: `Cloud Firestore`
- Backend administrativo: `Cloud Functions`
- Hosting web: `Firebase Hosting`
- PDF de recibos: `pdf` y `printing`
- Importaciones Excel: `excel` y `file_picker`
- Cache operativa del operador: `SharedPreferences`

## Estado funcional

El sistema cubre el flujo principal de operacion:

- inicio de sesion y persistencia por Firebase Auth
- validacion de perfil activo en `usuarios/{uid}`
- panel por rol
- administracion de usuarios, catalogos y auditoria
- importacion masiva de usuarios cliente desde Excel
- creacion y activacion de periodos
- registro local y sincronizacion de consumos
- importacion masiva de lecturas de consumo desde Excel
- deteccion y resolucion de conflictos
- reportes de lecturas y cartera pendiente
- facturacion masiva e individual
- regeneracion de recibos no pagados
- regeneracion individual de recibos no pagados
- PDF por recibo, por periodo y por sector
- gestion de medios de pago y observaciones de facturacion
- registro y reversa de pagos
- suspension administrativa de facturas en mora
- consulta de recibo pendiente por cliente
- acceso del contador a reportes y cartera pendiente

## Roles implementados

- `administrador`: consola completa con `Usuarios`, `Consumos` y `Facturacion`.
- `operador`: acceso directo a `Registrar consumos`.
- `cliente`: acceso directo al recibo pendiente mas reciente.
- `contador`: acceso restringido a `Consumos > Reportes`.

## Revision pantalla por pantalla

### Login

Archivo: `lib/features/auth/presentation/pages/login_page.dart`

- Permite ingreso por correo y clave.
- Soporta selector de acceso administrativo o usuario.
- Tras autenticar, la app carga el perfil de Firestore y valida `estado = activo`.

### Panel principal

Archivo: `lib/features/home/presentation/pages/home_page.dart`

- Enruta por rol.
- Muestra restriccion si no existe perfil en Firestore o si el usuario no esta activo.
- Incluye cierre de sesion.

### Usuarios

Archivo principal: `lib/features/users/presentation/pages/users_admin_page.dart`

- CRUD de usuarios administrados mediante Cloud Functions.
- Busqueda por datos principales del usuario.
- Validaciones especiales para clientes: codigo, contador, sector y tipo de cliente.

### Importar usuarios

Archivo principal: `lib/features/users/presentation/pages/users_import_page.dart`

- Descarga plantilla Excel.
- Lee columnas `tipousuario`, `sector`, `numcontador`, `codigousuario`, `documento`, `celular`, `nombre`, `correo`.
- Importa clientes con rol `cliente`, estado `activo` y tipo documento `cc`.

### Catalogos

Archivo principal: `lib/features/catalogs/presentation/pages/catalog_admin_page.dart`

- Administra tipos de documento, roles y sectores.
- Solo los registros activos se ofrecen en formularios operativos.

### Logs de usuarios

Archivo principal: `lib/features/users/presentation/pages/user_logs_page.dart`

- Consulta auditoria de cambios y eliminaciones.
- Muestra responsable, usuario afectado, fecha, datos anteriores y nuevos.

### Conflictos de consumo

Archivo principal: `lib/features/consumptions/presentation/pages/consumption_conflicts_admin_page.dart`

- Lista conflictos generados al sincronizar lecturas.
- Permite resolver usando lectura existente, lectura entrante o valor manual.
- Recalcula periodos posteriores mientras no esten facturados o pagados.

### Registrar consumos

Archivo principal: `lib/features/consumptions/presentation/pages/consumption_register_page.dart`

- Descarga el periodo vigente al dispositivo.
- Permite registrar lecturas localmente.
- Soporta irregularidades y observaciones.
- Sincroniza lecturas hacia Firestore.
- Muestra vistas rapidas de lecturas sin registrar e irregularidades.
- El contador `Pendientes por subir` solo incluye lecturas locales `pendiente_local` o `pendiente_revision`.

### Importar consumos

Archivo principal: `lib/features/consumptions/presentation/pages/consumption_import_page.dart`

- Descarga plantilla Excel.
- Usa columnas `codigousuario` y un encabezado de periodo como `2026-01`.
- Importa lecturas actuales y permite descargar filas ignoradas.

### Reportes de consumos

Archivo principal: `lib/features/consumptions/presentation/pages/consumption_reports_admin_page.dart`

- Filtra por periodo, codigo de usuario e irregularidades.
- Muestra lecturas consultadas.
- Muestra cartera pendiente con saldo anterior, valor pagado y saldo pendiente.
- Exporta lecturas a CSV.

### Registrar pagos

Archivo principal: `lib/features/consumptions/presentation/pages/consumption_payments_page.dart`

- Lista recibos por periodo desde `2026-01`.
- Diferencia pagados, pendientes y suspendidos.
- Registra valor pagado, medio de pago y observaciones.
- Puede revertir el pago y sincroniza estado en recibo y consumo.

### Suspensiones

Archivo principal: `lib/features/consumptions/presentation/pages/consumption_suspensions_admin_page.dart`

- Lista facturas por periodo desde `2026-01`.
- Busca por nombre, codigo de usuario o codigo de contador.
- Filtra por `Todos`, `Al día`, `En mora` y `Suspendidas`.
- Solo permite suspender facturas con estado de periodo anterior `en_mora`.
- No permite suspender facturas ya pagadas.

### Facturacion

Archivo principal: `lib/features/billing/invoices/presentation/pages/billing_invoices_page.dart`

- Genera recibos masivos o individuales.
- Regenera recibos no pagados de forma masiva o individual.
- Exporta PDF por periodo o por sector.
- Lista lecturas no preparadas para facturar.

### Periodos

Archivo principal: `lib/features/billing/periods/presentation/pages/billing_periods_page.dart`

- Genera periodos mensuales.
- Permite marcar un unico periodo vigente.

### Medios de pago

Archivo principal: `lib/features/billing/payment_methods/presentation/pages/payment_methods_admin_page.dart`

- Administra instrucciones de pago.
- Los medios quedan copiados como snapshot al generar recibos.

### Observaciones de facturacion

Archivo principal: `lib/features/billing/observations/presentation/pages/billing_observations_admin_page.dart`

- Administra observaciones masivas, permanentes o individuales.
- Las observaciones aplicables quedan copiadas dentro del recibo.

### Valores de facturacion

Archivo principal: `lib/features/billing/values/presentation/pages/billing_values_admin_page.dart`

- Versiona cargo fijo, rangos de consumo y valores adicionales.
- Cada guardado crea una version activa y desactiva la anterior.

### Cliente

Archivo principal: `lib/features/billing/invoices/presentation/pages/client_invoice_page.dart`

- Consulta el recibo pendiente mas reciente del cliente autenticado.
- Muestra lecturas, consumo, saldo anterior, total, vencimiento y medios de pago.
- Permite abrir el recibo en PDF.

## Reglas funcionales importantes

- Todo usuario autenticado requiere perfil en `usuarios/{uid}`.
- Solo usuarios con `estado = activo` pueden operar.
- El operador trabaja con cache local y no puede descargar otro periodo si tiene lecturas pendientes.
- Un consumo `facturado`, `pagado` o `suspendido` no se edita desde el flujo normal.
- La facturacion contable inicia en `2026-01`; `2025-12` se usa como base historica y no entra en cartera.
- Los recibos se generan solo para lecturas facturables y no bloqueadas.
- La fecha de vencimiento es el dia `24` del mes de generacion; si se genera despues del dia `20`, vence 15 dias despues.
- La regeneracion masiva e individual no modifica recibos pagados.
- Los estados internos como `al_dia` se muestran al usuario como `Al día`.
- El cliente solo ve recibos asociados a su `codigoUsuario`.
- El contador tiene acceso de solo lectura a reportes y cartera.
- Las suspensiones solo aplican a facturas en mora y no pagadas.

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

## Estructura principal

- `lib/features/auth`
- `lib/features/home`
- `lib/features/admin`
- `lib/features/users`
- `lib/features/catalogs`
- `lib/features/consumptions`
- `lib/features/billing`
- `functions`
- `documentacion de entrega`

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
flutter build web
firebase deploy --only firestore --project frontacueductonewzenda
firebase deploy --only functions --project frontacueductonewzenda
firebase deploy --only hosting --project frontacueductonewzenda
```

## Estado de cierre

Actualizado el 2026-04-29. La aplicacion queda lista para validacion operativa por rol en ambiente real, con hosting web, reglas Firestore, indices, funciones y documentacion de entrega alineadas con las pantallas disponibles.
