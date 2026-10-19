class_name SpellSpawner
extends MpSpawner

## Spawns spell projectiles under spawn_path: on the server (replicated) or in solo. The scene of each kind is in
## `projectiles` (RFC-041): a new projectile is a scene here, not a line of code.

const DEFAULT_KIND := "Rock"

## Projectile scene by kind. Its root extends SpellProjectile.
@export var projectiles: Dictionary[String, PackedScene] = {
	"Rock": preload("res://scenes/spells/rock_projectile.tscn"),
	"Wrath": preload("res://scenes/spells/wrath_strike.tscn"),
	"Fireball": preload("res://scenes/spells/fireball_projectile.tscn"),
	"Swarm": preload("res://scenes/spells/swarm_projectile.tscn"),
}

var _serial := 0


func _ready() -> void:
	add_to_group("spell_spawner")
	spawn_function = _make
	super._ready()


## `kind` is a key of `projectiles`; `data` = the projectile's setup() keys without `name`.
func spawn_projectile(kind: String, data: Dictionary) -> void:
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
	var kind := str(info.get("kind", DEFAULT_KIND))
	if not projectiles.has(kind):
		push_error("SpellSpawner: no projectile scene for kind «%s», using %s" % [kind, DEFAULT_KIND])
		kind = DEFAULT_KIND
	var effect := projectiles[kind].instantiate() as SpellProjectile
	effect.setup(info)
	return effect
