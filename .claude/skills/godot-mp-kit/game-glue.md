# Glue del juego (lo que vos escribís)

Para un título de un mundo, **no hace falta un `NetGlue`**. Tools → **MpKit: New session flow...** crea un autoload `extends MpFlow`. El lobby es `MpBootMenu` o botones que llaman `play_solo` / `host_lan` / `join_lan`.

Escribí glue propio solo si:

1. Copy o un túnel (como la demo: emote) → `extends MpFlow` y override.
2. Clean: `GameSession` + `SceneDirector` encima de `MpFlow`, o sin él si el director ya cambia escenas.
3. La ronda espera N jugadores / un “listo” → `start_when` no alcanza; llamá `start_match()` vos.

Varios mapas no son glue: `add_world` / `worlds` + `select_world(&"id")`.

Orden de autoload: `MpKit` → `MpFlow` (o tu subclase) → resto.

Dedicated / VPS: [dedicated.md](dedicated.md).

## MpFlow (default)

```gdscript
extends MpFlow

func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	world_path = "res://scenes/world/match.tscn"
	room_name = "Mi sala"
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()
```

Varios mundos:

```gdscript
add_world(&"2d", "res://scenes/world/match_2d.tscn")
add_world(&"3d", "res://scenes/world/match_3d.tscn")
select_world(&"2d")
```

Jugar solo / host / join / volver al boot: métodos de `MpFlow`. Advertise LAN va en el autoload (sobrevive el `change_scene`). Browse en el menú: `MpLan.browse(self)`.

Atajo UI: `MpBootMenu`. Si detecta un `MpFlow` en el árbol, lo usa.

Online: campo IP (dev: `127.0.0.1`). `join_lan` ya valida IPv4.

## Política custom (N clientes, no MpFlow solo)

Listen: una política válida es arrancar al conectar el 2.º peer. Dedicated: el servidor empieza vacío; arrancá al N-ésimo cliente o con un “listo”. Entonces no uses `DEDICATED_FIRST_CLIENT`; llamá `MpFlow.start_match()` o cambiá escenas vos.

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	var slots := MpKit.occupied_slots()
	if MpKit.is_dedicated() and slots.size() < 2:
		return  # ejemplo: esperar 2 clientes
	game_session.start(slots)
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()  # el servidor no recibe rpc_load_world
```

## Flow

```gdscript
func _ready() -> void:
	game_session.finished.connect(_on_finished)
	MpKit.load_world.connect(goto_world)
	MpKit.snapshot_received.connect(game_session.apply_snapshot)
	MpKit.session_ended.connect(_on_remote_ended)
	MpKit.server_lost.connect(_on_server_lost)
```

Al terminar en servidor: `broadcast_session_ended` + ir a resultados.  
`apply_snapshot` en cliente: `set_process(false)` en la sesión.

## Mundo (`_ready`)

Preferí un `MpSlotSpawner` en la escena (`pawn_scene`, `spawn_path`, markers). Entonces el glue **no** llama `ensure_pawn` ni `request_world_ready`.

Spawn a mano (proyectiles, enemigos, o un pawn custom):

```gdscript
func _ready() -> void:
	# FX locales acá (también el cliente)

	if not MpKit.is_networked():
		_spawn_world()
		game_session.start([MpKit.local_slot()])
		return

	if not MpKit.is_server():
		# Solo si no hay MpSpawner en esta escena:
		# MpKit.request_world_ready()
		return

	# Listen host: pawn local en _ready. MpSpawner no lo manda hasta world_ready.
	if MpKit.is_listen_host():
		_ensure_pawn(MpKit.local_slot())
```

`add_child(node, true)` — nombre estable. Colocá posición/slot **antes** de `add_child`.

```gdscript
func _on_client_world_ready(peer_id: int) -> void:
	_ensure_pawn(MpKit.slot_for_peer(peer_id))
```

Dedicated: **no** spawnees un pawn para `local_slot() == 0`.

`MpSpawner` revela los actores al peer listo (visibilidad nativa del synchronizer). No hagas `remove_child` + `add_child` en glue.

## Desconexión (definí producto)

| Signal | El kit | Vos |
|--------|--------|-----|
| `peer_left` | Limpia mapping | ¿Seguir? ¿Pausar? ¿Marcar ausente? Dedicated con 0 clientes: ¿apagar ronda? |
| `server_lost` | Ya `leave()` | Notice + menú |
| `join_failed` | Nada más | Notice + menú |

Una política válida: guest drop no pausa el timer y deja el pawn ausente. Otro género puede pausar. No lo pongas en el kit.

## Pawns

Preferí un hijo `MpReplicate` (Tools → Wire replication, o el scaffold). Equivale a:

```gdscript
MpAuthority.claim_server(self)
MpAuthority.ensure_sync(self, PackedStringArray([".:position", ".:rotation", ".:visible"]))
MpAuthority.freeze_rigid_proxy(self)
```

Componer trail/FSM/FX como hijos. La red no justifica un pawn monolítico. Túnel manual: [editor.md](editor.md).

## Snapshot periódico

Nodo vuestro en el mundo, solo servidor, 2–10 Hz:

```gdscript
if MpKit.is_server() and game_session.is_running:
	MpKit.push_snapshot(game_session.to_snapshot())
```
