# Sprint 4 — Partido en vivo, planilla y estadísticas

## Objetivo
Registrar el desarrollo del partido en tiempo real y convertir sus eventos aprobados en estadísticas confiables.

## Actividades realizadas

### 1. Partido en vivo
**Qué se realizó:** Se implementaron períodos, cronómetro, goles, tarjetas, suspensiones, tiempos muertos y cronología.

**Cómo se realizó:** Los eventos se modelan con tipo, jugador, equipo, período y marca de tiempo. La pantalla permite a los roles autorizados registrar eventos y mantiene el estado sincronizado con Firestore.

### 2. Planilla digital
**Qué se realizó:** Se creó la planilla para consultar jugadores y registrar la información oficial del partido.

**Cómo se realizó:** La plantilla se obtiene de las inscripciones aprobadas. La interfaz valida jugadores, dorsales y eventos antes de permitir cambios.

### 3. Aprobación y bloqueo
**Qué se realizó:** Una planilla aprobada ya no puede modificarse desde la interfaz.

**Cómo se realizó:** Se guardan `approvedBy`, `approvedAt` y el estado de aprobación. La interfaz oculta acciones de edición y las reglas de Firestore refuerzan el bloqueo en el backend.

### 4. Tabla de posiciones
**Qué se realizó:** Se calcularon PJ, PG, PE, PP, GF, GC, DG y puntos.

**Cómo se realizó:** El cálculo reconstruye los datos desde partidos finalizados y registros aprobados, evitando que solicitudes pendientes alteren la clasificación.

### 5. Goleadores y valla menos vencida
**Qué se realizó:** Se agregaron tablas de goleadores, goleadoras y porteros destacados.

**Cómo se realizó:** El género del jugador se valida durante la inscripción y se usa para filtrar los resultados según la rama del torneo.

## Resultado
El partido queda registrado de forma auditable y las estadísticas se generan únicamente con información aprobada.

## Flujo funcional

```text
Partido programado → árbitro abre planilla → registra eventos
→ finaliza partido → revisa y aprueba planilla → estadísticas y tabla
```

## Modelo de eventos

Cada evento conserva tipo, período, jugador, equipo, minuto o marca de tiempo y usuario que lo registró. Esto permite reconstruir goles, sanciones, exclusiones y estadísticas sin depender de contadores editados manualmente.

## Seguridad y consistencia

- Solo los roles autorizados pueden editar eventos.
- Una planilla aprobada queda bloqueada para evitar cambios posteriores.
- Las estadísticas ignoran partidos no finalizados o solicitudes no aprobadas.
- La tabla se recalcula desde la fuente deportiva para evitar duplicados.

## Criterios de aceptación

- El marcador refleja los eventos registrados.
- La planilla muestra únicamente jugadores inscritos y aprobados.
- La tabla y los líderes cambian al aprobar un partido finalizado.

## Evidencia técnica
- `lib/features/matches/`
- `lib/features/statistics/`
- `lib/features/tournaments/presentation/utils/standings_calculator.dart`
- Commits relacionados: `916091f`, `697fa31`, `3d1c146`, `379dfc9`, `0a17626`.

---

**Método de validación:** pruebas de estados del partido, bloqueo de planillas y reconstrucción de estadísticas desde partidos finalizados.

## Detalle funcional implementado

- Permiso de inicio por asignación del partido.
- Duración configurable de cada tiempo y estados del marcador.
- Cuatro oficiales visibles: dos árbitros de campo, cronometrista y anotador.
- Sección de oficiales plegable y resolución de IDs a nombres.
- Cronómetro con período, estado resaltado y acciones de finalización.
- Controles de gol, exclusión, tarjeta amarilla y tarjeta roja.
- Planilla digital con equipos y jugadores inscritos.
- La planilla solo se muestra a roles de árbitro normalizados (`arbitro`, `árbitro`, `referee`).
- Eventos visibles en cronología y sincronizados con el partido.
- Estadísticas por jugador, equipo, categoría y rama.
- Tabla de posiciones calculada desde partidos finalizados sin escribir ceros transitorios en Firestore.
- Distinción de goleadores, goleadoras y porteros según género y posición.

## Trazabilidad

Los commits funcionales del partido en vivo incluyen `7887698`, `3ccadbd`, `15bb4cc`, `735a00e`, `7f490f0`, `c766d8b`, `cbe502e`, `e85c4b0`, `3ff25c2` y `f8bd046`. Cada cambio se concentró en una capacidad concreta para facilitar revisión y rollback.
