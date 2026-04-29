# Manual Operador

## Perfil

El operador entra directamente a `Registrar consumos`.

## Que puede hacer

- Descargar el periodo vigente al dispositivo.
- Consultar clientes y contadores descargados.
- Registrar lecturas localmente.
- Reportar irregularidades.
- Ver solo clientes con irregularidades del periodo.
- Subir lecturas al sistema.

## Flujo de trabajo

1. Presionar `Descargar periodo vigente`.
2. Buscar cliente, codigo de usuario o contador.
3. Revisar lectura anterior.
4. Registrar lectura actual.
5. Si hay novedad, marcar irregularidad y describirla.
6. Repetir hasta completar el recorrido.
7. Usar `Lecturas pendientes` para revisar clientes sin lectura.
8. Usar `Irregularidades` para revisar novedades reportadas.
9. Presionar `Subir lecturas`.
10. Revisar el resumen final.

## Reglas importantes

- No puede descargar otro periodo si aun tiene lecturas locales pendientes por subir.
- El periodo de trabajo descargado se mantiene localmente hasta descargar otro.
- Si una lectura entra en conflicto, queda bloqueada para revision del administrador.
- No puede modificar lecturas ya facturadas, pagadas o suspendidas.
- `Pendientes por subir` solo cuenta lecturas capturadas localmente y aun no sincronizadas.

## Casos tipicos de conflicto

- Ya existe una lectura oficial para ese contador y periodo.
- La lectura nueva es menor a la lectura anterior oficial.

## Recomendaciones

- Revise la lectura anterior antes de guardar.
- Use observaciones cuando haya una novedad relevante.
- Reporte irregularidad cuando el contador no permita una lectura normal.
- Sincronice al terminar el recorrido para evitar acumulacion local.
