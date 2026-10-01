# Changelog

Registro de cambios del proyecto **handplay**. Este documento resume la evolución funcional a partir del historial de commits del repositorio.

## [Unreleased]

### Inscripciones y perfiles

- Se habilitó la inscripción pública y para entrenadores.
- Se agregaron datos de equipos, escudos, jugadores, posiciones, género, clubes y números de camiseta.
- Se configuraron límites de jugadores y validación de números de camiseta entre 1 y 99.
- Se agregó la consulta y reutilización de perfiles existentes durante la inscripción.
- Se permitió registrar jugadores sin perfil previo y crear perfiles buscables para entrenadores y jugadores.
- Se normalizaron los números de documento y se impidieron duplicados entre jugadores de una misma planilla.
- El entrenador puede participar o no como jugador: cuando participa conserva los roles `entrenador` y `jugador`, sin obligar a que todos los entrenadores sean jugadores.
- Se agregaron validaciones y reglas de Firestore para perfiles creados mediante inscripción pública.
- Se implementó el enlace de primer acceso para entrenadores nuevos: se crea la cuenta de Firebase Auth con una contraseña temporal aleatoria y se envía un enlace para establecer una contraseña propia; si la cuenta ya existe, se envía recuperación.

### Torneos

- Se implementó la creación, edición, eliminación y consulta pública de torneos.
- Se agregaron categorías, ramas, formatos, fechas de inicio y finalización opcional.
- Se incorporaron fechas límite de inscripción, filtros de estado y ordenamiento.
- El estado del torneo distingue `Por iniciar`, `En curso` y `Finalizado`, considerando la fecha de inicio y la finalización administrativa.
- Se agregaron equipos aprobados, conteos, detalle responsive y acciones administrativas.
- Las tablas de goleadores se muestran según la rama: masculino muestra goleador, femenino muestra goleadora y mixto muestra ambas.

### Solicitudes y equipos

- Se creó el flujo de solicitudes pendientes, aprobación, rechazo, historial y reenvío de inscripciones.
- Se agregó edición de solicitudes rechazadas y visualización de motivos.
- Se construyen equipos a partir de inscripciones aprobadas y se muestran sus detalles y plantillas.
- Se agregaron advertencias para posibles equipos duplicados y conflictos de datos.

### Usuarios, roles y árbitros

- Se implementó autenticación con Firebase y arquitectura por capas alrededor de `AuthBloc`.
- Se agregaron perfiles multirol para administradores, entrenadores, jugadores y árbitros.
- Se sincronizan roles y perfiles entre Firebase Auth y Firestore.
- Se agregaron perfiles de árbitros, niveles de acreditación, certificaciones y edición administrativa.
- La búsqueda de árbitros revisa perfiles de usuarios y directorio, incluyendo jugadores registrados.
- Se deduplican árbitros y oficiales cuando existen varios documentos para la misma persona.
- Se impiden conflictos de interés entre jugadores, árbitros y oficiales del mismo partido.

### Calendario y partidos

- Se implementó la creación y edición administrativa de partidos.
- Se agregó calendario global y calendario por torneo con nombres de equipos, uniformes, sedes, fechas y estados.
- Se asignaron árbitros, anotadores y cronometradores con validación de roles.
- Se implementó el detalle de partido y la planilla digital para roles autorizados.
- Se agregó partido en vivo con períodos, prórroga, cronómetro, goles, tarjetas, suspensiones, tiempos muertos y cronología.
- Se agregó finalización definitiva del partido y persistencia del resultado.
- Se implementó el bloqueo de planillas aprobadas: se registra quién y cuándo aprobó, se bloquean cambios posteriores en la interfaz y se refuerza la restricción con reglas de Firestore.

### Estadísticas

- Se creó la tabla de posiciones con PJ, PG, PE, PP, GF, GC, DG y puntos.
- Se reconstruyó el cálculo de posiciones desde inscripciones y partidos finalizados para evitar datos transitorios en cero.
- Se extrajo el cálculo reutilizable de estadísticas por equipo y tabla de posiciones.
- Se agregaron tablas completas de posiciones y destacados de goleadores y valla menos vencida.
- Se agregaron filtros de goleadores por rama masculina y femenina.
- El género de cada jugador es obligatorio durante la inscripción para clasificar correctamente las tablas de goleadores y goleadoras.

### Navegación, interfaz y arquitectura

- Se adoptó Clean Architecture con organización Feature-First.
- Se separaron repositorios, modelos, widgets y utilidades de equipos, partidos, torneos, árbitros y autenticación.
- Se centralizó la navegación con `go_router` y se estabilizó la navegación pública y autenticada.
- Se agregaron navegación inferior persistente, banners por rol y pantallas responsive.
- Se unificaron tema, colores, estados, filtros, botones y tarjetas de la aplicación.
- Se corrigieron problemas de splash, overflow, formularios, navegación y persistencia de perfiles.

## Historial por etapas

- **Sprint 1:** configuración inicial, autenticación, Firebase, arquitectura base y navegación.
- **Sprint 2:** torneos, inscripción de equipos, jugadores, solicitudes y aprobación de equipos.
- **Sprint 3:** árbitros, acreditaciones, calendario, oficiales y creación de partidos.
- **Sprint 4:** partido en vivo, planilla digital, eventos, cronología, estadísticas y bloqueo de planillas aprobadas.
- **Sprint 5:** perfiles multirol, estadísticas reutilizables, deduplicación y mejoras de navegación/documentación.
- **Sprint 6 en preparación:** automatización de calendario, notificaciones y asistente con IA.

## Correcciones recientes

- Se agregó el detalle interactivo de cada club, con sus equipos inscritos, jugadores y entrenadores, además de fichas resumidas para cada persona.

- Se corrigió el error de Flutter `_dependents.isEmpty` al guardar clubes: el controlador del formulario se libera después de cerrar el diálogo, se evita el doble guardado y los mensajes se muestran en el siguiente frame.

## Commits de referencia recientes

- `2e17049` — Enviar al entrenador un enlace para establecer su contraseña inicial.
- `0a17626` — Exigir género para cada jugador inscrito.
- `210b31d` — Permitir que el entrenador también se registre como jugador.
- `2de05fd` — Permitir la creación de perfiles durante la inscripción pública.
- `379dfc9` — Mostrar tablas de goleadores según la rama del torneo.
- `dea4470` — Evitar números de documento repetidos.
- `916091f` — Bloquear planillas aprobadas.
- `fa3946c` — Soportar entrenadores que también juegan.
- `fe2cb2f` — Crear usuarios buscables desde las inscripciones.
- `209e507` — Actualizar la arquitectura documentada.
- `1324ed3` — Deduplicar árbitros y oficiales.
- `697fa31` — Incorporar cálculo de estadísticas por equipo.
- `3d1c146` — Reconstruir tabla de posiciones desde partidos finalizados.
- `0079d86` — Refactorizar el detalle del torneo y estabilizar estadísticas.

> Para consultar el detalle completo y cronológico de cada cambio, usar `git log --oneline` del repositorio.

## Convenciones

- Los cambios nuevos se agregan bajo `Unreleased`.
- Cada entrada debe describir el comportamiento visible o la corrección realizada.
- Los cambios de seguridad y reglas de Firestore deben documentarse junto con su impacto funcional.
- El README debe mantenerse actualizado cuando se incorpora una funcionalidad relevante.

[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) · [Versionado semántico](https://semver.org/lang/es/)
