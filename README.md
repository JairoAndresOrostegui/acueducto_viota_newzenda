# Acueducto Viota Newzenda

Aplicacion Flutter para la operacion del acueducto veredal de Quitasol y Jazmin, municipio de Viota, Cundinamarca.

## Resumen

- Plataformas objetivo: `Android` y `Web`
- Autenticacion: `Firebase Authentication`
- Datos: `Cloud Firestore`
- Backend administrativo: `Cloud Functions`
- PDF de recibos: `pdf` y `printing`
- Cache operativa del operador: `SharedPreferences`

## Estado actual del software

El sistema ya cubre el flujo principal de operacion:

- login y persistencia de sesion
- panel por rol
- administracion de usuarios y catalogos
- registro local y sincronizacion de consumos
- deteccion y resolucion de conflictos
- reportes de consumos con exportacion CSV
- facturacion masiva e individual
- regeneracion de recibos no pagados
- gestion de medios de pago
- gestion de observaciones de facturacion
- registro y reversa de pagos
- consulta de recibo por cliente
- acceso del contador a reportes de consumos y cartera pendiente

## Roles implementados

- `administrador`
  - consola completa con `Usuarios`, `Consumos` y `Facturacion`
- `operador`
  - acceso directo a `Registrar consumos`
- `cliente`
  - acceso directo a su recibo pendiente mas reciente
- `contador`
  - acceso restringido a `Consumos > Reportes`, incluyendo informe de cartera pendiente

## Modulos principales

### Usuarios

Capacidades:

- CRUD de usuarios administrados
- catalogos de tipos de documento, roles y sectores
- auditoria de cambios y eliminaciones
- validaciones especiales para usuarios cliente

Colecciones:

- `usuarios`
- `usuarios_logs`
- `tipos_documento`
- `roles`
- `sectores`

### Consumos

Capacidades:

- descarga del periodo de trabajo al dispositivo del operador
- registro local de lecturas
- soporte de irregularidades
- sincronizacion a Firestore
- deteccion de conflictos
- resolucion administrativa con recálculo posterior
- reportes filtrados
- exportacion CSV
- registro y reversa de pagos

Colecciones:

- `periodos/{periodo}/consumos`
- `periodos/{periodo}/consumos/{contador}/historial`
- `consumos_conflictos`

### Facturacion

Capacidades:

- creacion y activacion de periodos
- configuracion versionada de valores
- medios de pago
- observaciones de facturacion masivas e individuales
- generacion de recibos masiva e individual
- exportacion PDF por periodo y por sector
- generacion de un solo PDF o PDFs individuales
- regeneracion de recibos no pagados
- aviso dentro del recibo si cambian valores de facturacion
- PDF institucional ajustado al formato solicitado

Colecciones:

- `periodos`
- `periodos/{periodo}/recibos`
- `medios_pago`
- `valores_facturacion`
- `facturacion_observaciones`

## Reglas funcionales importantes

- La app requiere perfil en `usuarios/{uid}` para todo usuario autenticado.
- Solo usuarios con `estado = activo` pueden entrar.
- El operador trabaja sobre un periodo descargado localmente.
- No se puede descargar otro periodo si hay lecturas locales pendientes.
- Los conflictos se guardan en `consumos_conflictos`.
- Un consumo `facturado` o `pagado` no se edita desde el flujo normal.
- Los recibos se generan solo para lecturas facturables y no bloqueadas.
- La fecha de vencimiento del recibo es el dia `24` del mes de generacion del recibo.
- Si el recibo se genera despues del dia `20`, vence `15` dias despues de la fecha generada.
- La regeneracion no modifica recibos ya pagados.
- El cliente solo ve su recibo pendiente mas reciente.
- El contador solo puede consultar reportes y cartera pendiente.

## Firebase desplegado en esta iteracion

Ya quedaron desplegados en `frontacueductonewzenda`:

- reglas de Firestore
- indices de Firestore

Cambios desplegados relevantes:

- permisos para `facturacion_observaciones`
- permisos de lectura para `contador` en `periodos`, `consumos` y `recibos`
- indice compuesto para `collectionGroup('recibos')` por `codigoUsuario` y `pagado`

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
flutter run
firebase deploy --only firestore --project frontacueductonewzenda
firebase deploy --only functions --project frontacueductonewzenda
firebase deploy --only hosting --project frontacueductonewzenda
```

## Estado de cierre

Para el alcance funcional actual, el software quedo operativo.

Todavia hay pendientes razonables antes de llamarlo cerrado al 100% a nivel de producto:

- pruebas funcionales finales por rol en ambiente real
- validacion operativa con datos reales de facturacion y pago
- despliegue de hosting si se quiere dejar la version web publicada
- endurecer pruebas automatizadas, porque hoy el proyecto depende sobre todo de validacion manual

Si el alcance esperado era:

- usuarios
- consumos
- conflictos
- reportes
- pagos
- facturacion
- PDF
- cliente
- contador con reportes y cartera

entonces el software quedo esencialmente completo.
