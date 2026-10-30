# Sacrifice — GDD corto

Juego de escritorio en Godot 4. Fan game personal de Sacrifice (Shiny, 2000), no comercial. La instalación original no se copia al repositorio. sacengine es el decodificador de datos y el árbitro de la simulación.

## Decisiones

- Arquitectura: estándar. Escenas y scripts juntos. Sin `src/domain/`.
- 3D.
- Multijugador online (desde 2026-10-27, MpKit 0.18): **salas que hospedan los jugadores**. El host abre la sala desde su PC (en escritorio, un proceso de partida local); los amigos entran con el código. Todo pasa por el relay (`relay-godot.fly.dev`) con tokens cortos del emisor (`issuer-godot.fly.dev`, en base64url en `config.cfg`). Nadie escribe una IP. El servidor de salas con un dedicado por partida en un VPS (RFC-034) sigue en el código, apagado (`room_server_enabled` en `sacrifice_flow.tscn`), para un despliegue futuro (`tools/deploy/`).
- «Servidor local» sigue igual: un dedicado en la PC del host, con código por asiento y asientos de IA. El dedicado directo (`--headless -- --dedicated`) queda para pruebas de humo.
- Sin Steam ni WebRTC. Un proceso dedicado por partida (decisión del 2026-10-17: el estado global de la simulación no admite varias partidas por proceso).
- Sin fork de Godot. Sin fork de `addons/mp_kit`. Lo genérico de las salas es del kit (`godot-studio-skills`).
- Blender no entra en el primer corte. Las mallas salen de sacengine.

## Fantasía

Dos a cuatro magos, en 1v1, 2v2 o todos contra todos (`ffa3`, `ffa4`), en el mapa que elige la sala. Cada uno manda desde su cliente o lo juega la IA. El servidor dedicado simula. Los compañeros de equipo son aliados: no se dañan sin fuego amigo, comparten la visión y ganan juntos (RFC-049, CHANGE-REQUEST-004).

## Fuera del primer corte

Campaña, hechizos de nivel 2 en adelante y el Shrine (las criaturas completas por nivel sí entran: RFC-030, CHANGE-REQUEST-002), export web (el audio entra con RFC-052, CHANGE-REQUEST-003), arte nuevo, modificar el motor de Godot. Los modos `slaughter`, `domination` y `soul-harvest` de sacengine tampoco entran.

## Slice jugable

1. El servidor dedicado abre el puerto y no tiene peón.
2. Dos clientes se unen a una IP y entran a High Noon con slots distintos.
3. Jugar solo no abre servidor.
4. Después: el terreno de High Noon exportado desde la instalación, un mago y una criatura, y un tick que coincida con sacengine.

## Modo solo contra la IA (CHANGE-REQUEST-001, 2026-10-14)

- Un humano contra un mago controlado por la IA, en High Noon, con los 5 dioses. Es el modo «solo»: no abre servidor.
- La IA es un jugador más: usa los mismos comandos, maná y almas que el humano. Sin trampa y sin bonificación de recursos. La percepción y las tácticas tienen diseño propio; el original (`sacengine/source/bots/shiny.d`) es referencia.
- Dificultades Fácil, Normal y Difícil, todas sin trampa. Normal parte de los números del original más las reglas de táctica de RFC-053 (`AiTactics`, CHANGE-REQUEST-005) y es la de por defecto.
- Poblados y NPC del mapa: 26 Farmers pasivos y 6 Taurocks hostiles a todos, casas neutrales. Los NPC no reaparecen. Matarlos es parte de la economía de almas: sus almas quedan rojas y pegadas al cadáver y se obtienen con Convert (Sac Doctor). Destruir una casa no da almas. La IA no los caza a propósito: sus criaturas los atacan al verlos.
- Victoria y derrota como hoy: profanar el altar enemigo y desvanecimiento.
- Un dedicado puede alojar un humano contra la IA (`--ai-slots=2`), como prueba de humo. El modo online de dos humanos no cambia.
- «Contra la IA» admite los modos con varios asientos: la IA llena los demás (aliada o rival). En una sala, el anfitrión puede poner IA en los asientos libres (RFC-049).
- Plan: `docs/archive/rfcs/RFC-024-single-player-ai.md` y `docs/archive/rfcs/RFC-024-addendum-poblados.md`. Cortes F71 a F77.

## Recorrido

El jugador abre el cliente, escribe la IP y pulsa Unirse. El dedicado, al recibir al primero, carga el mundo y se lo manda. El segundo cliente entra al mismo mundo.

## Éxito

`godot --headless --path game -- --dedicated` imprime que el puerto está listo y no sale con error. Un cliente headless o de editor puede unirse a `127.0.0.1`.
