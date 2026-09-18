# handplay


Aplicación móvil para la gestión de torneos de balonmano de la **Liga de
Balonmano del Caquetá**: creación de torneos, inscripción y aprobación de
equipos, calendario y arbitraje, partido en vivo, y estadísticas.

> 📄 Documento de producto completo (PRD, RF-01–RF-25, RN-01–RN-06,
> casos de uso UC-01–UC-11): `Cancha-Documento-Consolidado.docx`.
> Planificación técnica y backlog: `Seguimiento_de_item.docx`.

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

1. `main.dart` inicializa Firebase y registra dependencias sin bloquear el primer frame por el permiso de notificaciones.
2. `AuthBloc` escucha `authStateChanges` como única fuente de verdad.
3. `GoRouter` permanece en splash solo mientras el estado es inicial/loading; después redirige a Home público o Perfil.
4. El splash no usa un `Timer`: evita carreras y esperas artificiales al iniciar sesión.

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
  │   ├── tournaments/       # Torneos (RF-01–RF-03)
│   ├── teams/              # Inscripción y planilla de equipos (RF-05–RF-08)
│   ├── matches/            # Calendario, oficiales, partido en vivo (RF-09–RF-17)
│   ├── statistics/         # Posiciones, goleadores, valla menos vencida (RF-18–RF-20)
│   ├── notifications/      # Push (RF-27)
│   └── ai_assistant/       # Resumen de partido con Gemini (RF-26)
└── shared/                 # Widgets y servicios reutilizables entre features
```

Cada feature sigue tres capas internas:

- **`data/`** — datasources (Firebase), modelos, implementación de repositorios.
- **`domain/`** — entidades, contratos de repositorio, casos de uso.
- **`presentation/`** — BLoCs, pantallas, widgets.

## Reglas de negocio implementadas en el dominio

| Regla | Descripción | Tratamiento |
| --- | --- | --- |
| RN-01 / RN-02 | Conflicto de interés jugador/árbitro | Bloqueo duro, sin excepción, en los 4 roles oficiales |
| RN-05 | Color de uniforme único por categoría/torneo | Bloqueo al guardar inscripción |
| RN-06 | Cuota mínima de género en categoría Mixto | Valor de referencia 2/7 — **pendiente de confirmación oficial de la Liga** |

## Documentación

La configuración completa de Sprint 1 está documentada paso a paso en [`docs/sprint-1-configuracion.md`](docs/sprint-1-configuracion.md).

Incluye Firebase, FlutterFire, autenticación, AuthBloc, Firestore, reglas de seguridad, usuarios administradores, usuarios de prueba, App Check y verificación en dispositivo.

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

## Estado de avance

### ✅ Sprint 1 — Base del proyecto (completo, verificado en dispositivo físico)
- [x] Estructura Clean Architecture + Feature-First
- [x] Dependencias base (Firebase, BLoC, go_router, get_it)
- [x] Tema visual (colores/tipografías de marca)
- [x] Rutas iniciales con pantallas placeholder
- [x] Configuración real de Firebase (`flutterfire configure` — proyecto `handplaydemo`)
- [x] Autenticación (`AuthBloc` + login/registro/recuperar contraseña, correo y Google)
- [x] Firestore Security Rules configuradas para despliegue (`firebase deploy --only "firestore:rules"`) — reglas base: solo usuarios autenticados
- [ ] Verificado en Moto G34 5G: splash → login → Google Sign-In → Firestore → Mis torneos
- [x] Navegación protegida por sesión y roles (`redirect` de go_router según `AuthBloc`; roles disponibles desde custom claims de Firebase). La ruta de creación valida `state.extra` y usa el UID autenticado como respaldo; `main.dart` importa explícitamente `firebase_auth` para resolver ese UID. Las fechas de inicio, fin y límite de inscripción no pueden ser anteriores al día actual, tanto en el selector como al guardar. El correo del entrenador se valida con una expresión compatible con Dart antes de registrar el equipo. Al enviar una inscripción, una Cloud Function crea o actualiza el usuario del entrenador, asigna el rol `entrenador`, genera un enlace de contraseña, crea el equipo en `tournaments/{tournamentId}/teams/{registrationId}` y escribe el correo en `mail/{id}` para la Firebase Extension Trigger Email. El flujo gratuito no depende de Cloud Functions: el entrenador crea primero su cuenta desde la app y luego inscribe el equipo usando el mismo correo. Al registrarse o iniciar sesión, la app crea o completa automáticamente `users/{uid}` en segundo plano, sin bloquear la navegación ni el splash sin borrar roles existentes; esto también recupera usuarios que ya estaban en Firebase Authentication pero no tenían perfil en Firestore. La app vincula el `uid`, agrega `entrenador` al array de roles del perfil y crea el equipo pendiente directamente cuando la sesión activa usa ese mismo correo. En las tarjetas de torneo, las acciones Editar, Solicitudes y Eliminar solo son visibles para usuarios con `admin` o `admin_liga` en sus claims. El detalle del torneo muestra en tiempo real la cantidad de inscripciones con estado `approved`. Esta consulta requiere publicar las reglas Firestore actualizadas, que permiten leer públicamente solo esas inscripciones aprobadas; las pendientes y rechazadas siguen protegidas. al tocar la tarjeta Equipos abre la lista de equipos aprobados y el número de jugadores de cada uno. El icono de cada equipo usa el color registrado en `uniformColor`, con contraste automático para la inicial. En torneos mixtos, Destacados incluye máximo goleador masculino, máxima goleadora femenina y valla menos vencida sin distinción de género. El entrenador ve el estado de su solicitud: pendiente, aprobada o rechazada. El estado se consulta por el correo autenticado, incluyendo solicitudes existentes creadas antes de la vinculación por UID, y conserva la solicitud más reciente. El perfil lee los roles directamente desde `users/{uid}` en tiempo real, por lo que muestra `Jugador, Entrenador` sin depender de claims que aún no se hayan renovado. Las reglas permiten al entrenador consultar su inscripción por correo y, al iniciar sesión, la app sincroniza el rol `entrenador` si encuentra una solicitud asociada. Al rechazar, el administrador debe indicar los datos por corregir y ese mensaje se muestra al entrenador para que pueda editar y reenviar la inscripción. Estas escrituras se envían en un único batch atómico y tienen un límite de 20 segundos para evitar esperas indefinidas. El diálogo de validación adapta su título a pantallas estrechas para evitar desbordamientos visuales. Si el correo pertenece a otra cuenta pero no hay sesión iniciada con ella, por seguridad la app no puede modificar ese usuario: debe iniciar sesión con esa cuenta y volver a enviar o vincular la inscripción. Las Cloud Functions quedan opcionales y no se necesitan para este flujo. La extensión debe estar instalada y configurada para escuchar la colección `mail`; la URL autorizada de Firebase Hosting debe coincidir con `https://handplaydemo.web.app/login`.
- [x] Arquitectura AuthBloc por capas importada desde `feature/auth-bloc-firebase`: eventos, estados, casos de uso, repositorio y datasource Firebase
- [x] Vista de perfil conectada al botón inferior para todos los roles autenticados: muestra nombre, correo y cierre de sesión. La vista Equipos inscritos permite abrir cada equipo aprobado para consultar entrenador, categoría, métricas y plantilla con posición, número y goles registrados
- [x] Banner inferior persistente en la vista de perfil para administrador de liga, jugador, entrenador y árbitro
- [x] Home público después del splash: la información general no requiere iniciar sesión

#### Usuarios de prueba Firebase
El script `scripts/create-test-users.cjs` crea o actualiza cuentas de prueba y asigna custom claims multi-rol mediante `roles: []` (por ejemplo, `['jugador', 'arbitro']`). El claim singular `rol` se conserva temporalmente por compatibilidad. Requiere `serviceAccountKey.json` local, que nunca debe subirse al repositorio.

```powershell
npm install firebase-admin
node scripts/create-test-users.cjs
```

El script muestra las contraseñas temporales una sola vez; guárdalas de forma segura y obliga al usuario a cerrar sesión y entrar de nuevo para refrescar sus claims.

### ✅ Sprint 2 — Torneos y equipos (completado)

Incluye la gestión completa de torneos, categorías, inscripciones, equipos, jugadores, aprobación administrativa, edición de solicitudes rechazadas, advertencias de similitud, perfiles de equipo y jugador, y reglas de acceso Firestore.
- [x] Modelos Dart para torneos, categorías, sedes, equipos, jugadores y partidos
- [x] Repositorio Firestore con consultas reactivas de torneos, categorías y sedes
- [x] Home público de liga de balonmano con banner inferior para consultar información e iniciar sesión
- [x] Splash usa la paleta de marca y login conserva el banner público sin mostrar Perfil
- [x] Listado reactivo de torneos desde Firestore para usuarios autenticados
- [x] Botón y formulario de creación de torneo exclusivo para `admin_liga`
- [x] Categorías constantes: master, mayor, juvenil, cadete, infantil y libre; ramas femenino, masculino y mixto
- [x] Formatos constantes: todos contra todos y por grupos, sin sede principal
- [x] Fecha fin opcional y selección individual de categoría y rama mediante listas desplegables
- [x] Varias combinaciones categoría-rama se agregan automáticamente sin botón adicional
- [x] Números de camiseta obligatorios del 1 al 99 y únicos dentro del equipo
- [x] Reglas Firestore alineadas con `adminId` y custom claims de administración
- [x] El formulario renueva el token y valida `rol` antes de crear un torneo
- [x] Torneos creados permanecen en Firestore y se muestran de forma permanente al volver al home
- [x] Todos los usuarios, incluidos visitantes, consultan los torneos en tiempo real
- [x] Filtros de torneos por iniciar, jugando y terminados
- [x] Orden general: por iniciar primero, jugando después y terminados al final
- [x] Tarjetas de torneo interactivas con detalle responsive, estadísticas, posiciones y destacados
- [x] Detalle con desplazamiento vertical para pantallas pequeñas y contenido ampliable
- [x] Inscripción pública de equipos desde el detalle del torneo, con categoría, entrenador, contacto y consentimiento
- [x] Solicitudes guardadas en `tournaments/{id}/registrations` con estado `pending` para revisión administrativa
  - [x] Inscripción permitida desde la vista pública o con sesión de entrenador
  - [x] Las solicitudes rechazadas muestran el motivo en rojo y permiten editar y reenviar el mismo formulario con los datos precargados; al reenviar, la solicitud vuelve a `pending` sin error de `FieldValue.delete()`.
  - [x] El botón de enviar ocupa todo el ancho y respeta el área segura inferior del teléfono para no quedar oculto por la navegación del sistema.
  - [x] El contador y la lista de Equipos usan directamente `registrations` con `status: approved`, que contiene la información completa de cada inscripción; la colección `teams` queda como índice auxiliar.
  - [x] Las reglas Firestore permiten al entrenador autenticado actualizar su propia solicitud rechazada y el equipo vinculado al reenviarla como `pending`; las eliminaciones siguen restringidas al administrador.
- [x] Logo del equipo deshabilitado temporalmente hasta configurar almacenamiento
- [x] `firebase.json` ya no intenta desplegar Storage; la inscripción funciona solo con Firestore
- [x] Formulario de inscripción reorganizado en secciones visuales adaptables
- [x] Vista Equipos inscritos con contador en tiempo real de solicitudes aprobadas y navegación al detalle de cada equipo
  - [x] Detalle de equipo con uniforme, categoría, entrenador, métricas y plantilla de jugadores; cada jugador abre su perfil individual con estadísticas e historial disponible; el perfil distingue tarjetas amarillas y tarjetas rojas
- [x] Escrituras completas y validación de formularios para torneo, solicitud, equipo y jugadores
- [x] Revisión administrativa: aprobar/rechazar solicitudes y registrar motivo de rechazo
- [x] Advertencias de similitud de equipos, uniformes y jugadores con nombre y documento
- [x] Edición y reenvío de solicitudes rechazadas con datos precargados y cambios solicitados destacados en rojo
- [x] Perfil multirol sincronizado entre Firebase Authentication y Firestore
- [x] Estados de solicitud visibles para el entrenador: pendiente, aprobada y rechazada
- [x] Acceso seguro a solicitudes y equipos aprobados mediante reglas Firestore

### 🟨 Sprint 3 — Calendario y árbitros (en progreso)
- [x] Barra de navegación inferior global: el acceso a Árbitros aparece en todas las pantallas para `admin`/`admin_liga`, incluido Perfil; los demás roles no lo ven. Se eliminó el botón duplicado del banner superior.
- [x] El acceso de Árbitros usa un icono deportivo tipo silbato; Flutter Material no incluye un icono de silbato dedicado.
- [x] Listado inicial de árbitros registrados.
- [x] Botón Nuevo árbitro con estilo similar al botón de agregar de Mi torneo.
- [x] Formulario de documento, nombre, correo, teléfono y acreditación: municipal (básico), departamental (intermedio, requiere municipal) y nacional (alto, requiere departamental). El administrador puede crear o actualizar el perfil y se informa el error de Firebase si el guardado falla.
- [x] Cada árbitro abre un perfil con documento, correo, teléfono y selector para agregar o actualizar su nivel permitido; el listado muestra solo su acreditación resumida: municipal, departamental o nacional. En el perfil del árbitro aparecen botones inferiores para abrir la ficha de jugador o entrenador según los roles guardados en Firestore. La acreditación usa una lista desplegable con el mismo patrón visual del selector de categoría del torneo. El perfil muestra únicamente la lista de certificaciones vigentes, sin selector duplicado. El botón `+` abre el cuadro para seleccionar el siguiente nivel permitido. Si el documento existe carga sus datos y habilita solo los niveles permitidos; si no existe comienza en municipal.
- [x] En el detalle del torneo, tarjeta Jornada navegable hacia una pantalla independiente de partidos agrupados por fecha; lista conectada a `tournaments/{id}/matches`.
- [x] El botón Calendario del banner abre el calendario global con los partidos agrupados por día, hora, sede/cancha, equipos y estado.
- [x] El banner inferior de navegación está disponible también en la vista global de Calendario y conserva el acceso a Home, Calendario, Árbitros y Perfil según el rol.
- [x] El administrador del torneo puede crear partidos desde la pantalla de jornadas, asignando local, visitante, fecha, hora, sede/cancha, árbitros y mesa.
- [x] Las tarjetas muestran siempre LOCAL a la izquierda y VISITANTE a la derecha, con el nombre real del equipo y el color de uniforme registrado.
- [x] La fecha almacenada como `Timestamp` se presenta como día y mes legibles; la hora y la sede/cancha aparecen debajo de la fila de equipos.
- [x] Los estados de partido están normalizados como `Por iniciar`, `Jugando` y `Finalizado` en jornadas y calendario global.
- [x] Se evita guardar un partido cuando un árbitro de campo pertenece a la plantilla del equipo local o visitante; se muestra una alerta visual con el nombre del árbitro y el equipo en conflicto.
- [x] Las reglas Firestore permiten al administrador del torneo gestionar la subcolección anidada `tournaments/{id}/matches` y leer partidos/inscripciones para el calendario global.
- [ ] Generación automática de calendario (planificada para Sprint 6: automatizaciones).
- [x] Asignación manual de árbitros.
- [x] Asignación manual de mesa.
- [x] Validación de conflictos de interés entre árbitros de campo y equipos participantes.

#### Modelo de datos Firestore
Las colecciones creadas en el proyecto `handplaydemo` usan esta estructura base:

- `users/{uid}`: `uid`, `email`, `nombre`, `roles` (lista multi-rol: `jugador`, `arbitro`, `entrenador`, `admin_liga`), y `rol` legado. El perfil solo lo puede modificar su propietario; la asignación de roles se realiza desde un entorno seguro mediante Firebase Admin SDK y custom claims.
- `tournaments/{tournamentId}`: `adminId`, `name`, `status`, `categories` (`categoria|rama`), `format`, `teamLimit`, `publicRegistration`, `startDate`, `endDate`, `updatedAt`.
- `tournaments/{tournamentId}/teams/{teamId}`: `name`, `members`, `createdAt`. El propietario del torneo o un administrador gestiona equipos.
- `teams/{teamId}`: colección raíz compatible con los documentos ya creados; las escrituras quedan reservadas a administradores.
- `tournaments/{tournamentId}/matches/{matchId}`: `homeTeam`, `awayTeam`, `homeTeamName`, `awayTeamName`, `homeTeamColor`, `awayTeamColor`, `date` (`Timestamp`), `venue`, `refereeOne`, `refereeTwo`, `tableOfficial`, `status` (`scheduled`/`playing`/`finished`) y `score`.

Las reglas están en `firestore.rules`. Después de cualquier cambio, desplegarlas desde la raíz del proyecto:

```powershell
firebase deploy --only "firestore:rules" --project handplaydemo
```

### ✅ Sprint 3 — Calendario y árbitros (completado)
La creación manual de partidos, calendario global, presentación de equipos/colores, estados y validación de conflictos está implementada. La generación automática de jornadas queda planificada para el Sprint 6 de automatizaciones.

### Arquitectura de features
La información se organiza por dominio y no se concentra en una pantalla:
- `features/teams/`: equipos, jugadores, entrenadores, inscripciones, modelos, repositorio y widgets de plantilla.
- `features/matches/`: partidos, calendario, estados, sede, oficiales y repositorio de partidos.
- `features/tournaments/`: datos y pantallas propias del torneo; compone los módulos de equipos y partidos.
- `features/referees/`: perfiles y disponibilidad de árbitros.
- `core/`: configuración transversal, rutas, errores, tema y dependencias.
- `shared/`: widgets compartidos como el banner inferior.

Las pantallas deben coordinar datos y composición visual; los modelos, acceso a Firestore y widgets específicos permanecen dentro de su feature. Como parte de esta etapa, `TeamRepository` centraliza las inscripciones aprobadas y `MatchRepository` centraliza la lectura de partidos; las pantallas de torneo ya consumen esos repositorios.

#### Historial de commits de implementación
- `7887698`: detalle de partido en vivo y permiso de inicio por asignación.
- `3ccadbd`: duración configurable de cada tiempo y estado del marcador.
- `15bb4cc`: funciones de árbitro derivadas de la asignación del partido.
- `735a00e`: estado resaltado en el marcador.
- `7f490f0`: cuatro oficiales visibles: dos árbitros de campo, cronometrista y anotador.
- `c766d8b`: eliminación del estado duplicado bajo los oficiales.
- `cbe502e`: resolución de IDs de oficiales a nombres.
- `e85c4b0`: sección de oficiales plegable.
- `3ff25c2`: planilla digital con equipos y jugadores.
- `f8bd046`: controles de gol, exclusión, tarjeta amarilla y tarjeta roja.
  - `HEAD`: formulario de finalización de perfil después del inicio de sesión, con datos específicos para jugadores.
  - `HEAD`: árbitros visibles para cualquier usuario autenticado; calendario y detalle de partidos accesibles públicamente; el banner público muestra `Iniciar sesión` en lugar de `Perfil`.
  - `HEAD`: corrección de sintaxis en `profile_screen.dart` al añadir la coma del `AppBar`.
  - `HEAD`: calendario y partidos públicos, árbitros visibles según permiso y botón de árbitros exclusivo para administradores.
  - `HEAD`: resolución de nombres de equipos en el calendario y detalle usando inscripciones aprobadas y los identificadores `id`, `registrationId`, `teamId`, `teamUid` o `uid`; regreso a Home desde el banner constante.
  - `HEAD`: navegación consistente del banner para visitantes, usuarios y administradores; Perfil vuelve a funcionar para roles no administradores; el formulario de perfil persiste correo, documento y datos específicos del rol.
  - `HEAD`: evita mostrar UIDs como nombres durante la carga; calendario y detalle muestran nombres guardados o un texto neutral mientras resuelven la inscripción.
  - `HEAD`: el banner público del calendario muestra `Home`, `Calendario` e `Iniciar sesión`; Home navega directamente sin depender del historial de rutas.
  - `HEAD`: el banner calcula la sesión real desde AuthBloc, evita mostrar Perfil a visitantes/rol público y mantiene índices válidos para usuarios, administradores y visitantes.
  - `HEAD`: el botón Home del banner limpia la pila de navegación antes de ir a `/torneos`, evitando que el calendario abierto con `Navigator.push` bloquee el regreso.
  - `HEAD`: completar perfil crea/actualiza `users/{uid}` con `uid`, `roles`, `rol`, correo y datos del jugador; la pantalla Perfil muestra los datos guardados y errores de Firestore.
  - `HEAD`: las reglas de Firestore permiten crear el perfil propio para todos los roles soportados y el formulario muestra también errores no relacionados directamente con Firebase.
  - `HEAD`: la pantalla Perfil reconoce los perfiles completados por las banderas `profileCompleted`/`profileComplete` o por los datos obligatorios ya guardados, evitando solicitar el formulario nuevamente.
  - `HEAD`: completar perfil conserva los roles existentes del documento `users/{uid}` antes de actualizarlo, evitando que las reglas de Firestore rechacen la escritura por pérdida de roles previos.
  - `HEAD`: la sección `Planilla digital` de Partido en vivo solo se muestra a usuarios con rol `arbitro`, `árbitro` o `referee`, normalizando mayúsculas y espacios; los demás roles conservan el marcador y la cronología.
  - `HEAD`: el banner constante se incorporó al listado, detalle y alta de árbitros para conservar la navegación en todas las vistas.
  - `HEAD`: Perfil muestra únicamente nombre, documento, correo y cambio de contraseña; usuarios con múltiples roles acceden a sus fichas individuales de entrenador, árbitro y jugador mediante botones independientes.
  - `HEAD`: se corrigieron errores de compilación: navegación de cambio de contraseña con `go_router` y argumento `bottomNavigationBar` duplicado en el detalle de árbitro.
  - `HEAD`: la posición del jugador en Completar perfil usa el mismo selector desplegable que la inscripción de equipo: Portero, Extremo, Lateral, Central y Pivote; el número de camiseta se controla con constantes y solo acepta valores del 1 al 99.
  - `HEAD`: Completar perfil normaliza los roles `player/jugador`, `coach/entrenador`, `referee/arbitro` y `public/publico`; todos los roles usan la misma validación de guardado y las reglas de Firestore aceptan los perfiles soportados.
  - `HEAD`: Perfil normaliza los roles antes de comprobar la finalización y acepta banderas booleanas o serializadas como texto, además de validar los datos mínimos persistidos; evita volver a mostrar el formulario después de cambiar de vista.
  - `HEAD`: el banner inferior usa AuthBloc como fuente de sesión en todas las vistas, normaliza roles públicos y administrativos, conserva índices válidos y navega a Home con `go_router` sin depender de la pila de `Navigator`.
  - `HEAD`: arquitectura y documentación sincronizadas con el flujo multirol actual; AuthBloc/GoRouter controlan la sesión, el splash espera el estado real sin temporizador y los permisos secundarios no bloquean el arranque.
  - `HEAD`: la consulta pública de inscripciones permite resolver los nombres de equipos antiguos aunque no tengan el estado `approved` esperado; la UI filtra registros pendientes antes de mostrarlos.


### 🟨 Sprint 4 — Partido en vivo (en progreso)
- [x] Marcador y estado del partido.
- [x] Registro visual de goles.
- [x] Controles de tarjetas y exclusiones.
- [x] Planilla digital con equipos y jugadores inscritos.
- [ ] Bloqueo de planillas aprobadas.

Los roles operativos no son roles globales nuevos: se usa el rol global `arbitro` y, al crear cada partido, se asigna el tipo de función (`Árbitro de campo`, `Mesa - Cronometrista` o `Mesa - Anotador`). El permiso para iniciar el partido se determina por la asignación del usuario al partido.

### ⬜ Sprint 5 — Estadísticas

### ⬜ Sprint 6 — Automatizaciones
Incluye la generación automática del calendario y de las jornadas a partir de los equipos inscritos, además de la generación automática de la cronología del partido a partir de goles, exclusiones y tarjetas.

### ⬜ Sprint 6 — Gemini y notificaciones
### ⬜ Sprint 7 — Pruebas y publicación

_(Ver el desglose completo de cada sprint en `Seguimiento_de_item.docx`.)_

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

## Decisiones pendientes de la Liga

Ver sección 13 del PRD consolidado — entre ellas, el número exacto de la
cuota mínima de género en cancha (RN-06) y el mínimo de partidos jugados
para clasificar en valla menos vencida (RF-20).

## Pendientes técnicos conocidos

- **Google Sign-In en Android** requiere el SHA-1 (y SHA-256) del
  certificado de firma registrado en Firebase Console → Configuración
  del proyecto → tu app Android → "Agregar huella digital" (ya hecho
  para la máquina de desarrollo actual). **Si otra persona clona este
  repo en una máquina nueva**, va a necesitar generar y registrar SU
  PROPIO SHA-1 de debug (cada `debug.keystore` es distinto por
  máquina):
  ```powershell
  cd android
  .\gradlew signingReport
  ```
  y agregar el SHA-1 que aparezca ahí en Firebase Console, luego
  volver a descargar `google-services.json` y reemplazar el de
  `android/app/`.
- **Build de Android lento (`org.gradle.daemon=false`)**: en la
  máquina de desarrollo actual, el daemon de Gradle y de Kotlin se
  colgaban indefinidamente en `assembleDebug` (`Failed connecting to
  the daemon in 4 retries`), aparentemente por firewall/antivirus
  bloqueando el socket de loopback. Se desactivaron ambos daemons en
  `android/gradle.properties` como solución. Esto hace los builds más
  lentos para TODOS los que clonen el repo (no solo la máquina
  afectada). Si en tu máquina los builds nunca tuvieron ese problema,
  puedes probar a quitar esas dos líneas y ver si te compila más
  rápido con el daemon activado — si es así, considera mover esa
  configuración a tu `~/.gradle/gradle.properties` personal en vez de
  dejarla en el repo compartido.
