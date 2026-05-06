# Modulo Facturacion

## Alcance

Ruta:

- `Panel principal > Facturacion`

Pantallas:

1. `Facturacion`
2. `Periodos`
3. `Medios de pago`
4. `Observaciones`
5. `Valores`

## Servicios

- `BillingPeriodFirestoreService`
- `BillingValueConfigFirestoreService`
- `PaymentMethodFirestoreService`
- `BillingObservationFirestoreService`
- `InvoiceFirestoreService`
- `InvoicePrintingService`

## Colecciones

- `periodos`
- `periodos/{periodo}/recibos`
- `periodos/{periodo}/consumos`
- `medios_pago`
- `valores_facturacion`
- `facturacion_observaciones`
- `cuentas_movimientos`

## Facturacion

Archivo:

- `lib/features/billing/invoices/presentation/pages/billing_invoices_page.dart`

Objetivo:

- generar, regenerar, listar y exportar recibos por periodo.

Acciones:

- generar recibos masivos;
- generar recibo individual;
- regenerar recibos no pagados;
- regenerar recibo individual;
- exportar PDF por periodo;
- exportar PDF por sector;
- abrir PDF individual.

Reglas:

- solo se facturan periodos contables desde `2026-01`;
- `2025-12` es solo base historica;
- no se facturan lecturas bloqueadas;
- no se regeneran recibos pagados;
- el recibo toma valores, medios de pago y observaciones como snapshot;
- el recibo toma el balance de cuenta para saldo anterior o saldo a favor.

## Calculo del recibo

Componentes:

- cargo fijo;
- consumo por rangos;
- valores adicionales;
- reconexion, actualmente `0`;
- saldo anterior o saldo a favor aplicado;
- total a pagar.

Reglas de saldo:

- si la cuenta trae deuda, se muestra como `Saldo anterior`;
- si la cuenta trae credito, se muestra como `Saldo a favor`;
- `totalAPagar = max(total + saldoAnterior + reconexion, 0)`;
- un saldo a favor puede reducir el total a pagar del siguiente recibo.

## Pago y estado

El pago no se registra en este modulo. Se registra en:

- `Cuentas > Registrar pagos`

Estados relevantes:

- `facturado`
- `pagado`
- `en_mora`
- `suspendido`

Si un usuario acumula mora suficiente, la generacion/regeneracion puede marcar el recibo como `suspendido`. Los cobros siguen acumulando.

## PDF del recibo

Archivo:

- `lib/features/billing/invoices/presentation/services/invoice_printing_service.dart`

Incluye:

- datos institucionales;
- datos del usuario;
- codigo de usuario;
- contador;
- sector;
- periodo;
- lecturas;
- consumo;
- detalle de cobros;
- saldo anterior o saldo a favor;
- total a pagar;
- medios de pago;
- observaciones.

## Periodos

Archivo:

- `lib/features/billing/periods/presentation/pages/billing_periods_page.dart`

Reglas:

- permite crear periodos mensuales;
- solo un periodo queda vigente;
- el historial inicia en `2025-12`;
- los modulos contables trabajan desde `2026-01`.

## Medios de pago

Archivo:

- `lib/features/billing/payment_methods/presentation/pages/payment_methods_admin_page.dart`

Uso:

- se muestran en PDF;
- se guardan como snapshot al facturar;
- se ofrecen al registrar pago.

## Observaciones

Archivo:

- `lib/features/billing/observations/presentation/pages/billing_observations_admin_page.dart`

Tipos:

- masiva;
- individual;
- permanente.

## Valores

Archivo:

- `lib/features/billing/values/presentation/pages/billing_values_admin_page.dart`

Incluye:

- cargo fijo;
- reconexion;
- rangos de consumo.

Los valores adicionales fueron formalizados en:

- `Cuentas > Extraordinarios`

## Estado

El modulo queda dedicado a configuracion y generacion de facturacion. Pagos, cartera y reportes se gestionan desde `Cuentas` y `Reportes`.
