# Sprint 2 — Torneos e inscripciones

## Actividades realizadas

- Se crearon modelos, repositorios y consultas reactivas para torneos, categorías, sedes, equipos y jugadores.
- Se implementó la creación y edición de torneos para `admin_liga`, con formatos todos-contra-todos y por grupos.
- Se construyó la inscripción pública de equipos con club, entrenador, contacto, jugadores y consentimiento.
- Se implementaron estados `pending`, `approved` y `rejected`, revisión administrativa, motivos de rechazo y reenvío.
- Se agregaron validaciones de documentos, camisetas, uniformes, similitud y reglas de acceso Firestore.
- Se implementaron vistas de equipos aprobados, detalle del equipo y perfil del jugador.

## Resultado y validación

El administrador puede gestionar torneos e inscripciones y el entrenador puede consultar el estado de sus solicitudes. La información se persiste en Firestore y las consultas se actualizan en tiempo real.


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

## Flujo funcional

```text
Administrador crea torneo → publica inscripción → club registra equipo
→ solicitud pendiente → revisión administrativa → aprobada/rechazada
→ equipo disponible para calendario y estadísticas
```

## Datos y seguridad

- El torneo controla `publicRegistration`, fechas, categorías, ramas y límites.
- La solicitud conserva el correo del club como `clubEmail`; no se usa como correo del entrenador.
- Las inscripciones se consultan dentro del torneo y se filtran por `status`.
- Las operaciones administrativas comprueban el rol antes de modificar estados.
- Las reglas validan campos obligatorios y evitan que una inscripción pública se cree en un torneo cerrado.

## Criterios de aceptación

- Un usuario puede consultar torneos públicos sin iniciar sesión.
- Un club puede enviar una solicitud con jugadores válidos y datos de contacto.
- El administrador puede aprobar o rechazar con trazabilidad.
- Un equipo aprobado aparece en los módulos que consumen participantes.

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

## Detalle funcional implementado

- Categorías: `master`, `mayor`, `juvenil`, `cadete`, `infantil` y `libre`.
- Ramas: femenino, masculino y mixto.
- Selección de varias combinaciones categoría-rama sin botón adicional.
- Formatos todos-contra-todos y por grupos.
- Fecha final opcional y validación de fechas de inicio y cierre.
- Inscripción pública sin cuenta y flujo alternativo con sesión de entrenador.
- Correo solicitado como `clubEmail`, ubicado dentro de los datos del equipo.
- Entrenador opcionalmente inscrito también como jugador sin perder sus roles.
- Validación de documentos repetidos, género, posiciones y dorsales del 1 al 99.
- Clubes y jugadores seleccionados desde catálogos para evitar discrepancias de escritura libre.
- Advertencias de similitud por nombre, documento, uniforme y color.
- Rechazo con motivo visible, edición de la misma solicitud y reenvío a `pending`.
- Equipos aprobados consultables con entrenador, plantilla, métricas y perfil individual.

## Modelo de persistencia

```text
tournaments/{tournamentId}
├── registrations/{registrationId}
├── teams/{teamId}
└── matches/{matchId}

users/{uid}
profile_directory/{document}
teams/{teamId}
```

Las solicitudes aprobadas alimentan el contador y la lista pública de equipos; la colección `teams` funciona como índice auxiliar. Las reglas permiten leer información pública aprobada, pero mantienen protegidas las solicitudes pendientes y rechazadas.

## Incidencias y soluciones

- Se deshabilitó temporalmente el logo del equipo hasta contar con almacenamiento configurado.
- Se eliminó el campo de club libre y se usó el catálogo oficial.
- Se corrigió el correo para que pertenezca al club y no se use para invitar o vincular al entrenador.
- Se respetó el área segura inferior del dispositivo en el botón de envío.
- Se mantuvo la colección de equipos existente como compatibilidad con datos previos.
- La colección `clubs` guarda el correo oficial, el documento y correo del entrenador y el documento y correo del asistente; el administrador puede buscar ambas personas por documento y actualizar la asignación. en `email` y el detalle del club lo muestra aunque aún no existan equipos; al crear o actualizar el club se crea o actualiza automáticamente un perfil en `users/club_<emailKey>` y `profile_directory/club_<emailKey>`.
- El correo del club se conserva como identidad del club y no se asigna al entrenador.
