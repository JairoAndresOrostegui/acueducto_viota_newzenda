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

Objetivo:

- Generar, regenerar, listar y exportar recibos por periodo.

Muestra:

- selector de periodo
- pendientes listos
- lecturas no preparadas
- recibos generados
- filtros visuales por sector
- tarjetas de recibos con estado, usuario, contador, lecturas, saldo anterior y total

Acciones:

- `Generar recibos`
- `Generar individual`
- `Regenerar` periodo
- `Regenerar` individual
- `PDF periodo`
- `PDF por sector`
- `No preparados`
- `PDF` individual

Reglas para facturar:

- `facturado = false`
- `pagado = false`
- `isBlocked = false`
- `lecturaActual >= lecturaAnterior`
- periodo contable desde `2026-01`

## Flujo Generar recibos

1. Seleccionar periodo.
2. Validar lecturas listas.
3. Validar valores de facturacion vigentes.
4. Cargar medios de pago.
5. Cargar observaciones aplicables.
6. Construir recibos.
7. Guardar en `periodos/{periodo}/recibos`.
8. Marcar consumos como facturados.

## Flujo Regenerar recibos

1. Seleccionar periodo.
2. Presionar `Regenerar`.
3. Omitir recibos pagados.
4. Recalcular recibos no pagados con valores vigentes.
5. Guardar aviso si cambiaron valores de facturacion.

## Flujo Regenerar recibo individual

1. Seleccionar periodo.
2. Ubicar el recibo generado.
3. Presionar `Regenerar` en la tarjeta del recibo.
4. Confirmar la accion.
5. Recalcular solo ese recibo con valores vigentes, observaciones, medios de pago y recibo anterior.
6. Recargar la informacion del periodo.

Reglas:

- El boton queda deshabilitado si el recibo esta pagado.
- Si se intenta regenerar un recibo pagado, el servicio lo rechaza.
- Si no existe lectura asociada al contador del recibo, la regeneracion individual se detiene.
- Sirve para casos puntuales como conflictos corregidos o pagos registrados en meses anteriores sin regenerar todo el periodo.

## Exportacion PDF

Opciones:

- `PDF periodo`: un solo PDF o PDFs individuales.
- `PDF por sector`: un solo PDF del sector o PDFs individuales por usuario.
- `PDF` individual desde una tarjeta de recibo.

## Reglas de calculo del recibo

Segun `InvoiceFirestoreService`:

- fecha de generacion: `DateTime.now()`
- fecha de vencimiento:
  - dia `24` del mismo mes si la generacion ocurre hasta el dia `20`
  - 15 dias despues si la generacion ocurre despues del dia `20`
- `cargo fijo`: siempre se incluye
- rangos de consumo: se calculan segun configuracion vigente
- valores adicionales: se aplican por periodo y usuario cuando correspondan
- `reconexion`: actualmente queda en `0`
- `saldoAnterior`: saldo pendiente del recibo anterior contable
- `totalAPagar`: `total + saldoAnterior + reconexion`
- `mediosPago`: snapshot al facturar
- `observaciones`: snapshot al facturar
- `sector`: snapshot del usuario al facturar
- `estadoPeriodoAnterior`: `al_dia`, `en_mora` o `suspendido`
- Presentacion visible: `al_dia` se muestra como `Al día` y `en_mora` como `En mora`.

## PDF del recibo

Archivo principal:

- `lib/features/billing/invoices/presentation/services/invoice_printing_service.dart`

Incluye:

- encabezado institucional
- datos del usuario y contador
- periodo facturado
- estado del periodo anterior
- lectura anterior, lectura actual y consumo
- discriminacion de cobros
- saldo anterior
- total a pagar
- medios de pago
- observaciones
- espacio manual de recaudo

Comportamiento de `Valor pagado`:

- si el recibo no esta pagado, se deja en blanco para diligenciamiento manual
- si ya fue marcado como pagado, muestra `PAGADO`

## Pantalla Periodos

Archivo principal:

- `lib/features/billing/periods/presentation/pages/billing_periods_page.dart`

Objetivo:

- Crear periodos mensuales y definir cual esta vigente.

Reglas:

- Solo un periodo puede quedar `vigente`.
- No hay eliminacion desde la pantalla.

## Pantalla Medios de pago

Archivo principal:

- `lib/features/billing/payment_methods/presentation/pages/payment_methods_admin_page.dart`

Objetivo:

- Registrar instrucciones de pago en texto libre.

Uso:

- Se listan en el recibo.
- Se guardan como snapshot al facturar.
- Se ofrecen al registrar pagos.

## Pantalla Observaciones

Archivo principal:

- `lib/features/billing/observations/presentation/pages/billing_observations_admin_page.dart`

Objetivo:

- Registrar mensajes para recibos.

Tipos:

- masiva
- individual

Reglas:

- Puede aplicar a un periodo especifico.
- La masiva puede marcarse como permanente.
- La individual se asocia a un usuario.
- Al facturar, la observacion queda copiada dentro del recibo.

## Pantalla Valores

Archivo principal:

- `lib/features/billing/values/presentation/pages/billing_values_admin_page.dart`

Objetivo:

- Mantener la configuracion vigente de cobro.

Incluye:

- cargo fijo
- reconexion
- rangos de consumo
- valores adicionales por periodo y usuario

Regla de versionado:

- Cada guardado crea una nueva version activa y desactiva la anterior.

## Pantalla Cliente

Archivo principal:

- `lib/features/billing/invoices/presentation/pages/client_invoice_page.dart`

Objetivo:

- Mostrar al cliente su recibo pendiente mas reciente.

Reglas:

- Busca en `collectionGroup('recibos')`.
- Filtra por `codigoUsuario`.
- Filtra por `pagado = false`.
- Descarta periodos anteriores a `2026-01`.
- Devuelve el recibo pendiente mas reciente.
- Permite abrir PDF.

## Estado del modulo

El modulo de facturacion queda operativo para valores, periodos, recibos, PDF, cartera, pagos y soporte de suspensiones.
