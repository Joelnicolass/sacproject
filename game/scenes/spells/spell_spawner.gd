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
	"Dragonfire": preload("res://scenes/spells/carrier/dragonfire.tscn"),
	"RiftSpirit": preload("res://scenes/spells/zones/rift_spirit.tscn"),
	"SoulMole": preload("res://scenes/spells/carrier/soul_mole.tscn"),
	"SoulWind": preload("res://scenes/spells/carrier/soul_wind.tscn"),
	"AnimateDead": preload("res://scenes/spells/animate_dead/animate_dead_fx.tscn"),
	"Vaporization": preload("res://scenes/spells/carrier/vaporization.tscn"),
	"Charm": preload("res://scenes/spells/carrier/charm.tscn"),
	"BlindRage": preload("res://scenes/spells/carrier/blind_rage.tscn"),
	"BovineIntervention": preload("res://scenes/spells/carrier/bovine_intervention.tscn"),
	"Death": preload("res://scenes/spells/carrier/death.tscn"),
	"RainFrog": preload("res://scenes/spells/drops/rain_frog.tscn"),
	"FireDrop": preload("res://scenes/spells/drops/fire_drop.tscn"),
	"PlagueDrop": preload("res://scenes/spells/drops/plague_drop.tscn"),
	"Meteor": preload("res://scenes/spells/drops/meteor.tscn"),
	"LavaBall": preload("res://scenes/spells/drops/lava_ball.tscn"),
}
## Zone scenes by kind (Explosion, FrozenGround, DemonicRift, RainOfFrogs, RainOfFire, Plague, Cloudkill, Bombardment), assigned in match.tscn and not preloaded here: a zone points at its SpellType,
## the SpellType at its action, and the action's script knows this class, so a preload would close the circle. Root extends GroundZone.
@export var zones: Dictionary[String, PackedScene] = {}

var _serial := 0


## The spawner of spell projectiles in the world, or null.
static func of(tree: SceneTree) -> SpellSpawner:
	return tree.get_first_node_in_group(GROUP) as SpellSpawner


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _make
	super._ready()


## `kind` is a key of `projectiles`; `data` = the projectile's setup() keys without `name`. Returns the projectile on the server
## and in solo (a spell that must arm or cancel it keeps it), null on a client.
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
	if not projectiles.has(kind) and not zones.has(kind):
		push_error("SpellSpawner: no projectile scene for kind «%s», using %s" % [kind, DEFAULT_KIND])
		kind = DEFAULT_KIND
	var effect := (projectiles[kind] if projectiles.has(kind) else zones[kind]).instantiate() as SpellProjectile
	effect.setup(info)
	return effect
