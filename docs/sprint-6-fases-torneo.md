# Sprint 6 — Fases de torneo y automatización inicial

## Objetivo
Configurar torneos por grupos, definir clasificados y preparar automáticamente la fase 1 cuando cierran las inscripciones.

## Actividades realizadas

### 1. Configuración de grupos
**Qué se realizó:** Al crear un torneo por grupos se puede indicar cuántos grupos tendrá la fase 1.

**Cómo se realizó:** El formulario guarda `groupCount` en el modelo del torneo y valida que existan al menos dos grupos.

### 2. Posiciones clasificadas
**Qué se realizó:** Se pueden definir las posiciones que pasan a la fase 2, por ejemplo primero y segundo de cada grupo.

**Cómo se realizó:** El administrador escribe posiciones separadas por coma; el sistema las normaliza, elimina duplicados y las ordena en `advancingPositions`.

### 3. Sorteo de grupos
**Qué se realizó:** Al cerrar la inscripción, el administrador puede distribuir aleatoriamente los equipos entre los grupos.

**Cómo se realizó:** `TournamentPhaseService` obtiene las inscripciones aprobadas, mezcla la lista con una fuente aleatoria y asigna nombres de grupo de forma balanceada. El resultado se guarda en `phaseOneGroup`.

### 4. Jornadas de fase 1
**Qué se realizó:** Se generan las jornadas y partidos de fase 1 según el formato.

**Cómo se realizó:** Para todos contra todos se generan parejas únicas de equipos. Para grupos se generan parejas únicamente dentro del mismo grupo. El número estimado de jornadas se guarda en `phaseOneRounds`.

### 5. Fase 2 manual
**Qué se realizó:** Se dejó la creación de cruces de fase 2 bajo control del administrador.

**Cómo se realizó:** La configuración solo registra posiciones clasificadas; no crea cruces automáticamente. Esto permite que el administrador decida los enfrentamientos según el reglamento.

### 6. Correcciones de compilación
**Qué se realizó:** Se corrigieron tipos numéricos y sintaxis del formulario de configuración.

**Cómo se realizó:** Se convirtió explícitamente el resultado de `clamp()` a `int`, se sustituyó una cascada inválida dentro del ternario por una función local y se movió `helperText` dentro de `InputDecoration`.

## Resultado
El administrador puede preparar la fase 1 de un torneo por grupos y conservar la información necesaria para mostrarla en la tabla de posiciones. La fase 2 queda lista para cruces manuales.

## Flujo funcional

```text
Crear torneo por grupos → definir grupos y posiciones clasificadas
→ cerrar inscripciones → administrador ejecuta asignación
→ grupos y jornadas de fase 1 → resultados alimentan tabla
→ administrador crea cruces de fase 2
```

## Reglas de distribución

- Solo se consideran inscripciones aprobadas.
- La mezcla aleatoria se ejecuta al solicitar la asignación, no al registrar cada equipo.
- Los equipos se reparten de forma balanceada y reciben identificadores como Grupo A, Grupo B, etc.
- En grupos, los emparejamientos se limitan a equipos del mismo grupo.
- En todos-contra-todos, cada pareja se genera una sola vez.

## Criterios de aceptación

- El formulario exige al menos dos grupos cuando el formato es por grupos.
- Las posiciones clasificadas se guardan ordenadas y sin duplicados.
- La acción de fase 1 solo está disponible al administrador y con inscripción cerrada.
- La fase 2 no genera cruces automáticamente: quedan bajo decisión administrativa.

## Evidencia técnica
- `lib/features/tournaments/domain/models/tournament_models.dart`
- `lib/features/tournaments/data/tournament_phase_service.dart`
- `lib/features/tournaments/presentation/screens/create_tournament_screen.dart`
- Commits relacionados: `3235a18`, `9dc3e9a`, `ae5c336`.

## Riesgos y pendientes
- Validar el cálculo de jornadas con el reglamento oficial de la Liga.
- Integrar la visualización de `phaseOneGroup` directamente en todos los componentes de tabla de posiciones.
- Ejecutar `flutter analyze` y pruebas en dispositivo con Flutter instalado.

---

**Método de validación:** `git diff --check`, revisión de tipos Dart y verificación del flujo de cierre de inscripciones.

## Detalle funcional implementado

- El formulario de creación muestra grupos y posiciones clasificadas únicamente cuando el formato es `por_grupos`.
- `advancingPositions` se normaliza, ordena y guarda sin duplicados.
- La acción de asignar fase 1 se muestra solo al administrador cuando la inscripción está cerrada.
- Se consideran únicamente solicitudes con `status: approved`.
- Los equipos se mezclan aleatoriamente y se reparten de manera balanceada.
- Se guarda `phaseOneGroup` en cada inscripción para mostrar Grupo A, Grupo B, etc. en la tabla.
- Se calculan enfrentamientos sin repetir parejas y jornadas dentro del grupo correspondiente.
- Todos-contra-todos usa un grupo general y genera jornadas de ida y vuelta; con tres equipos produce A-B, B-C, C-A y después B-A, C-B, A-C.
- La fase 2 no crea cruces: el administrador conserva el control manual.

## Incidencias y soluciones

- Se corrigió el tipo de `clamp()` convirtiendo su resultado a `int`.
- Se reemplazó una cascada inválida dentro de un ternario por una función local con ordenamiento explícito.
- Se movió `helperText` dentro de `InputDecoration` para corregir la compilación.
- Se dejó documentada la necesidad de probar con `flutter analyze` cuando Flutter esté disponible.
