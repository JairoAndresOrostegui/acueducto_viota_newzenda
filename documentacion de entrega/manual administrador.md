# Manual Administrador

## Perfil

El administrador entra al panel principal con tres grupos:

1. `Usuarios`
2. `Consumos`
3. `Facturacion`

## Flujo recomendado

1. Revisar catalogos y usuarios.
2. Importar usuarios si aplica.
3. Crear o activar el periodo de trabajo.
4. Confirmar valores de facturacion, medios de pago y observaciones.
5. Descargar o importar consumos.
6. Resolver conflictos si aparecen.
7. Revisar reportes.
8. Generar recibos.
9. Regenerar recibos no pagados si hubo cambios, de forma masiva o individual.
10. Registrar pagos.
11. Suspender facturas en mora cuando aplique.
12. Exportar PDF o CSV si hace falta.

## Usuarios

Pantallas:

- `Usuarios`
- `Importar usuarios`
- `Tipos documento`
- `Roles`
- `Sectores`
- `Logs`

Puede:

- crear, editar y eliminar usuarios
- importar clientes desde Excel
- administrar catalogos activos
- consultar auditoria de cambios

## Consumos

Pantallas:

- `Conflictos`
- `Registrar consumos`
- `Importar consumos`
- `Reportes`
- `Registrar pagos`
- `Suspensiones`

Puede:

- revisar y resolver conflictos
- registrar lecturas desde la app
- importar lecturas desde Excel
- consultar reportes
- exportar CSV
- registrar y revertir pagos
- suspender facturas en mora
- filtrar suspensiones por `Todos`, `Al día`, `En mora` y `Suspendidas`

Notas:

- Al registrar pago puede capturar el valor realmente pagado.
- El valor queda guardado en recibos y consumos.
- Las suspensiones solo se habilitan para facturas no pagadas con mora anterior.

## Facturacion

Pantallas:

- `Facturacion`
- `Periodos`
- `Medios de pago`
- `Observaciones`
- `Valores`

Puede:

- crear periodos y marcar uno como vigente
- definir valores de facturacion versionados
- administrar medios de pago
- administrar observaciones masivas e individuales
- generar recibos masivos o individuales
- regenerar recibos no pagados de forma masiva o individual
- exportar PDF por periodo o por sector
- abrir recibos individuales en PDF

## Reglas clave

- No se deben facturar lecturas bloqueadas.
- Un recibo pagado no se regenera.
- La regeneracion individual permite corregir casos puntuales sin recalcular todo el periodo.
- Si cambian los valores de facturacion, el recibo regenerado deja aviso.
- El vencimiento se calcula con la fecha de generacion del recibo.
- La facturacion contable inicia en `2026-01`.
- `2025-12` no entra en cartera; se usa como base historica.
- El contador solo consulta reportes y cartera.
- El cliente solo ve su recibo pendiente mas reciente.

## Estado

El perfil `administrador` tiene cubierto el flujo operativo principal del sistema.
