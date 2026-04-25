# Manual Operador

## Perfil

El operador entra directamente a `Registrar consumos`.

## Que puede hacer

- Descargar el periodo vigente al dispositivo.
- Consultar clientes y contadores descargados.
- Registrar lecturas localmente.
- Reportar irregularidades.
- Subir lecturas al sistema.

## Flujo de trabajo

1. Presionar `Descargar periodo vigente`.
2. Buscar un cliente o contador.
3. Registrar lectura.
4. Si hay novedad, marcar irregularidad y describirla.
5. Repetir hasta completar el recorrido.
6. Presionar `Subir lecturas`.
7. Revisar el resumen final.

## Reglas importantes

- No puede descargar otro periodo si aun tiene lecturas locales pendientes por subir.
- El periodo de trabajo descargado se mantiene localmente hasta que descargue otro.
- Si una lectura entra en conflicto, quedara bloqueada y debe informar al administrador.
- No puede modificar lecturas ya facturadas o pagadas.

## Casos tipicos de conflicto

- Ya existe una lectura oficial para ese contador y periodo.
- La lectura nueva es menor a la lectura anterior oficial.

## Recomendaciones

- Revise la lectura anterior antes de guardar.
- Use observaciones cuando haya una novedad relevante.
- Reporte irregularidad cuando el contador no permita una lectura normal.
