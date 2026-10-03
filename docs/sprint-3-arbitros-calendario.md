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

## Flujo funcional

```text
Árbitro registrado → validación de rol/acreditación → administrador crea jornada
→ selecciona equipos, sede y horario → asigna oficiales → partido publicado
```

## Datos y reglas relevantes

- Los partidos mantienen referencias a torneo, jornada, equipos, sede, fecha, hora y oficiales.
- La interfaz resuelve nombres, escudos y colores desde los equipos aprobados.
- La agenda ordena los partidos cronológicamente y permite filtrar por torneo.
- Se evita asignar un jugador del partido como árbitro u oficial del mismo encuentro.
- La deduplicación usa documento, correo y nombre normalizados para no repetir personas.

## Criterios de aceptación

- El administrador puede construir una jornada completa.
- Un partido no se guarda con equipos u oficiales incompatibles.
- Los usuarios pueden consultar el calendario sin modificarlo.

## Evidencia técnica
- `lib/features/referees/`
- `lib/features/matches/`
- `lib/features/tournaments/`
- Commit relacionado: `1324ed3`.

## Pendientes
Completar la operación del partido en vivo y la planilla digital.

---

**Método de validación:** filtros por rol, deduplicación por identidad y validaciones antes de escribir el partido en Firestore.

## Detalle funcional implementado

- Acceso a Árbitros visible para `admin` y `admin_liga`, incluido Perfil.
- Icono deportivo de árbitro mediante Material Icons disponible.
- Niveles municipal, departamental y nacional con prerrequisitos secuenciales.
- Alta, edición y consulta de árbitros por documento, nombre, correo, teléfono y acreditación.
- Perfil de árbitro con accesos a sus fichas de jugador o entrenador cuando corresponda.
- Jornadas navegables desde el detalle del torneo.
- Calendario global con agrupación por día, hora, sede, equipos y estado.
- Estados normalizados: `Por iniciar`, `Jugando` y `Finalizado`.
- Presentación consistente de local a la izquierda y visitante a la derecha.
- Resolución de nombres, identificadores, colores y uniformes sin mostrar UIDs durante la carga.
- Asignación manual de dos árbitros de campo, cronometrista y anotador.
- Validación de conflicto cuando un árbitro pertenece a la plantilla local o visitante.

## Colecciones y operaciones

Los partidos se almacenan en `tournaments/{id}/matches`. El administrador crea la jornada y el partido; los usuarios consultan el calendario sin permisos de escritura. La generación automática de jornadas fue trasladada al Sprint 6.
