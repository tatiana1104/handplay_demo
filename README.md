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

## Arquitectura

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

Después de correr `flutterfire configure`, descomenta las líneas marcadas
con `TODO(Sprint 1)` en `lib/main.dart` para inicializar Firebase.

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
- [x] Navegación protegida por sesión y rol (`redirect` de go_router según `AuthBloc`; rol disponible desde custom claims de Firebase)
- [x] Arquitectura AuthBloc por capas importada desde `feature/auth-bloc-firebase`: eventos, estados, casos de uso, repositorio y datasource Firebase
- [x] Vista de perfil conectada al botón inferior para todos los roles autenticados: muestra nombre, correo y cierre de sesión
- [x] Banner inferior persistente en la vista de perfil para administrador de liga, jugador, entrenador y árbitro
- [x] Home público después del splash: la información general no requiere iniciar sesión

#### Usuarios de prueba Firebase
El script `scripts/create-test-users.cjs` crea o actualiza cuentas de prueba y asigna custom claims (`admin_liga`, `jugador`, `entrenador`, `arbitro`). Requiere `serviceAccountKey.json` local, que nunca debe subirse al repositorio.

```powershell
npm install firebase-admin
node scripts/create-test-users.cjs
```

El script muestra las contraseñas temporales una sola vez; guárdalas de forma segura y obliga al usuario a cerrar sesión y entrar de nuevo para refrescar sus claims.

### 🟨 Sprint 2 — Torneos y equipos (modelo iniciado)
- [x] Modelos Dart para torneos, categorías, sedes, equipos, jugadores y partidos
- [x] Repositorio Firestore con consultas reactivas de torneos, categorías y sedes
- [ ] Vistas de torneos y equipos
- [ ] Escrituras completas y validación de formularios

#### Modelo de datos Firestore
Las colecciones creadas en el proyecto `handplaydemo` usan esta estructura base:

- `users/{uid}`: `uid`, `email`, `nombre`, `rol` (`jugador`, `arbitro` o `admin`). El perfil solo lo puede modificar su propietario; el rol se conserva en actualizaciones.
- `tournaments/{tournamentId}`: `ownerId`, `nombre`, `status`, `participantIds`, `currentRound`, `totalRounds`, `nextMatch`, `updatedAt`.
- `tournaments/{tournamentId}/teams/{teamId}`: `name`, `members`, `createdAt`. El propietario del torneo o un administrador gestiona equipos.
- `teams/{teamId}`: colección raíz compatible con los documentos ya creados; las escrituras quedan reservadas a administradores.
- `matches/{matchId}`: `tournamentId`, `teamAId`, `teamBId`, `participantIds`, `refereeId`, `scheduledAt`, `status`, `score`.

Las reglas están en `firestore.rules`. Después de cualquier cambio, desplegarlas desde la raíz del proyecto:

```powershell
firebase deploy --only "firestore:rules" --project handplaydemo
```

### ⬜ Sprint 3 — Calendario y árbitros
### ⬜ Sprint 4 — Partido en vivo
### ⬜ Sprint 5 — Estadísticas
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
