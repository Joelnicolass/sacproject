# Rules

Producto: juego Godot 4. Checks de web, SQL, auth y negocio: no aplican.

## Stack

- Godot 4.7.2 (`/Applications/Godot.app`, binario `/Applications/Godot.app/Contents/MacOS/Godot`). Verificado con `--version`.
- GDScript.
- MpKit 0.13.0 (`plugin.cfg`; RFC-034, puerta de arranque RFC-068, pantalla de carga RFC-069: `MpWorldLoader` carga el mundo en un hilo, el mundo avisa cuándo está listo y la puerta también se arma en solo). El RC publicado es `rc/v0.10.0`; el hotfix de 068 va como `rc/v0.11.0` y el de 0.11.1 (la puerta decide sola: ENet deja lugar a los que esperan y el rechazo llega con razón; el mundo del host LAN carga al final del frame; `spawn_function` se toma al final del `_ready` de la escena; la puerta da sus cuentas también en el cliente) como `rc/v0.11.1`; la base es el 0.11.1 corregido (`rc/v0.11.1-spanish` @ 61c97cd: el dedicado sirve una partida tras otra, `late_join` apagado, un solo `start_seats`), el kit publica K1–K6 como 0.12.0 y la pantalla de carga (carga en hilo, `world_reports_loaded`, `report_loaded`, puerta en solo) va como 0.13.0. No meter reglas de Sacrifice en el addon. Si el plugin necesita un arreglo, se edita: el autor es el mismo del juego y el cambio se sube después a `godot-studio-skills`.

## Arquitectura

Estándar. Escenas en `scenes/`. Sin `src/domain/`.

Estructura por dominio (RFC-048). Cada carpeta tiene su `README.md`.
- `scenes/<dominio>/`: código y escenas del producto (`ai`, `audio`, `bodies`, `camera`, `components`, `core`, `fx`, `gods`, `look`, `map`, `match`, `net`, `orders`, `sacrifice`, `souls`, `spells`, `structures`, `ui`, `units`, `wizards`). Nada suelto en la raíz de `scenes/`.
- `data/`: Resources `.tres` por tipo (`data/catalog/<tipo>/`, `gods/`, `look/`, `nav/`, `maps/`, `audio/`...).
- `debug/<dominio>/`: escenas y reglas de desarrollo (`suite/` = casos del banco, `rules/` = `MatchRules` de prueba). No entra en el export.
- `tools/`: `import/`, `bake/`, `audit/`, `material/`, `deploy/`. `agent/`: `runs/`, `flows/`, `fixtures/`, `harness/`, `scripts/`. Ni `scenes/` ni `data/` nombran `res://debug|agent|tools`.
- Las mudanzas de rutas se hacen con `tools/move_map.py` y un CSV (`--check --lint` debe dar 0). Los commits de mudanza están en `.git-blame-ignore-revs`.

Convenciones de código en `CONVENTIONS.md`; `tools/lint/conventions.sh` es el ratchet (falla si un conteo sube; cada corte que baja uno reescribe `tools/lint/baseline.txt`).

Autoload: `MpKit` antes que `SacrificeFlow`.

## Red

Online = servidor de salas + dedicado por partida. El dedicado admite solo con ticket (`MpKit.admission`; sin `admission` queda el modo directo `join(ip)`, para pruebas y banco). Todo camino de red pasa por la puerta de arranque (`MpMatchGate`, RFC-068): la partida arranca cuando cargaron los asientos que espera; después solo vuelve un asiento que se cayó, dentro de `rejoin_grace_s`, y cualquier otro peer se rechaza con un motivo. El dedicado a mano también tiene la puerta: arranca con `--start-seats=N` asientos cargados (0 por defecto = todos, o los que cargaron pasado `load_timeout_s`), así que una corrida con un cliente pasa `--start-seats=1` y una con dos `--start-seats=2` y un «late join» se prueba como rejoin. Los clientes no escriben IP: `MpLobby` + `join_endpoint`. `play_solo()` no abre servidor. El host LAN no es el camino de internet. Lo genérico de salas vive en `addons/mp_kit/lobby/` sin textos ni reglas de Sacrifice; validadores, opciones y resultado van en `scenes/net/`.

El mapa y el modo de una partida en red los elige la sala y viajan en el ticket (`world`, `mode`). El cliente los recibe del dedicado; nunca los elige él. Un modo es un `GameMode` `.tres` en `data/modes/` (RFC-049); los equipos no entran al kit: para el kit son asientos y nada más.

Puntuación, textos y victoria viven fuera de `addons/mp_kit`.

## Datos

La instalación de Sacrifice se lee en local. Los WAD no se commitean nunca.

Desde el 2026-10-17 (decisión del usuario, RFC-023), los assets finales del port se versionan en `game/assets/original/` con git LFS: cada modelo es un `.glb` con su esqueleto y todas sus animaciones, uno por modelo, sin copias por cuadro. El port no depende de ninguna caché: todo sale de `assets/original/` (RFC-033).

sacengine aporta los números del juego (daño, hechizos, reglas). El mapa se edita en Godot (RFC-035): el terreno es la grilla 256² de `heights.png` + `void.png` (scenes/map/maps/<tag>/), los edificios y las criaturas son nodos de `map.tscn` (`Buildings`, `Npcs`) y la navegación es un navmesh de Godot (`NavigationRegion3D`, `nav.res` junto al mapa, horneado con `tools/bake/bake_nav.tscn`). Un mapa es una carpeta `scenes/map/maps/<tag>/` con su `map.tscn` y su `MapDefinition` `.tres`, listado en `data/maps/map_catalog.tres` (RFC-044); `--map=<tag>` lo elige, sin tocar código. No hay grilla propia de caminos. En Godot el movimiento usa el motor: `CharacterBody3D`, `move_and_slide`, colisión y gravedad. No se reescribe un integrador ni un rayo de pies al lado de eso. El dedicado, cuando hay red, es quien mueve el cuerpo. El cliente manda la orden y pinta.

## Idioma

Textos de pantalla en español. Nombres de archivos y de nodos en inglés.

## IA

La IA es un jugador más. Todo lo que hace pasa por un solo puerto que llama a lo mismo que el humano (`request_cast`, `request_summon`, `Orders`): paga maná y almas y respeta enfriamientos y alcance. Sin bonificación de recursos ni trampa, en ninguna dificultad. Existe solo en el proceso que simula (solo o dedicado) y no agrega RPC. Vive fuera de `addons/mp_kit`. Las partidas con IA son reproducibles con `match_seed`. Un asiento IA de sala es un asiento sin token (un bot del kit, siempre listo); el dedicado lo sienta con `AiRoster` (RFC-049).

## Fidelidad y pruebas

Desde el 2026-10-18 (decisión del usuario), hasta la v1 estable:

- Godot estándar antes que el original. Navegación, física y animación usan lo del motor, con tolerancia amplia. Desde RFC-036, la separación entre cuerpos es la evasión de Godot (`BodyAvoidance`, NavigationAgent3D, prioridad del mago mayor que la de sus criaturas). Las animaciones son una escena por modelo con su `AnimationTree` (`scenes/bodies/models/`). El catálogo de criaturas, hechizos, magos y edificios se edita como `.tres` en `data/catalog/`. Las partículas llevan su textura en el `.tres`. Del original se copia solo lo que se nota al jugar: números de daño, hechizos y reglas. No hace falta ser 100 % fiel.
- El banco de determinismo es una prueba de humo, no un contrato byte a byte. `quick` corre en cada corte. Si un digest cambia por un cambio hecho a propósito, se regraba la base y se anota una línea en el F. Sin informe de primer tick distinto ni los 4 modos. `all` queda para el cierre de un RFC.
- Los cortes chicos son developer y verificación del orquestador, sin review separada. La review queda para cambios grandes de comportamiento o arquitectura.
- La exactitud byte a byte se puede retomar después de la v1.
