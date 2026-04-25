# Modulo Facturacion

## Alcance

Ruta de acceso para administrador:

- `Panel principal > Facturacion`

Pantallas implementadas:

1. `Facturacion`
2. `Periodos`
3. `Medios de pago`
4. `Observaciones`
5. `Valores`

Pantalla cliente relacionada:

- `ClientInvoicePage`

Servicios involucrados:

- `BillingPeriodFirestoreService`
- `BillingValueConfigFirestoreService`
- `PaymentMethodFirestoreService`
- `BillingObservationFirestoreService`
- `InvoiceFirestoreService`
- `InvoicePrintingService`

Colecciones relacionadas:

- `periodos`
- `periodos/{periodo}/recibos`
- `periodos/{periodo}/consumos`
- `medios_pago`
- `valores_facturacion`
- `facturacion_observaciones`

## Pantalla Facturacion

Archivo principal:

- `lib/features/billing/invoices/presentation/pages/billing_invoices_page.dart`

### Objetivo

Generar, regenerar, listar y exportar recibos por periodo.

### Que muestra

- selector de periodo
- resumen de pendientes listos, no preparados y recibos existentes
- acciones de:
  - `Generar recibos`
  - `Regenerar`
  - `PDF periodo`
  - `PDF por sector`
  - `No preparados`
- filtros visuales por sector
- lista de pendientes por facturar
- lista de recibos ya generados

### Reglas reales para facturar

Solo entran en la lista facturable las lecturas que cumplan:

- `facturado = false`
- `pagado = false`
- `isBlocked = false`
- `lecturaActual >= lecturaAnterior`

### Flujo Generar recibos

1. Seleccionar periodo.
2. Validar que existan lecturas listas.
3. Validar valores de facturacion vigentes.
4. Cargar medios de pago.
5. Cargar observaciones aplicables.
6. Construir un recibo por lectura.
7. Guardar recibo en `periodos/{periodo}/recibos`.
8. Marcar el consumo relacionado como facturado.

### Flujo Regenerar recibos

1. Seleccionar periodo.
2. Presionar `Regenerar`.
3. El sistema omite recibos ya pagados.
4. El sistema recompone datos no pagados con la configuracion vigente.
5. Si cambian los valores de facturacion, el recibo guarda un aviso visible.

### Exportacion PDF

Se soportan dos flujos:

- `PDF periodo`
  - un solo PDF con todos los recibos del periodo
  - o PDFs individuales
- `PDF por sector`
  - un solo PDF por sector
  - o PDFs individuales por usuario

### Validacion de pendientes no preparados

El boton `No preparados` lista usuarios del periodo que aun no cumplen condiciones para facturar. La generacion masiva se bloquea si existen pendientes no preparados.

## Reglas de calculo del recibo

Segun `InvoiceFirestoreService`:

- fecha de generacion: `DateTime.now()`
- fecha de vencimiento:
  - dia `24` del mismo mes de generacion del recibo
  - si la generacion supera el dia `20`, entonces `15` dias despues de la fecha generada
- `cargo fijo`: siempre se incluye
- `reconexion`: actualmente queda en `0`
- `saldoAnterior`: actualmente queda en `0`
- `mensaje`: texto institucional fijo
- `mediosPago`: snapshot de medios vigentes al momento de facturar
- `observaciones`: snapshot de observaciones aplicables al momento de facturar
- `sector`: snapshot del usuario al momento de facturar

## PDF del recibo

El servicio `InvoicePrintingService` genera recibos para administrador y cliente.

Incluye:

- encabezado institucional ajustado
- tabla principal reorganizada
- estado del periodo anterior:
  - `Al dia`
  - `En mora`
  - `Suspendido`
- descripcion de cobros
- discriminacion de valores
- medios de pago
- observaciones
- espacio acueducto con cuadro manual para recaudo

Comportamiento de `Valor pagado`:

- si el recibo no esta pagado, se deja en blanco para diligenciamiento manual
- si ya fue marcado como pagado, muestra `PAGADO`

## Pantalla Periodos

Archivo principal:

- `lib/features/billing/periods/presentation/pages/billing_periods_page.dart`

### Objetivo

Crear periodos mensuales y definir cual esta vigente.

### Reglas reales

- solo un periodo puede quedar `vigente`
- no hay edicion ni eliminacion

## Pantalla Medios de pago

Archivo principal:

- `lib/features/billing/payment_methods/presentation/pages/payment_methods_admin_page.dart`

### Objetivo

Registrar instrucciones de pago en texto libre.

### Uso real

- se listan en el recibo
- se guardan como snapshot al facturar
- tambien pueden usarse al registrar pagos

## Pantalla Observaciones

Archivo principal:

- `lib/features/billing/observations/presentation/pages/billing_observations_admin_page.dart`

### Objetivo

Registrar mensajes que deben quedar pegados al recibo del periodo.

### Tipos soportados

- masiva
- individual

### Reglas reales

- puede aplicarse a un periodo especifico
- la masiva tambien puede marcarse como permanente
- la individual se asocia a un usuario
- al facturar, la observacion queda copiada dentro del recibo

## Pantalla Valores

Archivo principal:

- `lib/features/billing/values/presentation/pages/billing_values_admin_page.dart`

### Objetivo

Mantener la configuracion vigente de cobro.

### Regla de versionado

Cada guardado crea una nueva version activa y desactiva la anterior.

## Pantalla Cliente

Archivo principal:

- `lib/features/billing/invoices/presentation/pages/client_invoice_page.dart`

### Objetivo

Mostrar al cliente su recibo pendiente mas reciente.

### Reglas reales

- busca en `collectionGroup('recibos')`
- filtra por `codigoUsuario`
- filtra por `pagado = false`
- devuelve el recibo pendiente mas reciente
- puede abrir PDF

## Estado del modulo

El modulo de facturacion quedo operativo para el alcance funcional definido.
