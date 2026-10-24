class_name SpellSpawner
extends MpSpawner

## Spawns spell projectiles under spawn_path: on the server (replicated) or in solo. The scene of each kind is in
## `projectiles` (RFC-041): a new projectile is a scene here, not a line of code.

const DEFAULT_KIND := "Rock"
## The group the spawner joins, for whoever starts a spell that raises something (a zone).
const GROUP := &"spell_spawner"

## Projectile scene by kind. Its root extends SpellProjectile.
@export var projectiles: Dictionary[String, PackedScene] = {
	"Rock": preload("res://scenes/spells/rock_projectile.tscn"),
	"Wrath": preload("res://scenes/spells/wrath_strike.tscn"),
	"Fireball": preload("res://scenes/spells/fireball_projectile.tscn"),
	"Swarm": preload("res://scenes/spells/swarm_projectile.tscn"),
	"Explosion": preload("res://scenes/spells/zones/explosion_zone.tscn"),
	"FrozenGround": preload("res://scenes/spells/zones/frozen_ground.tscn"),
	"DemonicRift": preload("res://scenes/spells/zones/demonic_rift.tscn"),
	"RiftSpirit": preload("res://scenes/spells/zones/rift_spirit.tscn"),
}

var _serial := 0


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _make
	super._ready()


## `kind` is a key of `projectiles`; `data` = the projectile's setup() keys without `name`. Returns the node made here (the server's or the
## solo one), or null on a client; a zone's action keeps it to release or cancel it.
func spawn_projectile(kind: String, data: Dictionary) -> Node:
	_serial += 1
	data["name"] = "%s%d" % [kind, _serial]
	data["kind"] = kind
	if MpKit.is_networked():
		return spawn(data) if MpKit.is_server() else null
	var made := _make(data)
	get_node(spawn_path).add_child(made)
	return made


func _make(data: Variant) -> Node:
	var info: Dictionary = data
	var kind := str(info.get("kind", DEFAULT_KIND))
	if not projectiles.has(kind):
		push_error("SpellSpawner: no projectile scene for kind «%s», using %s" % [kind, DEFAULT_KIND])
		kind = DEFAULT_KIND
	var effect := projectiles[kind].instantiate() as SpellProjectile
	effect.setup(info)
	return effect
