# handplay


Aplicación móvil para la gestión de torneos de balonmano de la **Liga de
Balonmano del Caquetá**: creación de torneos, inscripción y aprobación de
equipos, calendario y arbitraje, partido en vivo, y estadísticas.

> 📄 Documento de producto completo (PRD, RF-01–RF-25, RN-01–RN-06,
> casos de uso UC-01–UC-11): `Cancha-Documento-Consolidado.docx`.
> Planificación técnica y backlog: `Seguimiento_de_item.docx`.
> Registro histórico de cambios: `CHANGELOG.md`.
> El formulario de clubes usa un diálogo Stateful autónomo que administra su propio controlador y formulario; esto evita el assertion `_dependents.isEmpty` al guardar o cerrar un club.
> Cada club del catálogo es interactivo y abre su detalle con equipos, jugadores y entrenadores; las personas tienen acceso a una ficha resumida.
> La inscripción de equipos solo permite seleccionar clubes oficiales del catálogo; se eliminó el campo de club libre y el selector se adapta al ancho disponible en móvil.
> El registro de cuenta solicita el número de documento y, cuando encuentra un jugador existente en `profile_directory` o `users`, conserva y vincula sus datos al nuevo UID aunque la inscripción original no haya solicitado correo.
> En la inscripción, el correo solicitado pertenece al club (`clubEmail`) y aparece dentro de `Datos del equipo`; los datos del entrenador se registran por nombre, documento y teléfono, sin usar el correo del club para crear o invitar su cuenta. El filtrado del entrenador usa su `coachUid`, no el correo del club.
> La regla de creación de inscripciones valida `clubEmail` y requiere `publicRegistration: true` en el documento del torneo.
> Los torneos por grupos permiten configurar grupos y posiciones clasificadas (`groupCount`, `advancingPositions`). Al cerrar inscripciones, el administrador puede asignar aleatoriamente los equipos y generar jornadas de fase 1; los cruces de fase 2 siguen siendo manuales.

---

## Stack tecnológico

| Capa | Tecnología |
| --- | --- |
| App | Flutter / Dart |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Functions, FCM) |
| Asistente IA | Gemini API (vía Cloud Function segura) |
| Estado | `flutter_bloc` |
| Navegación | `go_router` |
| Inyección de dependencias | `get_it` |
| Manejo de errores funcional | `dartz` (`Either<Failure, T>`) |

## Arquitectura actual

La aplicación usa **Clean Architecture + Feature-First**, con Firebase como backend y un flujo de autenticación centralizado en `AuthBloc`. La navegación está controlada por `go_router`, que escucha los cambios del bloc y resuelve splash, inicio público, autenticación y perfil sin depender de temporizadores.

Cada feature mantiene sus responsabilidades separadas:

- `data/`: Firebase Auth/Firestore, datasources, modelos y repositorios.
- `domain/`: entidades, contratos y casos de uso.
- `presentation/`: BLoCs, pantallas y widgets de cada flujo.
- `core/`: rutas, constantes, tema, errores e inyección con `get_it`.
- `shared/`: componentes transversales, especialmente el banner inferior persistente.

El documento `users/{uid}` es la fuente de datos del perfil multirol; conserva `roles`, `rol`, correo y datos específicos de jugador, entrenador o árbitro. Calendario y partidos consumen sus repositorios y resuelven los nombres de equipos a partir de las inscripciones. En partido en vivo, la planilla digital se renderiza únicamente para roles de árbitro.

### Flujo de arranque y sesión

1. `main.dart` inicializa Firebase y registra dependencias sin bloquear el primer frame por el permiso de notificaciones; GoRouter abre primero el splash.
2. `AuthBloc` escucha `authStateChanges` como única fuente de verdad.
3. `GoRouter` permanece en splash solo mientras el estado es inicial/loading; después redirige a Home público o Perfil.
4. El splash permanece visible al menos 2 segundos y, si la sesión tarda más en resolverse, espera ese resultado antes de continuar.

### Estructura de carpetas

Clean Architecture + Feature-First:

```
lib/
├── core/                 # Transversal a toda la app
│   ├── constants/        # Constantes de negocio (RF/RN), colecciones Firestore
│   ├── theme/             # Colores y tipografías de marca
│   ├── routing/          # go_router
│   ├── errors/            # Failure / Exception
│   └── di/                 # Service locator (get_it)
├── features/
│   ├── auth/              # Login, registro, recuperar contraseña (RF-24, RF-25)
│   ├── matches/            # Calendario, oficiales, partido en vivo (RF-09–RF-17)
│   ├── referees/           # Arbitros
│   ├── teams/              # Inscripción y planilla de equipos (RF-05–RF-08)
│   ├── tournaments/       # Torneos (RF-01–RF-03)
│   ├── statistics/         # Posiciones, goleadores, valla menos vencida (RF-18–RF-20)
│   ├── notifications/      # Push (RF-27)
│   └── ai_assistant/       # Resumen de partido con Gemini (RF-26)
└── shared/                 # Widgets y servicios reutilizables entre features
```

Cada feature sigue tres capas internas:

```text
lib/features/<feature>/
├── data/
│   ├── datasources/       # Firebase, APIs y fuentes externas
│   ├── models/            # DTOs y serialización
│   └── repositories/      # Implementaciones de contratos
├── domain/
│   ├── entities/          # Modelos de negocio independientes de Flutter
│   ├── repositories/      # Contratos del dominio
│   └── usecases/          # Reglas y casos de uso
└── presentation/
    ├── bloc/              # Estado, eventos y estados
    ├── screens/           # Pantallas de la feature
    └── widgets/           # Componentes específicos
```

Las dependencias apuntan hacia el dominio: `presentation` consume casos de uso, `data` implementa contratos de `domain` y `core/shared` contiene capacidades transversales. Esta separación evita concentrar lógica de negocio en las pantallas y facilita probar cada feature.

## Reglas de negocio implementadas en el dominio

| Regla | Descripción | Tratamiento |
| --- | --- | --- |
| RN-01 / RN-02 | Conflicto de interés jugador/árbitro | Bloqueo duro, sin excepción, en los 4 roles oficiales |
| RN-05 | Color de uniforme único por categoría/torneo | Bloqueo al guardar inscripción |
| RN-06 | Cuota mínima de género en categoría Mixto | Valor de referencia 2/7 — **pendiente de confirmación oficial de la Liga** |

## Documentación

El detalle de cada sprint se mantiene en su documento correspondiente para evitar duplicación y conservar una documentación completa:

- [`docs/sprint-1-configuracion.md`](docs/sprint-1-configuracion.md) — configuración inicial, Firebase, autenticación y arquitectura.
- [`docs/sprint-2-torneos-inscripciones.md`](docs/sprint-2-torneos-inscripciones.md) — torneos, inscripciones, perfiles y aprobaciones.
- [`docs/sprint-3-arbitros-calendario.md`](docs/sprint-3-arbitros-calendario.md) — árbitros, oficiales, calendario y partidos.
- [`docs/sprint-4-partido-estadisticas.md`](docs/sprint-4-partido-estadisticas.md) — partido en vivo, planilla y estadísticas.
- [`docs/sprint-5-perfiles-navegacion.md`](docs/sprint-5-perfiles-navegacion.md) — perfiles multirol, clubes y navegación.
- [`docs/sprint-6-fases-torneo.md`](docs/sprint-6-fases-torneo.md) — grupos, clasificados y jornadas de fase 1.

Los documentos explican el objetivo, las actividades, la implementación, el resultado y la validación de cada sprint. El README conserva únicamente este índice y la información general del proyecto.

### Diagramas técnicos

- [`docs/diagrama-arquitectura.md`](docs/diagrama-arquitectura.md) — arquitectura por capas, features y flujo de datos.
- [`docs/diagrama-base-datos.md`](docs/diagrama-base-datos.md) — modelo lógico de Firestore y relaciones principales.
- [`docs/diagramas-flujos.md`](docs/diagramas-flujos.md) — autenticación, inscripción, fases y partido en vivo.
- [`docs/diagrama-roles-permisos.md`](docs/diagrama-roles-permisos.md) — roles, capacidades y matriz de autorización.

Los diagramas están escritos en Mermaid dentro de Markdown para que se rendericen en GitHub y otros visores compatibles.

- [`docs/cancha-todas-las-vistas.html`](docs/cancha-todas-las-vistas.html) — referencia visual de las vistas de cancha en tema claro y oscuro.

## Puesta en marcha local

```bash
git clone https://github.com/tatiana1104/handplay
cd handplay
flutter pub get
flutterfire configure   # genera lib/firebase_options.dart
firebase deploy --only "firestore:rules" --project handplaydemo
flutter run
```

`main.dart` inicializa Firebase con `DefaultFirebaseOptions`; después de ejecutar `flutterfire configure`, verifica que `lib/firebase_options.dart` esté generado para la plataforma objetivo. No es necesario descomentar código adicional en `main.dart`.


### Regla de actualización documental

Después de cada commit funcional se deben revisar y actualizar, cuando aplique, `README.md`, `CHANGELOG.md`, el documento del sprint correspondiente y los diagramas afectados (`docs/diagrama-*.md` o `docs/diagramas-*.md`). Así la documentación, los flujos y el modelo de datos permanecen alineados con el código.

La edición de clubes usa una pantalla desplazable para evitar overflow con el teclado, permite recuperar nombre y correo del personal por documento y muestra esa información en el detalle. Los partidos generados aleatoriamente conservan sus equipos, jornada y fase al abrir la edición.

Los partidos de `todos_contra_todos` se generan en dos jornadas: ida y vuelta. Para tres equipos el orden es A-B, B-C, C-A y luego B-A, C-B, A-C.

La entidad `clubs` guarda `email` como correo oficial, `coachDocument`/`coachEmail` para su entrenador y `assistantDocument`/`assistantEmail` para su asistente. El administrador de liga puede buscar ambas personas por documento y actualizar la asignación. y la vista de detalle lo muestra junto al resumen del club, incluso cuando todavía no tiene equipos. Al crear o actualizar un club se crea o actualiza su perfil de usuario en `users/club_<correo>` y `profile_directory/club_<correo>`. Los perfiles editados se sincronizan en `users/{uid}` y `profile_directory/{uid}`. El entrenador puede consultar el club asociado y su correo desde la ficha de perfil; al guardar el perfil se sincronizan esos campos desde `profile_directory/document_<documento>`, y el administrador puede guardar nombre y correo de un asistente en el club. Se eliminaron los campos de experiencia y especialidad.

## Convenciones

- **Ramas:** `feature/RF-XX-descripcion`, `fix/RN-XX-descripcion`.
- **Commits:** `[RF-XX|RN-XX] verbo en infinitivo + qué cambia`, para
  trazar cada cambio a un requerimiento del PRD.
- **Diseño:** mockup HTML consolidado (`cancha-todas-las-vistas.html`),
  20 pantallas, tema claro/oscuro.
- **Comentarios de código:** todo el código nuevo (y el ya existente,
  a medida que se toca) lleva comentarios **en español** explicando
  qué hace cada parte y, cuando aplica, a qué RF/RN del PRD responde.
  El objetivo es que cualquiera pueda entender el "por qué" de una
  decisión sin tener que preguntar, no solo el "qué" del código.

