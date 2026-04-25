# Modulo Consumos

## Alcance

Rutas de acceso:

- administrador: `Panel principal > Consumos`
- operador: acceso directo a `Registrar consumos`
- contador: acceso directo a `Reportes`

Pantallas implementadas:

1. `Conflictos`
2. `Registrar consumos`
3. `Reportes`
4. `Registrar pagos`

Servicios involucrados:

- `ConsumptionFirestoreService`
- `ConsumptionConflictFirestoreService`
- `ConsumptionLocalCacheService`
- `BillingPeriodFirestoreService`
- `UserFirestoreService`
- `InvoiceFirestoreService`
- `PaymentMethodFirestoreService`

Colecciones relacionadas:

- `periodos/{periodo}/consumos`
- `periodos/{periodo}/consumos/{contador}/historial`
- `consumos_conflictos`
- `periodos/{periodo}/recibos`

## Pantalla Registrar consumos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_register_page.dart`

### Objetivo

Permitir al operador descargar un periodo, trabajar localmente y luego sincronizar.

### Reglas importantes

- el operador no trabaja directamente sobre Firestore
- primero descarga el periodo vigente al dispositivo
- no puede descargar otro periodo si hay lecturas locales pendientes
- no puede registrar lectura sobre consumos ya facturados o pagados

### Resultado del guardado local

- sin irregularidad: `estado = pendiente_local`
- con irregularidad: `estado = pendiente_revision`

## Pantalla Conflictos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_conflicts_admin_page.dart`

### Objetivo

Resolver conflictos de lectura detectados durante la sincronizacion.

### Reglas reales

- si el consumo ya esta `facturado` o `pagado`, no se modifica
- si se corrige una lectura anterior, el sistema recalcula periodos siguientes no bloqueados
- si en la cascada encuentra un periodo ya facturado o pagado, se detiene

## Pantalla Reportes

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_reports_admin_page.dart`

### Objetivo

Consultar lecturas registradas y revisar cartera pendiente con el mismo filtro.

### Filtros implementados

- periodo `YYYY-MM` o vacio
- codigo de usuario o vacio
- `Solo irregularidades`

### Que muestra

- total de lecturas consultadas
- total de recibos pendientes
- total de cartera pendiente
- listado de lecturas
- listado de cartera pendiente

### Informe de cartera pendiente

El panel lateral muestra para cada recibo:

- usuario
- codigo de usuario
- contador
- periodo
- estado
- fecha de vencimiento
- total facturado
- valor registrado
- saldo pendiente

### Exportacion CSV

Se mantiene para lecturas consultadas.

## Pantalla Registrar pagos

Archivo principal:

- `lib/features/consumptions/presentation/pages/consumption_payments_page.dart`

### Objetivo

Registrar o revertir pagos de recibos ya facturados.

### Que muestra

- selector de periodo
- contadores de pagados y pendientes
- lista de recibos del periodo
- valor del recibo
- estado del pago

### Flujo Registrar pago

1. seleccionar periodo
2. ubicar recibo
3. presionar `Registrar pago`
4. marcar pago
5. ver `Valor del recibo`
6. ingresar `Valor pagado`
7. opcionalmente seleccionar medio de pago
8. opcionalmente registrar observaciones
9. guardar

### Efecto tecnico

`InvoiceFirestoreService.updatePaymentStatus` actualiza en dos lados:

- `periodos/{periodo}/recibos`
- `periodos/{periodo}/consumos`

Campos sincronizados:

- `pagado`
- `estado`
- `valorPagado`
- `fechaPago`
- `medioPagoId`
- `medioPagoDescripcion`
- `observacionesPago`

## Estado del modulo

El modulo de consumos quedo operativo para captura, conflictos, reportes y pagos.
