# Manual Contador

## Acceso

El perfil `contador` inicia sesion normalmente, pero su acceso esta restringido a un unico flujo:

- `Consumos > Reportes`

No puede entrar a:

- usuarios
- registrar consumos
- importar consumos
- conflictos
- registrar pagos
- suspensiones
- facturacion administrativa

## Que puede consultar

En la pantalla de reportes puede:

- filtrar por periodo
- filtrar por codigo de usuario
- revisar solo irregularidades
- ver lecturas consultadas
- ver recibos pendientes
- ver cartera pendiente
- exportar el reporte de lecturas a CSV

## Informe de cartera pendiente

El informe muestra:

- cantidad de recibos pendientes
- total de cartera pendiente
- detalle por usuario
- periodo del recibo
- estado
- vencimiento
- total facturado
- saldo anterior
- valor registrado
- saldo pendiente

## Limitaciones actuales

- Tiene acceso de solo lectura.
- No puede registrar pagos.
- No puede editar consumos.
- No puede generar ni regenerar recibos.
- No puede suspender facturas.
- No existe todavia un modulo contable financiero mas profundo por medio de pago, cierres o conciliaciones.

## Estado

Para el alcance solicitado, el perfil `contador` queda funcional para reportes y cartera.
