# Modulo Consumos

## Alcance

Rutas de acceso:

- administrador: `Panel principal > Consumos`
- operador: acceso directo a `Registrar consumos`
- contador: acceso directo a `Reportes`

Pantallas implementadas:

1. `Conflictos`
2. `Registrar consumos`
3. `Importar consumos`
4. `Reportes`
5. `Registrar pagos`
6. `Suspensiones`

Servicios involucrados:

- `ConsumptionFirestoreService`
- `ConsumptionConflictFirestoreService`
- `ConsumptionLocalCacheService`
- `ConsumptionImportFunctionsService`
- `BillingPeriodFirestoreService`
- `UserFirestoreService`
- `InvoiceFirestoreService`
- `PaymentMethodFirestoreService`

Colecciones relacionadas:

- `periodos/{periodo}/consumos`
- `periodos/{periodo}/consumos/{contador}/historial`
- `consumos_conflictos`
- `periodos/{periodo}/recibos`

## Pantalla Conflictos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_conflicts_admin_page.dart`

Objetivo:

- Resolver conflictos de lectura detectados durante la sincronizacion.

Reglas:

- Si el consumo ya esta `facturado` o `pagado`, no se modifica.
- Puede conservarse la lectura existente, usar la entrante o ingresar valor manual.
- Si se corrige una lectura anterior, el sistema recalcula periodos siguientes no bloqueados.
- Si la cascada encuentra un periodo facturado o pagado, se detiene.

## Pantalla Registrar consumos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_register_page.dart`

Objetivo:

- Permitir al operador descargar un periodo, trabajar localmente y sincronizar lecturas.
- Revisar de forma rapida lecturas sin registrar e irregularidades del periodo de trabajo.

Reglas:

- El operador no trabaja directamente sobre Firestore.
- Primero descarga el periodo vigente al dispositivo.
- No puede descargar otro periodo si hay lecturas locales pendientes.
- No puede registrar lectura sobre consumos facturados, pagados o bloqueados.
- `Pendientes por subir` solo cuenta lecturas locales en estado `pendiente_local` o `pendiente_revision`.
- Los estados oficiales `sincronizado`, `irregularidad_reportada`, `facturado`, `pagado`, `suspendido`, `resuelto` y `editado_admin` no se tratan como pendientes por subir.
- Al subir, si ya existe un consumo oficial para el periodo y contador, la lectura queda como conflicto/bloqueada en lugar de intentar sobrescribir el consumo.

Resultado local:

- sin irregularidad: `estado = pendiente_local`
- con irregularidad: `estado = pendiente_revision`

Vistas rapidas:

- `Lecturas pendientes`: lista clientes del periodo sin lectura registrada.
- `Irregularidades`: lista clientes con lectura irregular registrada en el periodo.
- Cada vista respeta la busqueda por nombre, codigo de usuario o contador.

## Pantalla Importar consumos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_import_page.dart`

Objetivo:

- Cargar lecturas desde Excel para un periodo especifico.

Formato:

- Columna `codigousuario`.
- Una columna cuyo encabezado sea el periodo real, por ejemplo `2026-01`.
- El valor de esa columna es la lectura actual.

Acciones:

- Descargar plantilla Excel.
- Seleccionar archivo.
- Vista previa de filas.
- Importar consumos.
- Descargar filas ignoradas cuando aplique.

## Pantalla Reportes

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_reports_admin_page.dart`

Objetivo:

- Consultar lecturas registradas y revisar cartera pendiente.

Filtros:

- periodo `YYYY-MM` o vacio
- codigo de usuario o vacio
- solo irregularidades

Muestra:

- total de lecturas consultadas
- total de recibos pendientes
- total de cartera pendiente
- listado de lecturas
- listado de cartera pendiente

Informe de cartera:

- usuario
- codigo de usuario
- contador
- periodo
- estado
- fecha de vencimiento
- total facturado
- saldo anterior
- valor registrado
- saldo pendiente

Exportacion:

- CSV de lecturas consultadas.

## Pantalla Registrar pagos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_payments_page.dart`

Objetivo:

- Registrar o revertir pagos de recibos facturados.

Reglas:

- Solo se muestran periodos desde `2026-01`.
- El valor base de pago es `totalAPagar`, que incluye total facturado, saldo anterior y reconexion.
- Los recibos suspendidos se muestran con estado diferenciado.

Flujo:

1. Seleccionar periodo.
2. Ubicar recibo.
3. Presionar `Registrar pago` o `Cambiar estado`.
4. Marcar pago.
5. Confirmar valor pagado.
6. Seleccionar medio de pago si aplica.
7. Registrar observaciones si aplica.
8. Guardar.

Efecto tecnico:

`InvoiceFirestoreService.updatePaymentStatus` actualiza:

- `periodos/{periodo}/recibos/{reciboId}`
- `periodos/{periodo}/consumos/{codigoContador}`

Campos sincronizados:

- `pagado`
- `estado`
- `reciboId`
- `valorPagado`
- `fechaPago`
- `medioPagoId`
- `medioPagoDescripcion`
- `observacionesPago`

## Pantalla Suspensiones

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_suspensions_admin_page.dart`

Objetivo:

- Suspender facturas no pagadas que ya vienen en mora del periodo anterior.

Reglas:

- Solo se muestran periodos desde `2026-01`.
- `2025-12` queda fuera de cartera y sirve como base historica.
- Solo se habilita el boton `Suspender` si `estadoPeriodoAnterior = en_mora`.
- No se suspende una factura pagada.
- Una factura ya suspendida no se vuelve a procesar.
- El boton de suspension mantiene ancho controlado para evitar errores de layout en web.

Filtros:

- nombre
- codigo de usuario
- codigo de contador
- estado: `Todos`, `Al día`, `En mora`, `Suspendidas`

Efecto tecnico:

`InvoiceFirestoreService.suspendInvoice` actualiza:

- recibo: `estado = suspendido`
- consumo: `estado = suspendido`, `pagado = false`, `facturado = true`, `reciboId`, `detalleEstado`

## Estado del modulo

El modulo de consumos queda operativo para captura, importacion, conflictos, reportes, pagos y suspensiones.
