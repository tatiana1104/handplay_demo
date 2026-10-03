# Sprint 3 — Árbitros, calendario y oficiales

## Objetivo
Administrar árbitros y oficiales, y construir el calendario de partidos de cada torneo.

## Actividades realizadas

### 1. Directorio de árbitros
**Qué se realizó:** Se agregaron perfiles de árbitros, niveles de acreditación, certificaciones y edición administrativa.

**Cómo se realizó:** Se separó el dominio de árbitros en modelos, repositorio y pantalla. La búsqueda consulta tanto perfiles de usuarios como el directorio de personas para encontrar registros existentes.

### 2. Deduplicación de oficiales
**Qué se realizó:** Se evitó mostrar varias veces a la misma persona cuando aparece en distintas fuentes.

**Cómo se realizó:** Se normalizan documento, correo y nombre antes de construir la lista. Las coincidencias se fusionan conservando los datos más completos.

### 3. Calendario global y por torneo
**Qué se realizó:** Se creó la consulta y visualización de partidos con equipos, uniformes, sede, fecha y estado.

**Cómo se realizó:** Los partidos se guardan con referencias de torneo y equipo. Las pantallas usan repositorios para filtrar por torneo y ordenar cronológicamente.

### 4. Asignación de oficiales
**Qué se realizó:** Se permitió asignar árbitros, anotadores y cronometradores.

**Cómo se realizó:** La selección filtra por roles válidos y valida conflictos de interés antes de guardar. También se impide asignar como oficial a una persona que participa como jugador en el mismo partido.

## Resultado
El administrador puede consultar la agenda y preparar un partido con los oficiales correspondientes, manteniendo controles de rol y conflicto de interés.

## Evidencia técnica
- `lib/features/referees/`
- `lib/features/matches/`
- `lib/features/tournaments/`
- Commit relacionado: `1324ed3`.

## Pendientes
Completar la operación del partido en vivo y la planilla digital.

---

**Método de validación:** filtros por rol, deduplicación por identidad y validaciones antes de escribir el partido en Firestore.
