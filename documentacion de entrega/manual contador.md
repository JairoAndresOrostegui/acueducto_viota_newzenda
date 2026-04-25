# Manual Contador

## Acceso

El perfil `contador` inicia sesion normalmente, pero su acceso esta restringido a un unico flujo:

- `Consumos > Reportes`

No puede entrar a:

- usuarios
- registrar consumos
- conflictos
- registrar pagos
- facturacion administrativa

## Que puede consultar

En la pantalla de reportes puede:

- filtrar por periodo
- filtrar por codigo de usuario
- revisar solo irregularidades
- ver lecturas consultadas
- ver cartera pendiente
- exportar el reporte de lecturas a CSV

## Informe de cartera pendiente

El informe muestra:

- cantidad de recibos pendientes
- total de cartera pendiente
- detalle por usuario
- periodo del recibo
- vencimiento
- valor facturado
- valor registrado
- saldo pendiente

## Limitaciones actuales

- el contador tiene acceso de solo lectura
- no puede registrar pagos
- no puede editar consumos
- no puede generar o regenerar recibos
- no existe todavia un modulo contable financiero mas profundo por medio de pago, cierres o conciliaciones

## Estado

Para el alcance solicitado en esta iteracion, el perfil `contador` ya quedo funcional.
