# Manual Administrador

## Perfil

El administrador entra al panel con tres grupos:

1. `Usuarios`
2. `Consumos`
3. `Facturacion`

## Flujo recomendado de operacion

1. revisar catalogos y usuarios
2. crear o activar el periodo de trabajo
3. confirmar valores de facturacion, medios de pago y observaciones
4. esperar a que el operador descargue el periodo y suba lecturas
5. resolver conflictos si aparecen
6. revisar reportes
7. facturar consumos pendientes
8. regenerar recibos no pagados si hubo cambios
9. registrar pagos
10. exportar PDF o CSV si hace falta

## Usuarios

Puede:

- crear, editar y eliminar usuarios
- administrar tipos de documento, roles y sectores
- consultar logs

## Consumos

Puede:

- revisar y resolver conflictos
- consultar reportes
- exportar CSV
- registrar y revertir pagos

Notas:

- al registrar pago puede capturar el valor realmente pagado
- ese valor queda guardado en recibos y consumos

## Facturacion

Puede:

- crear periodos y marcar uno como vigente
- definir valores de facturacion
- administrar medios de pago
- administrar observaciones de facturacion
- generar recibos masivos o individuales
- regenerar recibos no pagados
- exportar PDF por periodo o por sector
- abrir recibos individuales en PDF

## Reglas clave

- no se deben facturar lecturas bloqueadas
- un recibo pagado no se regenera
- si cambian los valores de facturacion, el recibo regenerado deja aviso
- el vencimiento se calcula con la fecha de generacion del recibo

## Estado

El perfil `administrador` ya tiene cubierto el flujo operativo principal del sistema.
