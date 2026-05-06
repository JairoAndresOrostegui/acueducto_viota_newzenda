# Modulo Reportes

## Alcance

Ruta:

- `Panel principal > Reportes`

Pantallas:

1. `Facturacion`
2. `Consumos`
3. `Cartera`

El modulo separa responsabilidades. No mezcla cartera dentro de facturacion ni datos financieros dentro del reporte de consumos.

## Facturacion

Archivo:

- `lib/features/reports/presentation/pages/billing_reports_page.dart`

Objetivo:

- consultar recibos emitidos por periodo.

Incluye:

- cantidad de recibos;
- total facturado;
- total a pagar;
- valor pagado;
- estado del recibo;
- consumo m3;
- cargo fijo;
- valor de consumo;
- valores adicionales;
- saldo anterior;
- saldo a favor aplicado;
- saldo pendiente.

Filtros:

- periodo;
- todos;
- pagados;
- pendientes;
- suspendidos;
- busqueda por usuario, codigo, contador o sector.

Exporta:

- Excel `reporte_facturacion_{periodo}.xlsx`.

## Consumos

Archivo:

- `lib/features/reports/presentation/pages/consumption_reports_placeholder_page.dart`

Objetivo:

- consultar lecturas y consumos m3 por periodo.

Incluye:

- lectura anterior;
- lectura actual;
- consumo calculado;
- estado de consumo;
- facturado;
- pagado;
- irregularidad;
- observaciones operario;
- observaciones administrador.

Filtros:

- periodo;
- todos;
- facturados;
- sin facturar;
- pagados;
- solo irregularidades;
- busqueda por usuario, codigo, contador o sector.

Exporta:

- Excel `reporte_consumos_{periodo}.xlsx`.

## Cartera

Archivo:

- `lib/features/reports/presentation/pages/portfolio_reports_page.dart`

Objetivo:

- consultar deuda, pagos, saldos a favor y suspendidos.

Incluye:

- periodo;
- total a pagar;
- valor pagado;
- saldo pendiente;
- balance de cuenta;
- saldo a favor;
- pagos registrados;
- estado;
- fecha de vencimiento.

Filtros:

- periodo;
- todos los periodos;
- en mora;
- al dia;
- saldo a favor;
- suspendidos;
- todos;
- busqueda por usuario, codigo, contador o sector.

Exporta:

- Excel `reporte_cartera_{periodo}.xlsx`;
- Excel `reporte_cartera_todos.xlsx` cuando se activa todos los periodos.

## Estado

Los tres reportes quedan listos para validacion operativa. La generacion y manejo de PDF de recibos no se modifica desde este modulo.
