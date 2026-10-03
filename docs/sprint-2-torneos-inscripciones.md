# Sprint 2 — Torneos e inscripciones

## Objetivo
Construir el flujo principal para crear torneos, permitir la inscripción pública de equipos y administrar las solicitudes recibidas.

## Actividades realizadas

### 1. Gestión de torneos
**Qué se realizó:** Se implementaron las pantallas y operaciones para crear, editar, consultar y eliminar torneos.

**Cómo se realizó:** Se creó el modelo de torneo con categorías, ramas, formato, fechas, límite de inscripción y estado. La persistencia se separó mediante repositorios y Firestore. El detalle del torneo distingue los estados por iniciar, en curso y finalizado.

### 2. Inscripción de equipos
**Qué se realizó:** Se creó el formulario público para registrar equipos, club, uniforme, entrenador y jugadores.

**Cómo se realizó:** El formulario valida campos obligatorios, categorías, colores de uniforme, números de camiseta y límites de jugadores. El correo solicitado pertenece al club y se guarda como `clubEmail`; los datos del entrenador se solicitan por separado.

### 3. Solicitudes pendientes
**Qué se realizó:** Se agregó la bandeja administrativa para revisar, aprobar, rechazar, editar y reenviar solicitudes.

**Cómo se realizó:** Cada inscripción se almacena en la subcolección del torneo con su estado. Las acciones administrativas actualizan el estado y registran el motivo cuando corresponde.

### 4. Equipos y perfiles durante la inscripción
**Qué se realizó:** Se permitió reutilizar perfiles existentes y crear perfiles buscables para jugadores y entrenadores.

**Cómo se realizó:** La búsqueda utiliza documento, nombre y datos normalizados. Los jugadores pueden inscribirse sin correo; posteriormente, al crear una cuenta, el documento permite vincular el perfil existente al nuevo UID.

## Resultado
El administrador puede publicar un torneo, recibir inscripciones, revisar solicitudes y convertir las aprobadas en equipos utilizables por el resto de la aplicación.

## Evidencia técnica
- `lib/features/tournaments/`
- `lib/features/teams/`
- `lib/features/auth/`
- Firestore: torneos, inscripciones, equipos y perfiles.
- Commits relacionados: `5e79d8b`, `2de05fd`, `fe2cb2f`, `dea4470`, `210b31d`.

## Pendientes
Continuar con árbitros, calendario, partidos y automatización de fases del torneo.

---

**Método de validación:** revisión de reglas de negocio, persistencia en Firestore y flujo de aprobación administrativa.
