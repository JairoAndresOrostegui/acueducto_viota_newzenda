# Manual Administrador

## Perfil

El administrador entra al panel principal con seis macromodulos:

1. `Usuarios`
2. `Consumos`
3. `Cuentas`
4. `Facturacion`
5. `Gastos`
6. `Reportes`

Algunas pantallas sensibles solo son visibles si el usuario tiene `superAdmin = true`.

## Flujo recomendado

1. Revisar catalogos y usuarios.
2. Importar o unificar usuarios si aplica.
3. Crear o activar el periodo de trabajo.
4. Confirmar valores de facturacion, medios de pago y observaciones.
5. Registrar o importar consumos.
6. Resolver conflictos.
7. Generar recibos.
8. Registrar pagos en `Cuentas > Registrar pagos`.
9. Revisar saldos en `Cuentas > Cuentas`.
10. Aplicar extraordinarios si corresponde.
11. Revisar suspensiones.
12. Registrar gastos y soportes del periodo.
13. Consultar reportes de facturacion, consumos, cartera, extraordinarios y gastos.
14. Exportar PDF o Excel cuando haga falta.

## Usuarios

Pantallas:

- `Usuarios`
- `Importar usuarios`
- `Tipos documento`, solo `superAdmin`
- `Roles`, solo `superAdmin`
- `Sectores`
- `Logs`, solo `superAdmin`

Puede:

- crear, editar y eliminar usuarios;
- administrar clientes con varios codigos de usuario;
- importar usuarios desde Excel;
- unificar usuarios importados por documento;
- administrar catalogos activos;
- consultar auditoria.

Accion especial `superAdmin`:

- `Limpiar cuenta`: borra recibos, pagos, saldos y movimientos de un cliente de prueba, conservando usuario y consumos.

## Consumos

Pantallas:

- `Conflictos`
- `Registrar consumos`
- `Importar consumos`
- `Suspensiones`

Puede:

- resolver conflictos;
- consultar historico de conflictos resueltos;
- registrar lecturas desde la app;
- importar lecturas desde Excel;
- suspender o levantar suspension segun corresponda.

Notas:

- `2025-12` se usa como base historica para lecturas.
- Los modulos operativos de facturacion/cuentas trabajan desde `2026-01`.

## Cuentas

Pantallas:

- `Cuentas`
- `Registrar pagos`
- `Extraordinarios`

Puede:

- registrar pagos reales;
- registrar abonos parciales;
- generar saldos a favor por sobrepago;
- revisar balance de cuenta por periodo;
- consultar usuarios al dia, en mora, suspendidos o con saldo a favor;
- crear cargos extraordinarios masivos o individuales.

Regla central:

- Los pagos crean movimientos en `cuentas_movimientos`; ya no son solo un booleano de pagado/no pagado.

## Facturacion

Pantallas:

- `Facturacion`
- `Periodos`
- `Medios de pago`
- `Observaciones`
- `Valores`

Puede:

- crear periodos y marcar uno como vigente;
- definir valores de facturacion versionados;
- administrar medios de pago;
- administrar observaciones;
- generar recibos masivos o individuales;
- regenerar recibos no pagados;
- exportar PDF por periodo o sector;
- abrir PDF individual.

Reglas:

- Los recibos pagados no se regeneran.
- Si hay saldo a favor, se aplica en el siguiente recibo.
- Si hay saldo pendiente, se arrastra como saldo anterior.
- Al cumplir mora suficiente, el estado puede pasar a `suspendido`.

## Gastos

Pantallas:

- `Conceptos`
- `Gastos`
- `Soportes`

Puede:

- crear, editar, habilitar e inhabilitar conceptos de gasto;
- registrar gastos por periodo;
- editar gastos existentes;
- cargar soporte PDF por periodo;
- reemplazar soporte PDF existente;
- consultar y exportar reporte de gastos.

Reglas:

- Los conceptos inactivos no aparecen para registrar nuevos gastos.
- Los soportes deben ser PDF validos.
- Solo hay un soporte activo por periodo.

## Reportes

Pantallas:

- `Facturacion`
- `Consumos`
- `Cartera`
- `Extraordinarios`
- `Gastos`

Puede:

- exportar Excel de recibos emitidos;
- exportar Excel de lecturas y consumos;
- exportar Excel de cartera por periodo o consolidada;
- exportar Excel de cargos extraordinarios;
- exportar Excel de gastos.

## Estado

El perfil `administrador` cubre el flujo operativo, financiero y documental principal del sistema.
