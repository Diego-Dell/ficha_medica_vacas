# VetLink · Ficha médica de vacas lecheras

App móvil (Flutter + Supabase). Contiene el Sprint 1 (S1-01, RF-01): cuentas, sesión, registro y confirmación de granjas, invitaciones y acceso por rol. Del Sprint 2 incluye las fichas del ganado (S2-01, RF-02).

## Qué incluye

- Iniciar y cerrar sesión, crear cuenta (dueño con su granja o persona invitada) y recuperar la contraseña por correo.
- Registrar una granja, que queda en revisión hasta que el administrador técnico la confirma.
- Invitar al equipo con el rol de Veterinario o Trabajador, aceptar la invitación al iniciar sesión y comprobar la incorporación en Miembros.
- Elegir la granja al entrar y cambiar de granja desde *Mis granjas*; cada granja recupera el rol guardado.

## Estructura

```
lib/
  main.dart                          Punto de entrada, tema y enlace de recuperación
  logic/sesion.dart                  Cuenta y sesión (Singleton + Facade + Observer)
  logic/granjas.dart                 Granjas, miembros e invitaciones (Singleton + Facade)
  logic/fichas.dart                  Fichas del ganado (Singleton + Facade)
  models/                            Granja, Miembro, Invitación y Animal
  screens/inicio_por_rol.dart        Pantalla de inicio según el rol (Factory)
  screens/acceso_general/            Login, crear cuenta, recuperar, nueva contraseña y Mis granjas
  screens/dueno_granja/              Registro, revisión, Mi granja, Miembros e Invitar
  screens/veterinario/               Panel del veterinario
  screens/trabajador/                Panel del trabajador
  screens/administrador/             Confirmación de granjas
  screens/ganado/                    Ganado, ficha del animal, crear o editar ficha y dar de baja
  widgets/                           Piezas visuales compartidas
```

## Patrones de diseño

- **Singleton**: `Sesion.instance` y `Granjas.instance` tienen un constructor privado y una única instancia, así toda la app comparte la misma sesión y la misma granja actual.
- **Facade**: `Sesion` y `Granjas` esconden Supabase Auth y las consultas a las tablas detrás de métodos simples que devuelven el mensaje de error listo para mostrar.
- **Factory**: `InicioPorRol.crear` decide qué pantalla abrir para cada granja (Mi granja, panel del veterinario, panel del trabajador o Granja en revisión). El login y *Mis granjas* solo piden la pantalla, sin conocer los roles.
- **Observer**: `Sesion.alRecuperar` se suscribe a los cambios de Supabase Auth y abre Nueva contraseña cuando la app se abre desde el enlace de recuperación.

## Fichas del ganado (Sprint 2 · RF-02)

Desde Mi granja: *Ficha* crea o actualiza una ficha, *Baja del animal* registra la baja y *Búsqueda* abre Consulta y supervisión. El trabajador tiene *Ficha* y *Consulta*; el veterinario, *Consulta*.

| Acción | Dueño | Trabajador | Veterinario |
| --- | --- | --- | --- |
| Consultar fichas | Sí | Sí | Sí |
| Crear y editar datos generales | Sí | Sí | No |
| Dar de baja | Sí | No | No |

La base aplica los mismos permisos con las políticas `fichas_crear` y `fichas_editar`, y el trigger `proteger_baja`.

### Para Clínica, Tratamientos y Cuidados

- `Fichas.instance.activos()` trae los animales activos de la granja actual; un animal dado de baja no admite nuevos eventos.
- `SelectorAnimal(alElegir: …, inicial: …)` es el campo para elegir el animal en un formulario; valida que se haya elegido uno.
- `FichaAnimalScreen._registros` es donde cada módulo agrega su historial y opciones en la ficha del animal.
- En las pruebas, `simularDatos({'fichas_bovinas': [...]})` simula las fichas igual que las demás tablas.

## Configuración

Copia `config.example.json` como `config.json` y escribe la URL y la clave pública (publishable) del proyecto. `config.json` no se sube al repositorio.

Nunca uses la clave `service_role` en la app: los valores de `config.json` quedan dentro del APK.

Para que el enlace de recuperación abra la app, agrega `vetlink://restablecer` en Supabase, en *Authentication → URL Configuration → Redirect URLs*.

Para confirmar granjas, la cuenta del administrador técnico debe tener `administrador_tecnico = true` en la tabla `cuentas`.

## Cómo ejecutar

```bash
flutter pub get
flutter run --dart-define-from-file=config.json
```

## Pruebas

```bash
flutter test
```
