# Acueducto Viota Newzenda

Base inicial en Flutter para el sistema del acueducto veredal de Quitasol y Jazmin, municipio de Viota, Cundinamarca.

## Estado actual

- Login responsivo para Android, iOS, web y escritorio.
- Tema global con paleta azul y verde enfocada en identidad de agua y territorio.
- Estilos consistentes para botones, formularios, tarjetas, mensajes y textos.
- Flujo de autenticacion local inicial para avanzar mientras se conecta un backend real.

## Credenciales demo

- Usuario: `admin@acueductoviota.com`
- Clave: `Agua2026*`

## Estructura base

- `lib/app`: configuracion principal de la app.
- `lib/theme`: paleta y tema global.
- `lib/features/auth`: login, controlador y autenticacion local.
- `lib/features/home`: pantalla inicial posterior al login.

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Siguiente paso recomendado

Conectar autenticacion real y empezar los modulos de suscriptores, lecturas, facturacion y recaudo.
