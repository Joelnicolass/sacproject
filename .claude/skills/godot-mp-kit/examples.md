# Examples — MpKit (genéricos)

Nada de un título concreto. El kit no nombra estas clases.

## Session flow (`extends MpFlow`)

```gdscript
extends MpFlow

func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	add_world(&"2d", "res://scenes/world/match_2d.tscn")
	add_world(&"3d", "res://scenes/world/match_3d.tscn")
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()
```

## RPC de intención en el actor

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_action(dir: Vector2, strength: float) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_action(dir, strength)


func try_action(dir: Vector2, strength: float) -> void:
	if MpAuthority.should_send_command():
		submit_action.rpc_id(1, dir, strength)
	else:
		apply_action(dir, strength)
```

## Glue: listen (2.º peer) vs dedicated (N clientes)

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	var slots := MpKit.occupied_slots()
	if MpKit.is_dedicated() and slots.size() < 2:
		return
	game_session.start(slots)
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()
```

## Dedicated boot

```gdscript
if MpBoot.is_dedicated_process():
	MpKit.configure(int(MpBoot.user_value("mp-port", "7777")), 4)
	var err := MpKit.host_dedicated()
	if err != OK:
		get_tree().quit(1)
```

## Snapshot periódico (solo servidor, 2–10 Hz)

```gdscript
func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.timeout.connect(_push_if_server)
	add_child(timer)
	timer.start()


func _push_if_server() -> void:
	if not MpKit.is_server() or not game_session.is_running:
		return
	MpKit.push_snapshot(game_session.to_snapshot())
```

## Túnel Dictionary (no refleja solo)

```gdscript
# Cliente o 1P
MpKit.send_custom(&"emote", {"id": "wave"})
# Listen host / server origin (everyone must see it): broadcast_custom, not send_custom

# Servidor (glue): reflejá solo paquetes de cliente. from_peer == 1 ya es emit del server
# (broadcast o send local). Sin este check, broadcast_custom se llama a sí mismo.
func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != &"emote":
		return
	if MpKit.is_server() and from_peer != 1:
		MpKit.broadcast_custom(channel, data)
```

O un hijo `MpCustomPipe` con `channel` en el inspector.

## Identidad al spawnear (actor, no kit)

Pone `player_slot` (u otro id) en el `MultiplayerSynchronizer` con `spawn = true`, como el `player_id` de Asteroidcitos. Nombre estable (`Pawn_2`) como fallback.

```gdscript
MpAuthority.ensure_sync(self, PackedStringArray([
	".:position",
	".:rotation",
	".:visible",
	".:player_slot",
]))
```

`add_child` bajo el `spawn_path`. `MpSpawner` revela el actor al peer en `world_ready` (Godot manda spawn + sync). Un `MpSlotSpawner` hace el pawn por slot; no hace falta `ensure_pawn` en glue.
