# MpKit — API del addon

Archivos (`res://addons/mp_kit/`):

| Archivo | Rol |
|---------|-----|
| `mp_kit.gd` | Autoload. ENet + RPCs de sesión + signals. Hijos `Rooms` / `Matchmaker`. **Sin** `class_name` (el autoload ya se llama `MpKit`). |
| `mp_ids.gd` | `class_name MpIds` — slot ↔ peer; rejoin reusa slot |
| `mp_room_directory.gd` | `class_name MpRoomDirectory` — hub rooms (opt-in); asiento de sala ≠ slot del hub |
| `mp_matchmaker.gd` | `class_name MpMatchmaker` — cola FIFO; arma un `create_room` al llenar `party_size` |
| `mp_boot.gd` | `class_name MpBoot` — `dedicated_server` / `--dedicated` |
| `mp_lan.gd` | `class_name MpLan` — IPv4 + `advertise` / `browse` |
| `mp_lan_beacon.gd` | `class_name MpLanBeacon` — UDP `MPKIT1` |
| `mp_authority.gd` | `class_name MpAuthority` — authority, freeze 2D/3D, synchronizer, `accept_room_command` |
| `mp_custom_pipe.gd` | `class_name MpCustomPipe` — un canal del túnel |
| `mp_replicate.gd` | `class_name MpReplicate` — authority / sync / freeze / lerp opcional |
| `mp_spawner.gd` | `class_name MpSpawner` — MultiplayerSpawner que espera `world_ready` |
| `mp_slot_spawner.gd` | `class_name MpSlotSpawner` — un pawn packed por slot ocupado |
| `mp_boot_menu.gd` | `class_name MpBootMenu` — lobby drop-in (`mp_boot_menu.tscn`) |
| `mp_flow.gd` | `class_name MpFlow` — flow opcional (escenas, host/join/1P, catálogo de mundos) |
| `mp_world_ref.gd` | `class_name MpWorldRef` — un mundo del catálogo (`id` + escena) |
| `mp_world_ready.gd` | `class_name MpWorldReady` — legado; no hace falta si hay `MpSpawner` |
| `plugin.cfg` | Editor: Tools, scaffold, snippets, autoload al Enable. |

Estos archivos **no** nombran `GameSession`, `SceneDirector`, copy, `PlayerId` ni `submit_action`.

## Install

Copiá `addons/mp_kit/` a `res://addons/mp_kit/` del proyecto. Autoload, **antes** del glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

`MpKit.configure(port, max_players, host_slot, custom_channels)` antes de `host()` / `host_dedicated()` / `join()`. `custom_channels` vacío = todos los canales del túnel.

## Signals (el juego escucha)

- `peer_joined(peer_id, slot)` — aceptado y sloteado
- `peer_left(peer_id, slot)` — mapping limpio; el slot queda reservado para rejoin
- `join_failed` — el cliente no llegó
- `server_lost` — servidor caído; el kit ya hizo `leave()`
- `client_world_ready(peer_id)` — el cliente registró spawners
- `load_world` — hay que abrir la escena de match (el proceso servidor no recibe este RPC)
- `snapshot_received(data)` — `Dictionary` vuestro
- `session_ended(data)` — `Dictionary` vuestro
- `slot_assigned(slot)` — este cliente aprendió su slot
- `custom_received(channel, data, from_peer)` — túnel opaco (from_peer `1` si lo empujó el servidor)

## RPCs del kit (lista cerrada)

Cliente → servidor: `rpc_world_ready`, `rpc_custom_to_server`  
Servidor → clientes: `rpc_assign_slot`, `rpc_load_world`, `rpc_snapshot`, `rpc_session_ended`, `rpc_custom_from_server`  
`MpRoomDirectory`: `rpc_assign_room` (authority → ese peer; `room_id` va como `String`)

Input de pawn y semántica del dict custom **fuera** del kit.

## Métodos útiles

- `host(dedicated=false) -> Error` / `host_dedicated() -> Error` / `join(address) -> Error` / `leave()`
- `rooms` / `matchmaker` — hijos `Rooms` y `Matchmaker`. `leave()` los **resetea** (cierra salas, vacía la cola), no los `queue_free`.
- `is_networked()` / `is_server()` / `is_dedicated()` / `is_listen_host()`
- `local_slot()` — `0` en dedicated (no hay jugador local). **No** es el asiento de una hub room.
- `occupied_slots()` / `peer_id_for(slot)` / `slot_for_peer(peer_id)`
- `request_world_ready()`
- `broadcast_load_world()` / `load_world_to(peer)`
- `push_snapshot(data)` / `push_snapshot_to(peer, data)`
- `broadcast_session_ended(data)`
- `is_peer_world_ready(peer_id)`
- `send_custom(channel, data)` / `broadcast_custom` / `push_custom_to` / `is_custom_channel_allowed`

Editor: [editor.md](editor.md).

`rpc_load_world` es `call_remote`: el **servidor no lo recibe**. Entra al mundo por glue (listen host y dedicated).

## MpBoot

```gdscript
MpBoot.is_dedicated_process()   # dedicated_server / dedicated feature, or --dedicated in cmdline or user args
MpBoot.user_flag("dedicated")
MpBoot.user_value("mp-port", "7777")
```

No trates `--headless` solo como dedicated.

## MpAuthority

```gdscript
MpAuthority.claim_server(node)           # authority = peer 1
MpAuthority.ensure_sync(node, PackedStringArray([".:position", ".:rotation"]))
MpAuthority.freeze_rigid_proxy(body)     # RigidBody2D/3D; no-op si sos authority
MpAuthority.should_send_command()        # networked y no server
MpAuthority.accept_command(self, player_slot)  # en submit_*: server + sender == peer del slot
MpAuthority.accept_room_command(self, room_id, seat)  # server + sender == peer_for_seat
```

`accept_command` no cambia: sigue validando el **slot del hub**. `accept_room_command` valida el **asiento de esa room**.

| Método | Condición |
|--------|-----------|
| `accept_command(node, player_slot)` | Servidor y `get_remote_sender_id() == MpKit.peer_id_for(player_slot)` |
| `accept_room_command(node, room_id, seat)` | Servidor y `get_remote_sender_id() == MpKit.rooms.peer_for_seat(room_id, seat)` |

## MpRoomDirectory

Hijo `Rooms` del autoload (`MpKit.rooms`). Mutadores **solo servidor** (cliente: no-op, `FAILED`, id vacío). Las salas vacías cuentan en `max_rooms` hasta `close_room`.

`@export`: `max_rooms` (16), `seats_per_room` (2), `code_length` (4). Alfabeto de código: `A-Z0-9` sin `0O1I`.

Identidad: ENet `peer_id` = RPC; hub **slot** (`MpIds` / `local_slot()`) = conexión al proceso; room **id** (`StringName`, p.ej. `r_1`); room **seat** = `0..seats-1` en esa sala.

| Método | Qué hace |
|--------|----------|
| `create_room(seats=-1) -> StringName` | Sala vacía. `-1` → `seats_per_room`. Id vacío si hay tope. Genera código único. **No** sienta a nadie. |
| `join_room(peer_id, room_id) -> Error` | Próximo asiento libre; RPC `room_assigned` a ese peer. Si ya está en otra sala: `leave_room` y sienta. Misma sala: `OK` idempotente. |
| `join_room_by_code(peer_id, code) -> Error` | Normaliza a mayúsculas. |
| `leave_room(peer_id)` | Libera el asiento. No cierra la sala. |
| `close_room(room_id)` | Saca a todos y borra la sala. |
| `reset()` | Limpia mapas **sin** RPC (lo llama `MpKit.leave()`). |
| `room_id_for_peer` / `seat_for_peer` | Sala / asiento (`-1` si no está sentado). |
| `peer_for_seat(room_id, seat)` | Peer en ese asiento (`0` si vacío). |
| `peers_in_room` / `code_for_room` / `is_room_full` / `room_count` | Consultas. |
| `push_snapshot_to_room` / `push_custom_to_room` | `MpKit.push_snapshot_to` / `push_custom_to` **por miembro**. Nunca `push_snapshot` a todo el hub. |

Signals (servidor): `room_created(room_id, code)`, `peer_seated(room_id, peer_id, seat)`, `room_ready(room_id)` (todos los asientos llenos), `peer_unseated(...)`, `room_closed(room_id)`.

Cliente: `room_assigned(room_id, seat)` desde `rpc_assign_room`.

`MpKit.peer_left` → `leave_room`. Sin reglas de forfeit.

## MpMatchmaker

Hijo `Matchmaker` (`MpKit.matchmaker`). **Sin** RPCs. Usa `MpKit.rooms`, no paths. `@export party_size = 2`.

| Método | Qué hace |
|--------|----------|
| `enqueue(peer_id)` | Ignora si ya está en cola **o** ya sentado. |
| `dequeue(peer_id)` | Idempotente. |
| `queued_count()` / `is_queued(peer_id)` | Consultas. |
| `reset()` | Vacía la cola (`MpKit.leave()`). |

Cuando `queued_count() >= party_size`: FIFO toma `party_size`, `create_room(party_size)`, `join_room` cada uno, emite `match_assembled(room_id, peer_ids: PackedInt32Array)`. Instantáneo (sin Accept). Si `create_room` falla: los deja en cola y no emite.

`MpKit.peer_left` → `dequeue`. Sin tema, nick ni `change_scene`.

## MpSpawner

Extiende `MultiplayerSpawner` nativo. Usa el mecanismo de **visibilidad por peer** del `MultiplayerSynchronizer`: Godot no manda el spawn a un peer hasta que el synchronizer del actor sea visible para él, y al revelarlo manda spawn + sync emparejados.

Default `hold_until_world_ready = true` (solo actúa en el servidor):

1. Cada actor que entra bajo `spawn_path` nace oculto (`public_visibility = false` en sus synchronizers).
2. En `client_world_ready`, `set_visibility_for(peer, true)` → Godot entrega spawn + sync a ese peer.
3. `peer_left` → visibilidad off para ese peer (limpio para rejoin).

- Inspector: `spawn_path` = padre de los actores (queda intacto; el cliente lo necesita para instanciar). `extra_scenes` = packed scenes.
- Glue: `add_child(node, true)` bajo ese padre, cuando quieras. Identidad (`player_slot`, etc.) va en el `MultiplayerSynchronizer` con `spawn = true`, no en un RPC.
- `hold_until_world_ready = false` solo si todos los peers ya tienen esta escena.
- Cliente: este mismo nodo hace `request_world_ready()` deferred. Un `MpSpawner` basta.

## MpSlotSpawner

Extiende `MpSpawner`. `@export pawn_scene`, `spawn_points`, `actor_name_prefix` (`Pawn_`). Listen host spawnea el slot local en `_ready`. Joiners en `client_world_ready`. Dedicated no spawnea slot 0. Identidad: nombre `Pawn_<n>` y `player_slot` si el actor lo exporta.

## MpWorldReady

Opcional / legado. Si la escena ya tiene un `MpSpawner`, este nodo no-op. Escenas viejas pueden dejarlo.

## MpReplicate

Hijo del actor. Inspector: `interpolate` (default on) + `interpolate_speed`. Solo proxies; la authority no interpola.

## MpBootMenu

Escena `res://addons/mp_kit/mp_boot_menu.tscn`. Copy por `@export`. Si hay un autoload `MpFlow`, lo usa. Si no: `world_scene` asignado = loop sin glue (host hace `broadcast_load_world` + late join). Vacío = solo UI; tu glue escucha las signals.

## MpFlow

Autoload **después** de `MpKit` (Tools → **New session flow...**, o `extends MpFlow`). No es puntaje ni reglas: boot/world, `play_solo` / `host_lan` / `join_lan` / `return_to_boot`, advertise LAN, late join, dedicated al primer cliente.

Un mundo:

```gdscript
extends MpFlow

func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	world_path = "res://scenes/world/match.tscn"
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()
```

Varios mundos — catálogo `MpWorldRef` (inspector `worlds`, o `add_world`). El lobby llama `select_world(&"2d")`. El joiner recibe `world_id` en el snapshot. `--world=3d` (user arg) selecciona si el id existe.

```gdscript
func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	add_world(&"2d", "res://scenes/world/match_2d.tscn")
	add_world(&"3d", "res://scenes/world/match_3d.tscn")
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()

# lobby
MpFlow.select_world(&"3d")
```

`snapshot_for_joiner()` ya manda `world_id`. Override y `super.snapshot_for_joiner()` si necesitás más estado.

`MpFlow.find_in_tree(self)` localiza el autoload aunque no se llame `MpFlow` (la demo se llama `NetGlue`).

## MpLan

`MpLan.get_local_ipv4()` / `MpLan.is_valid_ipv4(ip)` para el lobby listen. Online: IP de la VPS (o `127.0.0.1` en dev), no la LAN del cliente.

```gdscript
MpLan.advertise(parent, "Sala")   # UDP; parentéalo a un nodo que sobreviva el change_scene (autoload)
MpLan.browse(parent)              # signal rooms_changed(rooms: Array) — **LAN browse**, no hub rooms
```

## MpIds (contrato)

- Listen: slot `host_slot` (1) = jugador host = ENet peer 1. Clientes: `host_slot+1..max_players`.
- Dedicated: peer 1 sin slot. Clientes: `host_slot..max_players`.
- `unbind_peer` deja el slot en `0` (libre para rebind), no borra el cupo.
- `assign_client` reusa slot si el peer ya estaba, o rebind de slot vacío.
- `occupied_slots()` = slots con peer ≠ 0.

## Fallos que el kit ya cubre

| Fallo típico | Mitigación |
|--------------|------------|
| 1P abre puerto | `is_networked()` false hasta `host()`/`join()` |
| HUD usa unique_id | `local_slot()` (0 = dedicated) |
| Spawn antes de escena cliente | `MpSpawner.hold_until_world_ready` + `request_world_ready` |
| RigidBody cliente pelea con sync | `freeze_rigid_proxy` |
| `leave()` con peer null | `OfflineMultiplayerPeer` |
| Host se cae | `server_lost` |
| IP basura | `join_failed` |
| Cupo | `create_server` max_clients + `disconnect_peer` |
