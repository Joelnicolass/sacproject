---
name: godot-mp-kit
description: >-
  Implementa multiplayer host-authoritative en Godot 4 con el addon informal
  MpKit (ENet, slots, handshake, snapshots) más glue del juego. Preguntá antes
  el tipo: sin MP (no copies el addon), local/WiFi (listen-server), u online
  (dedicated server, mismo proyecto, VPS). Usar al copiar addons/mp_kit,
  host/host_dedicated/join, RPCs submit_*, túnel Dictionary, MultiplayerSpawner,
  1P offline, rejoin, export dedicated, scaffold de feature, o al extraer
  netcode a otro proyecto.
---

# Godot — MpKit y multiplayer

Un simulador (servidor). Los clientes mandan intenciones y pintan copias. El addon es pequeño a propósito: tubería reusable, cero gameplay.

Arquitectura: [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (**preguntar** Clean vs estándar; no asumir capas). Nodos/FX/Resources: [godot-composition-first](../godot-composition-first/SKILL.md). Dedicated / VPS: [dedicated.md](dedicated.md).

## Alcance de red (obligatorio)

**Preguntar siempre** (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está) **antes** de copiar el addon o de escribir RPCs. No asumas LAN.

| Elección | Qué hacer |
|----------|-----------|
| **Sin multiplayer** | No instales MpKit. Sin autoload, sin RPC, sin `MultiplayerSpawner`. |
| **Local / WiFi** (mismo dispositivo o misma LAN) | `MpKit.host()` listen-server. El proceso host **es** un jugador (slot 1 / peer 1). |
| **Online** (internet, VPS) | **Dedicated server** en el **mismo proyecto**. `MpKit.host_dedicated()`; clientes `join(ip)`. Peer 1 **no** es jugador. Desarrollá así desde el día uno (headless + clientes a `127.0.0.1`); la VPS es el mismo binario con IP pública y UDP abierto. Varias partidas = **salas in-process** (`MpKit.rooms` / `MpKit.matchmaker`) en ese proceso. Steam / WebRTC / process-per-match: solo si el producto los pide, **después**, no en lugar de dedicated. |

No preguntar de nuevo si el usuario ya eligió en este chat o el PRD/RULES lo declara.

Tipos de pawn/proyectil/enemigo: Resource `.tres` en el actor, no un RPC por `kind` string.

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

En red eso se traduce a:

| Prioridad | En MpKit / glue |
|-----------|-----------------|
| Capas | `addons/mp_kit` no nombra sesión, escenas, copy ni puntaje. Online = dedicated en el addon, no un `NetworkManager` del título. |
| Composición | Transport (kit) + glue + (`GameSession` **o** nodo Match) + actores con `submit_*`. |
| Editor | Spawners, replication config y escenas de pawn se arman como nodos. El kit no genera el mundo. |
| Reuso | Copiar el addon canónico. El juego escribe glue + dominio; no forks del kit por título. |

## Fuente canónica

El plugin es `addons/mp_kit/` **dentro del proyecto Godot**. Copiá esa carpeta tal cual a otro título. No forkearla por juego.

Si el addon del proyecto y una copia suelta divergen, gana `res://addons/mp_kit/` de este proyecto.

API: [kit-api.md](kit-api.md). Glue: [game-glue.md](game-glue.md). Dedicated: [dedicated.md](dedicated.md). Editor / túnel / scaffold: [editor.md](editor.md). Código genérico: [examples.md](examples.md).

Guía humana (inspector, paso a paso, túnel custom, salas hub y cola): `addons/mp_kit/README.md`.

## Arranque en 5 pasos

1. Copiá `addons/mp_kit/` y enable **MpKit** (autoload `MpKit` **antes** del flow).
2. Tools → **MpKit: New session flow...** (o `extends MpFlow`). Asigná boot/world. `play_solo()` / `host_lan()` / `join_lan()`. 1P: no llames `host()` a mano.
3. En el match: un `MpSpawner` o `MpSlotSpawner` (`spawn_path` = padre de actores). El cliente pide `world_ready` solo; no hace falta un nodo `MpWorldReady`.
4. Pawns: hijo `MpReplicate` + `submit_*` con `MpAuthority.accept_command(self, player_slot)`.
5. LAN: `MpFlow` ya hace `advertise` en el host; el lobby hace `browse` (o `MpBootMenu`). Online: dedicated + IP pública, no `host()` detrás de NAT.

## Qué es el kit / qué no

Copiar `addons/mp_kit/` → autoload `MpKit`.

**Hace:** ENet listen o dedicated, mapa slot ↔ peer, cupo, handshake `world_ready`, push de `Dictionary` opaco (snapshot **y** túnel `send_custom`), signals, nodos de replicación, `MpBoot`. Opcional: `MpFlow` (escenas host/join/1P, no reglas). Opcional: salas hub in-process (`MpRoomDirectory` + cola FIFO `MpMatchmaker`) en un dedicated.

**No hace:** score, copy de un título, input de actor, predicción, Steam/WebRTC, process-per-match, “cuándo gana alguien”. `MpReplicate.interpolate` es un lerp opcional de proxy, no rollback.

Si metés puntaje en `mp_kit.gd`, el kit deja de ser portable.

## Modelo obligatorio

```
[Jugar solo]     no llames host(); OfflineMultiplayerPeer; local_slot() == host_slot
[Host LAN]       MpKit.host()
[Dedicated]      MpKit.host_dedicated()     local_slot() == 0
[Cliente]        MpKit.join(ip)
```

- **Slot** estable: key de vidas/score/HUD. Listen: slot 1 = jugador host. Dedicated: slots 1..N = solo clientes.
- **Peer id** volátil: validar RPCs con `MpKit.peer_id_for(slot)`. Nunca `get_unique_id()` como id de jugador. Peer 1 en dedicated **no** es un slot.

Cliente: `apply_snapshot` **apaga** el tick de simulación de la sesión. El guest no tiquea el reloj. Dedicated sí simula (es el servidor).

## Input y autoridad

Actores: el servidor es authority. Si el body es `RigidBody2D`/`RigidBody3D`, los proxies se freezan (`MpAuthority.freeze_rigid_proxy`). No asumas RigidBody en todo pawn.

```
if MpAuthority.should_send_command():
    pawn.submit_x.rpc_id(1, payload)
else:
    pawn.apply_x(payload)
```

RPC en **tu** pawn, no en el kit:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_x(payload) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_x(payload)
```

- Allowlist de `submit_*`. No `rpc add_score`.
- No `call_local` en comandos de cliente (duplica spawn/daño).
- Áreas de daño: `monitoring = is_multiplayer_authority()`.
- Dedicated nunca manda `submit_*` (no hay jugador local).

## Handshake de spawn (obligatorio)

El `MultiplayerSpawner` de Godot replica hijos en `peer_connected`, cuando el cliente **sigue en el lobby**; ese spawn se pierde. `MpSpawner` (default `hold_until_world_ready`) usa la visibilidad por peer del `MultiplayerSynchronizer`: los actores nacen ocultos y cada peer se revela en `client_world_ready`; recién ahí Godot manda spawn + sync emparejados.

```
Server broadcast_load_world() + glue carga el mundo en el proceso servidor
  → listen host add_child(pawn local) en _ready; nace oculto para peers no listos
  → cliente carga escena; MpSpawner pide request_world_ready() (deferred)
  → MpSpawner revela al peer (set_visibility_for) → Godot manda spawn + sync
  → MpSlotSpawner (o glue) spawnea el slot que acaba de entrar
```

No desparentes actors en glue: el kit ya revela al `client_world_ready`.

Identidad del actor (`player_slot`, etc.): propiedades del `MultiplayerSynchronizer` con `spawn = true`, o el nombre (`Pawn_2` / `Ship_2`).

FX locales (post-process, atmósfera) se arman en `_ready` **también en el cliente**, antes del `return` del guest.

Rejoin: no resetear score; snapshot + `load_world_to`. `MpSpawner` revela de nuevo al nuevo peer id.

## Snapshots vs transforms

- Posición/rotación/visible: `MultiplayerSynchronizer` (`MpAuthority.ensure_sync`).
- Timer/score/vidas: `to_snapshot()` a 2–10 Hz vía `MpKit.push_snapshot` (Timer, no cada frame de `_process`).
- Eventos discretos (`+N` flotante): RPC `authority` en un nodo **vuestro**, no en MpKit.

No metas 40 posiciones de props en el dict si ya van por synchronizer.

## 1P

Mismo código de colisión y `submit_*` (el host local no manda RPC). Probar siempre jugar solo **sin** `create_server`.

## Anti-patrones

- Cliente spawnea / `queue_free` / suma puntos.
- `PlayerId` o `GameSession` importados desde `mp_kit.gd`.
- Arrancar spawn en el mismo frame que `change_scene` del invitado (el kit lo cubre; no lo “arregles” unparenteando en glue).
- `leave()` dejando `multiplayer_peer = null` (el kit pone `OfflineMultiplayerPeer`).
- Tercer peer aceptado en silencio (el kit debe `disconnect_peer` al exceder cupo; la política de “sala llena” es glue + kit).
- HUD que muestra el score del host porque usó peer id 1.
- Dedicated con pawn para sí, o desarrollar online como listen-server.
- Fingir que `host()` LAN detrás de NAT es online.
- Auto-broadcast del túnel custom (el servidor debe elegir).
- Meter reglas de juego o `kind` de bala en el dict del túnel.

## Checklist

- [ ] Tipo de MP declarado (ninguno / local-WiFi / online). Sin MP: este checklist no aplica.
- [ ] Autoload `MpKit` **antes** del glue. `configure(port, max_players)` antes de host/join.
- [ ] `MpFlow` autoload (Tools → New session flow) o `extends MpFlow`. Varios mapas: `add_world` + `select_world`. Glue extra solo si hay copy o túnel.
- [ ] Online: `MpBoot` + `host_dedicated()`; clientes `join`; export dedicated; spawn solo `occupied_slots()`. Hub opcional: `MpKit.rooms` / `MpKit.matchmaker` en el mismo proceso; el puntaje sigue fuera del addon.
- [ ] Slots en dominio; peers solo en RPC/authority.
- [ ] `MpSpawner` o `MpSlotSpawner` con `hold_until_world_ready` (default). El cliente no necesita `MpWorldReady`. No restage de pawns en glue.
- [ ] Guest no simula reglas; servidor valida sender.
- [ ] 1P offline verificado.
- [ ] Pawns son packed scenes componibles, no lógica de red incrustada en el kit.
- [ ] Features nuevas: Tools scaffold o `/new-mp-feature`; túnel solo para lo que no es `submit_*` / Resource.
