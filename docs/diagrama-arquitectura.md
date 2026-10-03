# Diagrama de arquitectura

## Objetivo

Handplay es una aplicación Flutter organizada por funcionalidades y capas, con Firebase como plataforma de autenticación y persistencia.

```mermaid
flowchart LR
  UI[Flutter UI\nPantallas y widgets] --> P[Presentation\nBLoC / estado]
  P --> D[Domain\nEntidades, contratos y casos de uso]
  D --> DA[Data\nRepositorios y datasources]
  DA --> FA[Firebase Auth]
  DA --> FS[(Cloud Firestore)]
  UI --> R[go_router\nRutas públicas y protegidas]
  P --> SH[Shared widgets\nTema y componentes comunes]

  subgraph Features[Feature-first]
    AUTH[auth]
    TOU[tournaments]
    TEA[teams]
    MAT[matches]
    REF[referees]
  end
  Features --> P
```

## Capas

| Capa | Responsabilidad |
| --- | --- |
| `presentation` | Renderiza pantallas, formularios y estados de interacción. |
| `domain` | Define modelos, reglas y contratos independientes de Firebase. |
| `data` | Implementa repositorios, consultas, escrituras y transformación de datos. |
| `shared` | Reúne tema, navegación, componentes y utilidades reutilizables. |

## Flujo de una operación

```mermaid
sequenceDiagram
  actor Usuario
  participant Pantalla
  participant Bloc as BLoC/Caso de uso
  participant Repo as Repositorio
  participant Firestore

  Usuario->>Pantalla: Ejecuta una acción
  Pantalla->>Bloc: Envía evento o llama caso de uso
  Bloc->>Repo: Solicita lectura/escritura
  Repo->>Firestore: Consulta o actualiza datos
  Firestore-->>Repo: Resultado
  Repo-->>Bloc: Entidad o error
  Bloc-->>Pantalla: Estado loading/success/error
  Pantalla-->>Usuario: Actualiza la interfaz
```

## Decisiones técnicas

- Firebase Auth gestiona identidad y sesiones.
- Firestore conserva torneos, inscripciones, equipos, partidos, perfiles y clubes.
- Las reglas de Firestore complementan las validaciones de la interfaz.
- Las rutas protegidas dependen de sesión y roles.
- Los cruces de fase 2 se mantienen como una decisión manual del administrador.
