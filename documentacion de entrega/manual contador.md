# Manual Contador

## Acceso

El perfil `contador` inicia sesion normalmente y tiene acceso de consulta.

Modulo principal:

- `Reportes`

Pantallas:

- `Facturacion`
- `Consumos`
- `Cartera`

No puede:

- administrar usuarios;
- registrar consumos;
- importar consumos;
- resolver conflictos;
- registrar pagos;
- suspender usuarios;
- generar o regenerar recibos;
- modificar configuraciones.

## Reporte Facturacion

Puede consultar:

- recibos emitidos por periodo;
- total facturado;
- total a pagar;
- valor pagado;
- estados de recibo;
- consumo m3 asociado;
- valores adicionales;
- saldo anterior o saldo a favor aplicado.

Puede exportar Excel.

## Reporte Consumos

Puede consultar:

- lecturas por periodo;
- lectura anterior;
- lectura actual;
- consumo m3;
- irregularidades;
- estado de facturacion;
- estado de pago.

Puede exportar Excel.

## Reporte Cartera

Puede consultar:

- cartera por periodo;
- cartera consolidada de todos los periodos;
- saldos pendientes;
- saldos a favor;
- pagos registrados;
- usuarios suspendidos;
- usuarios al dia o en mora.

Puede exportar Excel.

## Limitaciones

El perfil es de solo lectura. No registra pagos ni modifica estados.

## Estado

El perfil `contador` queda funcional para revision de facturacion, consumos y cartera.
