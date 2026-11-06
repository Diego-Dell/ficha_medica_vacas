# Ficha médica de vacas lecheras

App móvil (Flutter). Por ahora solo contiene la pantalla de inicio de sesión.

## Estructura

```
lib/
  main.dart                   Punto de entrada y tema
  logic/sesion.dart           Sesión del usuario (patrón Singleton)
  screens/login_screen.dart   Pantalla de login
```

## Patrón Singleton

`Sesion` tiene un constructor privado y una única instancia, `Sesion.instance`, así que toda la app comparte el mismo estado de sesión.

## Configuración

El login usa Supabase Auth. Para configurarlo, copia `config.example.json` como `config.json` y escribe la URL y la clave pública (publishable) del proyecto. `config.json` no se sube al repositorio.

Nunca uses la clave `service_role` en la app: los valores de `config.json` quedan dentro del APK.

Los usuarios se crean en el panel de Supabase, en *Authentication → Users*.

## Cómo ejecutar

```bash
flutter pub get
flutter run --dart-define-from-file=config.json
```

## Pruebas

```bash
flutter test
```
