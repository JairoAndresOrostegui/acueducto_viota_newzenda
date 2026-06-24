# Manual Tesorero

## Perfil

El perfil `tesorero` entra al panel principal con dos macromodulos:

1. `Gastos`
2. `Reportes`

## Gastos

Pantallas:

- `Gastos`
- `Soportes`

Puede:

- seleccionar periodo operativo;
- registrar gastos por concepto activo;
- consultar gastos del periodo;
- buscar por concepto, beneficiario, identificacion o registrante;
- cargar soporte PDF cuando el periodo no tiene soporte;
- consultar soporte cargado.

No puede:

- crear o editar conceptos de gasto;
- editar gastos existentes;
- reemplazar un soporte ya cargado.

## Reportes

Pantallas:

- `Facturacion`
- `Consumos`
- `Cartera`
- `Extraordinarios`
- `Gastos`

Puede:

- consultar y exportar facturacion por periodo;
- consultar y exportar consumos;
- consultar y exportar cartera;
- consultar y exportar extraordinarios;
- consultar y exportar gastos.

## Reglas importantes

- Solo usuarios con rol `tesorero` y estado `activo` pueden acceder.
- Los soportes deben ser PDF validos y menores a 20 MB.
- La carga de soportes queda asociada al usuario que la realiza.
- La actualizacion de gastos y el reemplazo de soportes quedan reservados para administrador.

## Estado

El perfil `tesorero` queda funcional para registro de egresos, gestion documental basica y consulta financiera.
