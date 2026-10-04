# Sprint 5 — Perfiles multirol y navegación

## Objetivo
Consolidar los perfiles multirol, mejorar la navegación administrativa y estabilizar la experiencia de clubes y cuentas.

## Actividades realizadas

### 1. Perfiles multirol
**Qué se realizó:** Se permitió que una persona tenga simultáneamente roles de entrenador y jugador, además de los roles administrativos y arbitrales.

**Cómo se realizó:** Firebase Auth identifica la cuenta y Firestore conserva `roles`, `rol` y los datos específicos. Las actualizaciones usan unión de roles para no sobrescribir permisos existentes.

### 2. Primer acceso de entrenadores
**Qué se realizó:** Los entrenadores nuevos reciben un enlace para definir su contraseña.

**Cómo se realizó:** Se crea la cuenta con una contraseña temporal aleatoria y se envía un enlace de recuperación. Si el correo ya existe, se envía recuperación sin duplicar la cuenta.

### 3. Vinculación por documento
**Qué se realizó:** Una cuenta nueva puede recuperar la información de un jugador inscrito sin correo.

**Cómo se realizó:** El registro solicita número de documento y busca coincidencias en `profile_directory` y `users`. Si encuentra un perfil, conserva sus datos y lo vincula al UID nuevo.

### 4. Catálogo y detalle de clubes
**Qué se realizó:** Los clubes se pueden consultar, abrir y explorar.

**Cómo se realizó:** Cada club abre una pantalla con equipos, jugadores y entrenadores. Las fichas enlazan con información resumida de las personas.

### 5. Estabilidad de formularios
**Qué se realizó:** Se corrigió el assertion `_dependents.isEmpty` al guardar clubes y se eliminó el campo de club libre de la inscripción.

**Cómo se realizó:** El diálogo de clubes se convirtió en un widget Stateful autónomo. El selector de clubes oficiales usa `isExpanded` para evitar overflow en móviles.

## Resultado
La aplicación mantiene una identidad coherente por persona, soporta varios roles y ofrece navegación estable entre clubes, equipos y perfiles.

## Flujo de identidad

```text
Cuenta Firebase Auth → búsqueda por UID/documento → perfil Firestore
→ combinación de roles → rutas y capacidades disponibles
```

## Decisiones técnicas

- `roles` se actualiza mediante unión para conservar permisos existentes.
- El documento nacional funciona como clave de vinculación cuando el perfil nació desde una inscripción.
- El catálogo de clubes es la fuente de selección para nuevas inscripciones.
- Los diálogos con formularios administran sus propios controladores para evitar ciclos de vida inválidos.
- La navegación se adapta a usuarios anónimos, autenticados y administradores.

## Criterios de aceptación

- Una persona no pierde roles al completar o editar su perfil.
- Un jugador inscrito puede recuperar su información al crear cuenta.
- El detalle de club navega a equipos, jugadores y entrenadores.
- El formulario de clubes no produce el assertion `_dependents.isEmpty`.

## Evidencia técnica
- `lib/features/auth/`
- `lib/features/teams/presentation/screens/club_detail_screen.dart`
- `lib/features/teams/presentation/screens/clubs_screen.dart`
- Commits relacionados: `2e17049`, `c4e49f1`, `3ebfc46`, `b0d1e00`, `426c37b`, `6509383`.

---

**Método de validación:** revisión de flujos de registro, reutilización por documento, navegación de fichas y pruebas visuales en pantalla móvil.

## Detalle funcional implementado

- Perfil muestra nombre, documento, correo, cambio de contraseña y cierre de sesión.
- Usuarios con múltiples roles acceden a fichas independientes de jugador, entrenador y árbitro.
- Se normalizan equivalencias `player/jugador`, `coach/entrenador`, `referee/arbitro` y `public/publico`.
- El formulario de perfil persiste correo, documento y datos específicos de cada rol.
- Se detectan perfiles ya completos mediante banderas de completitud o datos obligatorios guardados.
- Se conserva el array de roles existente durante la actualización de perfil.
- El banner se incorporó a listado, detalle y alta de árbitros, calendario, equipos y perfil.
- Visitantes ven Home, Calendario e Iniciar sesión; usuarios autenticados ven Perfil según permisos.
- Se resolvieron problemas de navegación con `go_router`, `Navigator.push` y limpieza de pila al volver a Home.

## Incidencias y soluciones

- Se corrigió la coma faltante de `AppBar` en `profile_screen.dart`.
- Se eliminó el argumento `bottomNavigationBar` duplicado del detalle de árbitro.
- Se corrigió el assertion `_dependents.isEmpty` convirtiendo el diálogo de clubes en un widget Stateful autónomo.
- La edición sincroniza `users/{uid}` y `profile_directory/{uid}` para que los cambios sean visibles en la base de datos.
- La ficha de entrenador incluye club asociado y correo del club.
- El administrador puede asignar nombre y correo de asistente desde el catálogo de clubes.
- Se retiraron de formularios, fichas y sincronización los campos de experiencia y especialidad.
