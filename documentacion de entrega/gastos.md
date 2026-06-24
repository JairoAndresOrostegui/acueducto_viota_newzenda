# Modulo Gastos

## Alcance

Ruta administrador:

- `Panel principal > Gastos`

Ruta tesorero:

- `Panel principal > Gastos`

Pantallas administrador:

1. `Conceptos`
2. `Gastos`
3. `Soportes`

Pantallas tesorero:

1. `Gastos`
2. `Soportes`

## Servicios

- `ExpenseConceptFirestoreService`
- `ExpenseRecordFirestoreService`
- `ExpenseSupportService`
- `BillingPeriodFirestoreService`

## Colecciones y archivos

Firestore:

- `gastos_conceptos`
- `gastos`
- `gastos_soportes`

Storage:

- `gastos_soportes/{periodoId}/{archivo}.pdf`

## Conceptos

Archivo:

- `lib/features/expenses/presentation/pages/expense_concepts_page.dart`

Objetivo:

- administrar los conceptos disponibles para registrar gastos.

Reglas:

- solo el administrador accede a esta pantalla;
- permite crear y editar conceptos;
- permite habilitar o inhabilitar conceptos;
- los gastos solo ofrecen conceptos activos;
- no elimina conceptos para conservar trazabilidad.

Campos principales:

- nombre;
- descripcion;
- estado;
- creado por;
- actualizado por.

## Gastos

Archivo:

- `lib/features/expenses/presentation/pages/expenses_page.dart`

Objetivo:

- registrar egresos asociados a un periodo operativo.

Reglas:

- trabaja con periodos operativos desde `2026-01`;
- selecciona por defecto el periodo vigente;
- exige concepto activo, valor, fecha del gasto, beneficiario e identificacion;
- administrador y tesorero pueden crear gastos;
- solo administrador puede editar gastos existentes;
- no se eliminan gastos desde la interfaz.

Campos principales:

- periodo;
- concepto;
- valor;
- fecha del gasto;
- pagado a nombre de;
- identificacion del beneficiario;
- registrado por;
- fecha de registro;
- actualizado por y fecha de actualizacion cuando aplique.

Busqueda:

- concepto;
- beneficiario;
- identificacion;
- registrante.

## Soportes

Archivo:

- `lib/features/expenses/presentation/pages/expense_supports_page.dart`

Objetivo:

- cargar un PDF soporte por periodo.

Reglas:

- administrador y tesorero pueden cargar soporte si el periodo no tiene uno;
- solo administrador puede reemplazar un soporte existente;
- el archivo debe ser PDF valido;
- Storage limita el archivo a menos de 20 MB;
- al reemplazar, el archivo anterior se elimina de Storage cuando sea posible;
- la metadata de Firestore conserva usuario y fecha de carga, y usuario y fecha de edicion cuando aplique.

## Reglas de seguridad

Firestore:

- `gastos_conceptos`: lectura administrador; tesorero solo conceptos activos; escritura administrador.
- `gastos`: lectura administrador, tesorero y contador; creacion administrador o tesorero; actualizacion administrador.
- `gastos_soportes`: lectura y creacion administrador o tesorero; actualizacion administrador.

Storage:

- lectura y carga de PDF para administrador o tesorero activo;
- borrado permitido para administrador;
- otros accesos bloqueados.

## Estado

El modulo queda operativo para control de egresos por periodo, soporte documental y reporte exportable.
