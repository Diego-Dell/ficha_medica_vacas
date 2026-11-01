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

El usuario es de demostración y está definido en `lib/logic/sesion.dart`. No debe usarse así en producción.

## Cómo ejecutar

```bash
flutter pub get
flutter run
```

## Pruebas

```bash
flutter test
```
