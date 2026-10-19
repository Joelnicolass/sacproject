# Sacrifice — GDD corto

Juego de escritorio en Godot 4. Fan game personal de Sacrifice (Shiny, 2000), no comercial. La instalación original no se copia al repositorio. sacengine es el decodificador de datos y el árbitro de la simulación.

## Decisiones

- Arquitectura: estándar. Escenas y scripts juntos. Sin `src/domain/`.
- 3D.
- Multijugador: online con **servidor de salas** (Godot headless, mismo proyecto, `--room-server`) que lanza **un dedicado por partida** (`host_dedicated()`, el de hoy) en un puerto del VPS. El peer 1 del dedicado no es un jugador. El cliente se conecta al lobby de `data/net/lobby_endpoint.tres`; no escribe la IP. (RFC-034; hasta que 034e cierre, el camino directo `join(ip)` sigue vigente.)
- Desarrollo local: `res://scenes/net/room_server.tscn -- --room-server` y clientes al lobby `127.0.0.1:7700`; el servidor de salas lanza los dedicados en `127.0.0.1:7800+`. El VPS corre el mismo binario y abre UDP 7700 y 7800-7831. El dedicado directo (`--headless -- --dedicated`) queda para pruebas de humo y el banco.
- Sin Steam ni WebRTC. Un proceso dedicado por partida (decisión del 2026-10-17: el estado global de la simulación no admite varias partidas por proceso).
- Sin fork de Godot. Sin fork de `addons/mp_kit`. El servidor de salas es genérico del kit; se sube a `godot-studio-skills` como RC cuando sea estable (RFC-034).
- Blender no entra en el primer corte. Las mallas salen de sacengine.

## Fantasía

Dos magos en High Noon. Cada uno manda desde su cliente, o uno de los dos lo controla la IA. El servidor dedicado simula.

## Fuera del primer corte

Campaña, hechizos de nivel 2 en adelante y el Shrine (las criaturas completas por nivel sí entran: RFC-030, CHANGE-REQUEST-002), export web (el audio entra con RFC-052, CHANGE-REQUEST-003), arte nuevo, modificar el motor de Godot. Más de un rival IA, alianzas y los modos `slaughter`, `domination` y `soul-harvest` de sacengine tampoco entran en el modo solo.

## Slice jugable

1. El servidor dedicado abre el puerto y no tiene peón.
2. Dos clientes se unen a una IP y entran a High Noon con slots distintos.
3. Jugar solo no abre servidor.
4. Después: el terreno de High Noon exportado desde la instalación, un mago y una criatura, y un tick que coincida con sacengine.

## Modo solo contra la IA (CHANGE-REQUEST-001, 2026-10-14)

- Un humano contra un mago controlado por la IA, en High Noon, con los 5 dioses. Es el modo «solo»: no abre servidor.
- La IA es un jugador más: usa los mismos comandos, maná y almas que el humano. Sin trampa y sin bonificación de recursos. Se porta de la IA del original (`sacengine/source/bots/shiny.d`).
- Dificultades Fácil, Normal y Difícil, todas sin trampa. Normal usa los números del original y es la de por defecto.
- Poblados y NPC del mapa: 26 Farmers pasivos y 6 Taurocks hostiles a todos, casas neutrales. Los NPC no reaparecen. Matarlos es parte de la economía de almas: sus almas quedan rojas y pegadas al cadáver y se obtienen con Convert (Sac Doctor). Destruir una casa no da almas. La IA no los caza a propósito: sus criaturas los atacan al verlos.
- Victoria y derrota como hoy: profanar el altar enemigo y desvanecimiento.
- Un dedicado puede alojar un humano contra la IA (`--ai-slots=2`), como prueba de humo. El modo online de dos humanos no cambia.
- Plan: `rfcs/RFC-024-single-player-ai.md` y `rfcs/RFC-024-addendum-poblados.md`. Cortes F71 a F77.

## Recorrido

El jugador abre el cliente, escribe la IP y pulsa Unirse. El dedicado, al recibir al primero, carga el mundo y se lo manda. El segundo cliente entra al mismo mundo.

## Éxito

`godot --headless --path game -- --dedicated` imprime que el puerto está listo y no sale con error. Un cliente headless o de editor puede unirse a `127.0.0.1`.
