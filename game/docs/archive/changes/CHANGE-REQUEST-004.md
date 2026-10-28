# CHANGE-REQUEST-004: equipos (2v2, todos contra todos) y mapa elegido por la sala (RFC-049)

Fecha: 2026-10-19.
Pedido del usuario: «2v2 completo y que la sala elija el mapa en red».
Las decisiones de la cola están delegadas («iterar la cola sin preguntar»). Las del §13 de RFC-049 las tomó el orquestador (P1–P10) y el usuario puede cambiarlas.

## Clasificación

- **Tipo:** Scope Change. Feature nueva, Large, Must have.
- **Qué saca de los no-goals:** «Más de un rival IA, alianzas» estaba fuera del primer corte en `PRD.md`. RFC-034 §12 dejaba fuera «más de 2 asientos por sala» y «salas con IA».

## Conflicto

- **PRD §Fantasía:** decía «Dos magos en High Noon». Ahora son de dos a cuatro magos, en 1v1, 2v2 o todos contra todos, en el mapa que elige la sala.
- **PRD §Fuera del primer corte:** se saca «Más de un rival IA, alianzas». Siguen fuera los modos `slaughter`, `domination` y `soul-harvest`.
- **RFC-034 §12:** las salas tienen los asientos de su modo y admiten asientos IA. Queda una nota en §12.
- **F262:** `SacrificeFlow.max_players` dejaba el 2v2 «para otro RFC». Ese RFC es RFC-049.
- **RULES:**
  - No se viola ninguna regla. El kit sigue sin reglas de Sacrifice: para el kit, los equipos son asientos y un asiento IA es un bot genérico.
  - Se agregan dos líneas: el mapa y el modo los elige la sala y viajan en el ticket; un asiento IA de sala es un asiento sin token que el dedicado sienta con `AiRoster`.

## Impacto

- **Simulación:** postura de aliado en `SideRelations` y en las reglas que comparaban slots. En 1v1 no se instala la capa de equipos: el banco `quick` no se regrabó.
- **Red:** ticket v2 (`mode`, `ai_seats`), protocolo del lobby `proto_version` 2. Un cliente viejo recibe `version`.
- **Mapas:** High Noon tiene dos inicios. El 2v2 se juega en `winter_wonder` (RFC-050) o en `test_flat4` (prueba).

## Alternativas rechazadas

- **Equipos libres por jugador** (un `team` en la meta del asiento): el original pone los equipos por asiento (`--2v2`), y cambiar de asiento ya existe.
- **Modo dentro de `MatchRules`:** `MatchRules` son las reglas de ronda; el modo es una elección de la sala, como el mapa, y necesita un catálogo listable.
- **Importar un mapa de 4 dentro de RFC-049:** es trabajo de mapa, no de equipos. Fue a RFC-050.

## Artefactos actualizados

- `PRD.md` (fantasía, fuera del primer corte, modo solo)
- `FEATURES.md` (Modos y equipos, F290–F298) y `docs/archive/CHANGELOG-features.md`
- `RULES.md` (red, IA)
- `docs/archive/rfcs/RFC-034-room-server.md` (nota en §12)
- `docs/archive/rfcs/RFC-049-teams-and-room-map.md` (estado)
- `docs/HOWTO.md` («Un mapa», «Un modo», «Jugar 2 contra 2»)
