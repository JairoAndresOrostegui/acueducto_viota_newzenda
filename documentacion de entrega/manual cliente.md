# Manual Cliente

## Perfil

El cliente entra directamente a la consulta de sus recibos pendientes.

## Que puede hacer

- Ver recibos pendientes asociados a sus codigos de usuario.
- Revisar periodo, lecturas y consumo.
- Consultar saldo anterior o saldo a favor aplicado.
- Consultar total a pagar.
- Consultar fecha de vencimiento.
- Ver medios de pago.
- Abrir el recibo en PDF.

## Flujo de uso

1. Iniciar sesion.
2. Revisar si existen recibos pendientes.
3. Validar datos del recibo:
   - codigo de usuario;
   - contador;
   - sector;
   - periodo;
   - lectura anterior;
   - lectura actual;
   - consumo;
   - saldo anterior o saldo a favor;
   - total a pagar;
   - fecha de vencimiento.
4. Revisar medios de pago.
5. Abrir PDF si necesita copia.

## Reglas importantes

- Solo ve recibos asociados a sus codigos de usuario.
- Puede tener varios codigos y por tanto varios recibos pendientes.
- La consulta descarta periodos anteriores a `2026-01`.
- Si no tiene recibos pendientes, la pantalla muestra un mensaje informativo.
- El cliente no registra pagos ni cambia estados desde la app.

## Saldos

- Si debe de meses anteriores, el recibo muestra saldo anterior.
- Si pago de mas en un periodo anterior, el recibo muestra saldo a favor aplicado.
- El total a pagar ya descuenta el saldo a favor.
