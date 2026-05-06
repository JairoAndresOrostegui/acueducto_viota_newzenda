# Modulo Consumos

## Alcance

Rutas:

- administrador: `Panel principal > Consumos`
- operador: acceso directo a `Registrar consumos`

Pantallas:

1. `Conflictos`
2. `Registrar consumos`
3. `Importar consumos`
4. `Suspensiones`

Los pagos y reportes se movieron a los macromodulos `Cuentas` y `Reportes`.

## Servicios

- `ConsumptionFirestoreService`
- `ConsumptionConflictFirestoreService`
- `ConsumptionLocalCacheService`
- `ConsumptionImportFunctionsService`
- `BillingPeriodFirestoreService`
- `UserFirestoreService`
- `InvoiceFirestoreService`

## Colecciones

- `periodos/{periodo}/consumos`
- `periodos/{periodo}/consumos/{contador}/historial`
- `consumos_conflictos`
- `periodos/{periodo}/recibos`

## Conflictos

Archivo:

- `lib/features/consumptions/presentation/pages/consumption_conflicts_admin_page.dart`

Objetivo:

- resolver conflictos de lectura generados al sincronizar o importar consumos.

Acciones:

- conservar lectura existente;
- usar lectura entrante;
- ingresar valor manual;
- consultar historico de conflictos resueltos.

Reglas:

- si el consumo esta facturado o pagado, no se modifica desde el flujo normal;
- si se corrige una lectura anterior, se recalculan periodos posteriores no bloqueados;
- la cascada se detiene ante consumo facturado o pagado.

## Registrar consumos

Archivo:

- `lib/features/consumptions/presentation/pages/consumption_register_page.dart`

Objetivo:

- permitir al operador trabajar localmente y subir lecturas.

Reglas:

- primero se descarga el periodo vigente;
- no se descarga otro periodo si hay lecturas locales pendientes;
- se puede buscar por nombre, codigo de usuario o contador;
- se puede registrar irregularidad y observaciones;
- las lecturas locales quedan como `pendiente_local` o `pendiente_revision`;
- al subir, los conflictos quedan bloqueados para revision;
- `2025-12` puede existir como periodo base de lectura.

## Importar consumos

Archivo:

- `lib/features/consumptions/presentation/pages/consumption_import_page.dart`

Formato:

- columna `codigousuario`;
- una columna con encabezado de periodo, por ejemplo `2026-01`;
- el valor de esa segunda columna es la lectura actual.

Este flujo es el unico que puede trabajar con el periodo base cuando sea necesario para cargar lecturas historicas.

## Suspensiones

Archivo:

- `lib/features/consumptions/presentation/pages/consumption_suspensions_admin_page.dart`

Objetivo:

- revisar y gestionar facturas suspendidas o en mora.

Reglas:

- solo muestra periodos operativos desde `2026-01`;
- `2025-12` no entra en cartera;
- no suspende facturas pagadas;
- permite levantar suspension;
- el estado suspendido conserva el cobro y la acumulacion de saldos.

## Estado

El modulo de consumos queda dedicado a lecturas, conflictos, importaciones y suspensiones.
