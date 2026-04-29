# Manual Cliente

## Perfil

El cliente entra directamente a la consulta de su recibo pendiente.

## Que puede hacer

- Ver su recibo pendiente de pago mas reciente.
- Revisar periodo, lecturas y consumo.
- Consultar saldo anterior, total facturado y total a pagar.
- Consultar fecha de vencimiento.
- Ver medios de pago.
- Abrir el recibo en PDF.

## Flujo de uso

1. Iniciar sesion con correo y clave.
2. Revisar si existe un recibo pendiente.
3. Validar datos del recibo:
   - codigo de usuario
   - contador
   - periodo
   - lectura anterior
   - lectura actual
   - consumo
   - saldo anterior
   - total a pagar
   - fecha de vencimiento
4. Revisar medios de pago.
5. Si necesita copia, presionar `PDF`.

## Reglas importantes

- Solo puede ver recibos asociados a su `codigoUsuario`.
- Solo ve recibos pendientes.
- La consulta descarta periodos anteriores a `2026-01`.
- Si no tiene recibos pendientes, la pantalla muestra un mensaje informativo.
- El cliente no registra pagos, no genera recibos y no cambia estados desde la app.
