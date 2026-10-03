# Diagrama de roles y permisos

```mermaid
flowchart LR
  AUTH[Firebase Auth] --> SESSION[Sesión activa]
  SESSION --> CLAIMS[Custom claims y roles]
  CLAIMS --> ADMIN[Administrador]
  CLAIMS --> LIGA[Administrador de liga]
  CLAIMS --> COACH[Entrenador]
  CLAIMS --> PLAYER[Jugador]
  CLAIMS --> REF[Árbitro]

  ADMIN --> A1[Gestionar torneos]
  ADMIN --> A2[Gestionar usuarios]
  LIGA --> L1[Gestionar clubes]
  LIGA --> L2[Aprobar inscripciones]
  LIGA --> L3[Asignar grupos y generar fase 1]
  COACH --> C1[Inscribir equipo]
  COACH --> C2[Gestionar plantilla]
  PLAYER --> P1[Consultar perfil y equipos]
  REF --> R1[Gestionar planilla autorizada]
  REF --> R2[Registrar eventos del partido]
```

## Matriz de autorización

| Capacidad | Admin | Admin liga | Entrenador | Jugador | Árbitro |
| --- | :---: | :---: | :---: | :---: | :---: |
| Consultar información pública | Sí | Sí | Sí | Sí | Sí |
| Crear y editar torneos | Sí | Sí | No | No | No |
| Gestionar clubes | Sí | Sí | No | No | No |
| Aprobar inscripciones | Sí | Sí | No | No | No |
| Inscribir equipo | Sí | Sí | Sí | No | No |
| Administrar plantilla propia | No | No | Sí | No | No |
| Registrar partido en vivo | No | No | No | No | Sí |
| Aprobar y bloquear planilla | Sí | Sí | No | No | Sí |
| Crear cruces de fase 2 | Sí | Sí | No | No | No |

La matriz es una guía funcional; la autorización definitiva se aplica en la ruta, el servicio y las reglas de Firestore.
