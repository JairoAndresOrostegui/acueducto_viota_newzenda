# Manual Administrador

## Perfil

El administrador entra al panel principal con cinco macromodulos:

1. `Usuarios`
2. `Consumos`
3. `Cuentas`
4. `Facturacion`
5. `Reportes`

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
12. Consultar reportes de facturacion, consumos y cartera.
13. Exportar PDF o Excel cuando haga falta.

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

## Reportes

Pantallas:

- `Facturacion`
- `Consumos`
- `Cartera`

Puede:

- exportar Excel de recibos emitidos;
- exportar Excel de lecturas y consumos;
- exportar Excel de cartera por periodo o consolidada.

## Estado

El perfil `administrador` cubre el flujo operativo principal y financiero basico del sistema.
