# Modulo Cuentas

## Alcance

Ruta:

- `Panel principal > Cuentas`

Pantallas:

1. `Cuentas`
2. `Registrar pagos`
3. `Extraordinarios`

## Colecciones relacionadas

- `periodos/{periodo}/recibos`
- `periodos/{periodo}/consumos`
- `cuentas_movimientos`
- `valores_facturacion`

## Modelo contable

La cuenta del usuario se calcula a partir de movimientos en `cuentas_movimientos`.

Tipos principales:

- `factura`: cargo generado por recibo.
- `pago`: pago recibido.
- `reverso_pago`: ajuste cuando se corrige o revierte un pago.

Convencion de signos:

- valores positivos: deuda o cargo para el usuario;
- valores negativos: pago o saldo a favor.

## Pantalla Cuentas

Archivo:

- `lib/features/accounts/presentation/pages/accounts_overview_page.dart`

Objetivo:

- revisar por periodo el estado financiero de usuarios facturados;
- ver al dia, en mora, suspendidos y saldos a favor;
- buscar por usuario, codigo, contador o sector.

Muestra:

- total a pagar;
- valor pagado;
- saldo pendiente;
- balance de cuenta;
- saldo a favor cuando exista.

## Pantalla Registrar pagos

Archivo:

- `lib/features/accounts/presentation/pages/account_payments_page.dart`
- reutiliza `lib/features/consumptions/presentation/pages/consumption_payments_page.dart`

Objetivo:

- registrar pagos reales contra recibos generados.

Reglas:

- si el pago es igual al total, el recibo queda `pagado`;
- si el pago es menor, queda saldo pendiente y estado de mora;
- si el pago es mayor, el excedente queda como saldo a favor;
- el saldo a favor se aplica al siguiente recibo;
- el pago guarda medio de pago y observaciones cuando aplique;
- el movimiento queda trazado con actor administrador.

Efectos tecnicos:

- actualiza el recibo;
- actualiza el consumo asociado;
- crea o actualiza movimiento `factura`;
- crea movimiento `pago` o `reverso_pago`.

## Pantalla Extraordinarios

Archivo:

- `lib/features/accounts/presentation/pages/extraordinary_values_page.dart`

Objetivo:

- administrar cargos adicionales del periodo;
- registrar saldos iniciales, cuotas extraordinarias, multas u otros conceptos.

Reglas:

- usa periodos operativos desde `2026-01`;
- no permite seleccionar `2025-12`;
- el formulario masivo queda fijo como masivo;
- el formulario individual queda fijo como individual;
- el cargo individual permite buscar usuario por nombre, codigo de usuario y sector;
- guarda los cargos como `valoresAdicionales` dentro de la configuracion de valores de facturacion, sin cambiar el modelo historico de facturacion.

## Flujo de saldo a favor

Ejemplo:

1. Recibo actual: `$20.000`.
2. Pago recibido: `$30.000`.
3. Se genera saldo a favor: `$10.000`.
4. Siguiente recibo con cargos por `$15.000`.
5. El recibo muestra saldo a favor aplicado por `$10.000`.
6. Total a pagar: `$5.000`.

## Estado

El modulo queda operativo para pagos reales, abonos, saldos pendientes, saldos a favor, cargos extraordinarios y revision de cuentas por periodo.
