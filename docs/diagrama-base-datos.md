# Diagrama de base de datos

## Modelo lógico Firestore

Firestore utiliza una colección principal de torneos con subcolecciones operativas. Los perfiles globales se mantienen en `users` y `profile_directory` para permitir vinculación por documento incluso cuando una inscripción no solicita correo.

```mermaid
erDiagram
  USERS {
    string uid PK
    string displayName
    string email
    string document
    string documentNumber
    string[] roles
    timestamp createdAt
  }
  PROFILE_DIRECTORY {
    string id PK
    string uid FK
    string name
    string document
    string documentNumber
    string phone
    string role
  }
  CLUBS {
    string id PK
    string name
    string normalizedName
    timestamp createdAt
  }
  TOURNAMENTS {
    string id PK
    string name
    string format
    string status
    int groupCount
    int[] advancingPositions
    int phaseOneRounds
    timestamp registrationDeadline
  }
  REGISTRATIONS {
    string id PK
    string teamName
    string clubEmail
    string coachDocument
    string phaseOneGroup
    string status
    string tournamentId FK
  }
  TEAMS {
    string id PK
    string registrationId FK
    string name
    string status
  }
  MATCHES {
    string id PK
    string tournamentId FK
    string homeTeamId FK
    string awayTeamId FK
    int phase
    int round
    string status
    int homeScore
    int awayScore
  }
  USERS ||--o{ PROFILE_DIRECTORY : "se vincula por documento"
  TOURNAMENTS ||--o{ REGISTRATIONS : contiene
  TOURNAMENTS ||--o{ MATCHES : programa
  REGISTRATIONS ||--o| TEAMS : construye
  CLUBS ||--o{ REGISTRATIONS : asocia
  MATCHES }o--|| TEAMS : local
  MATCHES }o--|| TEAMS : visitante
```

## Rutas Firestore

```text
users/{uid}
users/club_{emailKey}  (usuario de club creado al inscribir)
clubs/{clubId}          (email, coachName, coachDocument, coachEmail, assistantName, assistantDocument, assistantEmail)
users/club_{emailKey}   (usuario Firestore asociado al correo del club)
profile_directory/{profileId}
clubs/{clubId}
tournaments/{tournamentId}
tournaments/{tournamentId}/registrations/{registrationId}
tournaments/{tournamentId}/teams/{registrationId}
tournaments/{tournamentId}/matches/{matchId}  (jornada, leg: ida|vuelta, homeTeamId, awayTeamId)
```

## Estados principales

```mermaid
stateDiagram-v2
  [*] --> pending: Inscripción creada
  pending --> approved: Administrador aprueba
  pending --> rejected: Administrador rechaza
  rejected --> pending: Reenvío o edición
  approved --> teamCreated: Equipo construido
  teamCreated --> active: Participa en partidos
```

## Integridad y seguridad

- `document` y `documentNumber` permiten localizar perfiles existentes.
- `clubEmail` identifica al correo institucional del club, no al entrenador.
- Las estadísticas se calculan con inscripciones y partidos aprobados/finalizados.
- Los partidos y planillas respetan roles y permisos de Firebase.
- Un registro pendiente no debe alimentar tablas públicas de posiciones.
