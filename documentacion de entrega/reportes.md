# Modulo Reportes

## Alcance

Ruta administrador:

- `Panel principal > Reportes`

Ruta tesorero:

- `Panel principal > Reportes`

Ruta contador/fiscal:

- `Panel principal > Reportes`

Pantallas para administrador y tesorero:

1. `Facturacion`
2. `Consumos`
3. `Cartera`
4. `Extraordinarios`
5. `Gastos`

Pantallas para contador y fiscal:

1. `Consumos`
2. `Extraordinarios`
3. `Gastos`

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

Archivos:

- `lib/features/reports/presentation/pages/consumption_reports_placeholder_page.dart`
- `lib/features/consumptions/presentation/pages/consumption_reports_admin_page.dart`

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

## Extraordinarios

Archivo:

- `lib/features/reports/presentation/pages/extraordinary_reports_page.dart`

Objetivo:

- consultar cargos extraordinarios configurados para un periodo.

Incluye:

- periodo;
- codigo de usuario;
- nombre e identificacion del usuario cuando aplica;
- sector;
- contador;
- alcance masivo o individual;
- concepto;
- valor;
- total del periodo.

Exporta:

- Excel `reporte_extraordinarios_{periodo}.xlsx`.

## Gastos

Archivo:

- `lib/features/reports/presentation/pages/expense_reports_page.dart`

Objetivo:

- consultar egresos registrados por periodo.

Incluye:

- periodo;
- concepto;
- valor;
- fecha del gasto;
- beneficiario;
- identificacion del beneficiario;
- usuario que registro;
- fecha de registro;
- usuario y fecha de actualizacion cuando aplique;
- total del periodo.

Exporta:

- Excel `reporte_gastos_{periodo}.xlsx`.

## Estado

Los reportes quedan listos para validacion operativa y contable. La generacion y manejo de PDF de recibos no se modifica desde este modulo.
