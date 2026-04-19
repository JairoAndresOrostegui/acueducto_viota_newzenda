# Acueducto Viota Newzenda

Aplicacion Flutter para el sistema del acueducto veredal de Quitasol y Jazmin, municipio de Viota, Cundinamarca.

## Estado actual

- Soporte objetivo: Android y Web.
- Login responsivo con autenticacion real en Firebase.
- Panel administrativo con CRUD de usuarios, tipos de documento, roles y sectores.
- Auditoria visual de ediciones y eliminaciones de usuarios.
- Tema global consistente con la identidad del proyecto.

## Estructura base

- `lib/app`: configuracion principal de la app.
- `lib/theme`: paleta y tema global.
- `lib/features/auth`: login y autenticacion con Firebase.
- `lib/features/admin`: consola administrativa principal.
- `lib/features/catalogs`: CRUDs de catalogos.
- `lib/features/users`: CRUD de usuarios y logs de auditoria.
- `functions/`: Cloud Functions para crear, editar y eliminar usuarios administrados.

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
flutter run
firebase deploy --only functions --project frontacueductonewzenda
firebase deploy --only firestore --project frontacueductonewzenda
```

## Firebase

- Proyecto: `frontacueductonewzenda`
- Plataformas configuradas: Android y Web
- Archivo generado: `lib/firebase_options.dart`
- Colecciones base:
  - `usuarios`
  - `usuarios_logs`
  - `tipos_documento`
  - `roles`
  - `sectores`

## Reglas de datos

- La base de datos guarda en minuscula `nombre`, `correo`, `rol`, `estado`, `sector` y `tipoDocumento`.
- La UI capitaliza esos valores solo al mostrarlos.
- Los catalogos de tipos de documento y roles se inicializan automaticamente si estan vacios.
- Los sectores se administran desde su propio CRUD y solo se ofrecen activos en usuarios cuando el rol es `cliente`.
