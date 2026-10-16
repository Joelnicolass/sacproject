extends MpSpawner

## Spawns spell projectiles under spawn_path: on the server (replicated) or in solo.

const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")
const _WRATH := preload("res://scenes/world/spells/wrath_strike.gd")
const _FIREBALL := preload("res://scenes/world/spells/fireball_projectile.gd")
const _SWARM := preload("res://scenes/world/spells/swarm_projectile.gd")

var _serial := 0


func _ready() -> void:
	add_to_group("spell_spawner")
	spawn_function = _make
	super._ready()


## `data` = rock_projectile.setup() keys without `name`.
func spawn_rock(data: Dictionary) -> void:
	_spawn("Rock", data)


## `data` = wrath_strike.setup() keys without `name`.
func spawn_wrath(data: Dictionary) -> void:
	_spawn("Wrath", data)


## `data` = fireball_projectile.setup() keys without `name`.
func spawn_fireball(data: Dictionary) -> void:
	_spawn("Fireball", data)


## `data` = swarm_projectile.setup() keys without `name`.
func spawn_swarm(data: Dictionary) -> void:
	_spawn("Swarm", data)


func _spawn(kind: String, data: Dictionary) -> void:
	_serial += 1
	data["name"] = "%s%d" % [kind, _serial]
	data["kind"] = kind
	if MpKit.is_networked():
		if MpKit.is_server():
			spawn(data)
		return
	get_node(spawn_path).add_child(_make(data))


func _make(data: Variant) -> Node:
	var info: Dictionary = data
	var kind := str(info.get("kind", "Rock"))
	var effect: Node3D
	match kind:
		"Wrath":
			effect = _WRATH.new()
		"Fireball":
			effect = _FIREBALL.new()
		"Swarm":
			effect = _SWARM.new()
		_:
			effect = _ROCK.new()
	effect.call("setup", info)
	return effect
