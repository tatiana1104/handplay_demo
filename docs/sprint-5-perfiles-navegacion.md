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

## Evidencia técnica
- `lib/features/auth/`
- `lib/features/teams/presentation/screens/club_detail_screen.dart`
- `lib/features/teams/presentation/screens/clubs_screen.dart`
- Commits relacionados: `2e17049`, `c4e49f1`, `3ebfc46`, `b0d1e00`, `426c37b`, `6509383`.

---

**Método de validación:** revisión de flujos de registro, reutilización por documento, navegación de fichas y pruebas visuales en pantalla móvil.
