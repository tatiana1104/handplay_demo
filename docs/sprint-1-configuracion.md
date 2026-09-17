# Sprint 1 — Configuración paso a paso

## 1. Requisitos

Instala y verifica:

- Flutter y Dart compatibles con el proyecto.
- Node.js y npm.
- Firebase CLI.
- FlutterFire CLI.
- Una cuenta con acceso al proyecto Firebase `handplaydemo`.

Comandos de verificación:

```powershell
flutter --version
dart --version
node --version
npm --version
firebase --version
flutterfire --version
```

## 2. Obtener el proyecto

```powershell
git clone https://github.com/tatiana1104/handplay_demo.git
cd handplay_demo
flutter pub get
```

La rama de trabajo usada durante Sprint 1 fue `v0/firebase-initialization`.

## 3. Vincular Flutter con Firebase

Inicia sesión en Firebase CLI:

```powershell
firebase login
```

Configura FlutterFire usando el proyecto correcto y las plataformas requeridas:

```powershell
flutterfire configure --project=handplaydemo --platforms=android,ios,web
```

Esta operación genera o actualiza:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- La configuración de Firebase para Android, iOS y Web.

El archivo `firebase.json` debe apuntar a las reglas de Firestore:

```json
{
  "firestore": {
    "rules": "firestore.rules"
  }
}
```

## 4. Inicializar Firebase en Flutter

En `lib/main.dart` se inicializa Firebase antes de ejecutar la aplicación:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

La aplicación usa `firebase_options.dart` para elegir automáticamente la configuración de Android, iOS o Web.

## 5. Configurar huellas Android

Google Sign-In en Android necesita las huellas del certificado.

Desde la raíz del proyecto:

```powershell
cd android
.\\gradlew signingReport
```

Registra en Firebase Console, dentro de la aplicación Android:

- SHA-1 de `debug` para desarrollo.
- SHA-256 de `debug` para servicios que la requieran.
- SHA-1 y SHA-256 de `release` para producción.
- La huella de Play App Signing si la aplicación se publica en Google Play.

Después de agregar las huellas, descarga nuevamente `google-services.json` y reemplázalo en:

```text
android/app/google-services.json
```

## 6. Autenticación

En Firebase Console habilita en **Authentication → Sign-in method**:

- Email/Password.
- Google.

La aplicación implementa autenticación con una arquitectura por capas:

```text
lib/features/auth/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── bloc/
    └── screens/
```

`AuthBloc` escucha los cambios de Firebase Auth y expone estados para:

- Estado inicial/cargando.
- Usuario autenticado.
- Usuario no autenticado.
- Error de autenticación.

## 7. Inyección de dependencias

La aplicación registra el datasource, repositorio, casos de uso y `AuthBloc` mediante `get_it` en:

```text
lib/core/di/injection_container.dart
```

La inicialización se ejecuta antes de `runApp`:

```dart
await initDependencies();
```

## 8. Navegación y acceso público

El flujo inicial es:

```text
splash → home
```

El home es público y permite consultar la información general sin iniciar sesión.

Las rutas privadas, como el perfil, requieren una sesión válida. `go_router` se actualiza cuando cambia `AuthBloc` mediante `GoRouterRefreshStream`.

El perfil muestra para cualquier cuenta autenticada:

- Nombre.
- Correo.
- Avatar con inicial.
- Rol cuando esté disponible.
- Cierre de sesión.
- Barra de navegación inferior persistente.

## 9. Crear Firestore

En Firebase Console:

1. Abre **Build → Firestore Database**.
2. Pulsa **Create database**.
3. Selecciona **Production mode**.
4. Elige la región adecuada.
5. Confirma la creación.

Las colecciones base usadas por el proyecto son:

```text
users
teams
 tournaments
matches
```

El espacio delante de `tournaments` es solo visual; el nombre real debe ser `tournaments`.

## 10. Modelo base de datos

### `users/{uid}`

```text
uid: string
nombre: string
correo: string
rol: string
estado: string
```

Los roles actuales son `admin_liga`, `jugador`, `entrenador` y `arbitro`.

### `tournaments/{tournamentId}`

```text
ownerId: string
nombre: string
status: string
participantIds: array
currentRound: number
totalRounds: number
nextMatch: string
updatedAt: timestamp
```

### `teams/{teamId}`

```text
nombre: string
clubId: string
estado: string
```

### `matches/{matchId}`

```text
tournamentId: string
teamAId: string
teamBId: string
participantIds: array
refereeId: string
scheduledAt: timestamp
status: string
score: map
```

Firebase Authentication gestiona las contraseñas. Nunca se debe crear ni guardar `password_hash` en Firestore.

## 11. Reglas de seguridad

Las reglas viven en:

```text
firestore.rules
```

La función administrativa reconoce los custom claims:

```text
rol: admin
rol: admin_liga
```

Las reglas protegen:

- Perfiles propios en `users`.
- Torneos según propietario o participante.
- Equipos según propietario del torneo o administrador.
- Partidos según administrador, participante, árbitro asignado.
- Escrituras administrativas mediante custom claims.

Despliega desde la raíz del proyecto. En PowerShell se recomienda usar comillas:

```powershell
firebase deploy --only "firestore:rules" --project handplaydemo
```

## 12. Usuario administrador

Crear el documento en `users` con `rol: admin` no es suficiente para conceder permisos. También hay que asignar el custom claim mediante Firebase Admin SDK.

La cuenta se crea en **Authentication → Users → Add user**. Después se consulta su UID y se asigna el claim desde un script local.

Ejemplo conceptual:

```js
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp({
  credential: cert(require('./serviceAccountKey.json')),
});

getAuth().setCustomUserClaims(USER_UID, { rol: 'admin_liga' });
```

Verificación:

```js
const user = await getAuth().getUser(USER_UID);
console.log(user.customClaims);
```

Resultado esperado:

```text
{ rol: 'admin_liga' }
```

El usuario debe cerrar sesión y volver a iniciar sesión para recibir el token actualizado. Desde Flutter se puede comprobar así:

```dart
final user = FirebaseAuth.instance.currentUser;
final token = await user?.getIdTokenResult(true);
debugPrint('Rol actual: ${token?.claims?['rol']}');
```

## 13. Usuarios de prueba

El proyecto incluye:

```text
scripts/create-test-users.cjs
```

Crea o actualiza estas cuentas:

```text
admin.liga.test@handplaydemo.test → admin_liga
jugador.test@handplaydemo.test → jugador
entrenador.test@handplaydemo.test → entrenador
arbitro.test@handplaydemo.test → arbitro
```

Requisitos:

1. Descarga una clave privada desde Firebase Console → Project settings → Service accounts.
2. Guárdala localmente como `serviceAccountKey.json`.
3. No la subas al repositorio.
4. Ejecuta:

```powershell
npm install firebase-admin
node scripts/create-test-users.cjs
```

El script muestra las contraseñas temporales una sola vez. Deben guardarse de forma segura y cambiarse posteriormente.

## 14. App Check

Si aparecen mensajes como:

```text
No AppCheckProvider installed
```

significa que App Check aún no está configurado. En desarrollo Firebase usa un token provisional. No impide el inicio de sesión ni la lectura de custom claims.

App Check debe configurarse antes de producción desde Firebase Console → App Check, registrando las aplicaciones Android, iOS y Web.

## 15. Verificación final del Sprint 1

Ejecuta:

```powershell
flutter clean
flutter pub get
flutter run
```

Verifica en un dispositivo:

1. Splash.
2. Home público sin iniciar sesión.
3. Registro por correo.
4. Inicio de sesión por correo.
5. Google Sign-In.
6. Recuperación de contraseña.
7. Acceso al perfil.
8. Nombre y correo de la cuenta.
9. Rol mediante custom claim.
10. Cierre de sesión.
11. Redirección de rutas privadas.
12. Barra inferior visible en el perfil.
13. Lectura/escritura protegida por reglas Firestore.

## 16. Seguridad y limpieza

Nunca subir al repositorio:

```text
serviceAccountKey.json
.env
claves privadas
contraseñas temporales
```

Después de usar una clave administrativa local, elimínala o revócala desde Firebase Console. Si una clave privada se expone, revócala inmediatamente y genera otra.

## 17. Historial de cambios principales

Los cambios principales de Sprint 1 quedaron registrados en la rama `v0/firebase-initialization`, incluyendo:

- Configuración FlutterFire.
- Inicialización Firebase.
- Arquitectura AuthBloc por capas.
- Navegación protegida.
- Home público.
- Perfil autenticado.
- Custom claims y usuarios de prueba.
- Reglas Firestore.

Para continuar el desarrollo, crea una rama con la convención del proyecto:

```powershell
git checkout -b feature/RF-XX-descripcion
```

## 18. Nota sobre favoritos

La funcionalidad de favoritos fue eliminada del alcance actual. No se deben crear campos, reglas, pantallas ni subcolecciones relacionadas con favoritos.
