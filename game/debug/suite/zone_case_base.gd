extends RefCounted

## What the 061f case files share (zone_cases, rift_cases, aura_cases): a flat floor, a SpellSpawner with its Spells node, three sides (seats 1
## and 2 allied, seat 3 the enemy of both), and the makers of bodies and zones. `begin(host)` builds the world and `finish()` takes it away.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RULES := preload("res://data/match_rules.tres")
const TOLERANCE := 0.01
## The match seed of the cases: what a spell draws (the points of an Explosion, the targets of a rift) is the same on every run.
const SEED := 4242
## 061h: the clouds, by the kind their zone has in SpellSpawner.zones.
const CLOUDS := {"RainOfFrogs": "rain_of_frogs", "RainOfFire": "rain_of_fire", "Plague": "plague", "Cloudkill": "cloudkill", "Bombardment": "bombardment"}

var _host: Node3D
var _root: Node3D
var _spawner: SpellSpawner
var _saved_seed := 0


func begin(host: Node3D, world_name: String) -> void:
	_host = host
	_root = Node3D.new()
	_root.name = world_name
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200.0, 2.0, 1200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	var spells := Node3D.new()
	spells.name = "Spells"
	_root.add_child(spells)
	_spawner = SpellSpawner.new()
	_spawner.name = "SpellSpawner"
	_spawner.spawn_path = NodePath("../Spells")
	_spawner.zones["Explosion"] = load("res://scenes/spells/zones/explosion_zone.tscn") as PackedScene
	_spawner.zones["FrozenGround"] = load("res://scenes/spells/zones/frozen_ground.tscn") as PackedScene
	_spawner.zones["DemonicRift"] = load("res://scenes/spells/zones/demonic_rift.tscn") as PackedScene
	_spawner.zones["Erupt"] = load("res://scenes/spells/zones/erupt_zone.tscn") as PackedScene
	_spawner.zones["Bore"] = load("res://scenes/spells/zones/bore_zone.tscn") as PackedScene
	for kind in CLOUDS:
		_spawner.zones[kind] = load("res://scenes/spells/zones/%s.tscn" % CLOUDS[kind]) as PackedScene
	_spawner.zones["Meanstalks"] = load("res://scenes/spells/stalks/meanstalks.tscn") as PackedScene
	_spawner.zones["Tornado"] = load("res://scenes/spells/tornado/tornado.tscn") as PackedScene
	_root.add_child(_spawner)
	## Where a Cloudkill's bolts are born (LightningStrike.launch looks for the group and its spawn_path).
	var shots := Node3D.new()
	shots.name = "Shots"
	_root.add_child(shots)
	var shot_spawner := MultiplayerSpawner.new()
	shot_spawner.name = "ShotSpawner"
	shot_spawner.spawn_path = NodePath("../Shots")
	shot_spawner.add_to_group(&"shot_spawner")
	_root.add_child(shot_spawner)
	_host.add_child(_root)
	SideRelations.set_rows(_rows(), 3)
	_saved_seed = MatchSeed.current
	MatchSeed.current = SEED


func finish() -> void:
	MatchSeed.current = _saved_seed
	SideRelations.refresh()
	_root.queue_free()


## A zone made through the spawner, as the action does, at `points`. `arm` is the ticks it waits once released.
func _zone(kind: String, points: PackedVector3Array, wizard: Node3D, cast_ticks: int, arm: int, aim := Vector3.INF) -> GroundZone:
	var data := {
		"x": points[0].x, "y": points[0].y, "z": points[0].z, "points": points, "aim": points[0] if aim == Vector3.INF else aim,
		"slot": wizard.get("owner_slot"), "caster": str(wizard.get_path()), "cast_ticks": cast_ticks, "arm_ticks": arm,
	}
	return _spawner.spawn_projectile(kind, data) as GroundZone


func _zones() -> Array[GroundZone]:
	var found: Array[GroundZone] = []
	for node in _host.get_tree().get_nodes_in_group(GroundZone.GROUP):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			found.append(node as GroundZone)
	return found


func _wizard(slot: int, at: Vector3, god: String, level := 1) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god = god
	wizard.level = level
	wizard.position = at
	_root.add_child(wizard)
	wizard.god = god
	(wizard.get_node("Health") as Health).setup(10000.0)
	return wizard


func _unit(tag: String, at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.creature_tag = tag
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.position = at
	_root.add_child(unit)
	return unit


## A creature that takes spell damage (a Druid: the Trogg is immune to it) with health to spare, so a hit never kills it.
func _tough(at: Vector3, slot: int) -> UnitBody:
	var unit := _unit("nmuh", at, slot)
	(unit.get_node("Health") as Health).setup(5000.0)
	return unit


## The creature stops regenerating (its type is a copy with no regeneration), so a heal is the only thing that moves its health.
func _still(unit: UnitBody) -> UnitBody:
	unit.type = unit.type.duplicate()
	unit.type.regeneration_per_s = 0.0
	return unit


func _rows() -> Array:
	return [
		{"id": 0, "allies": 0b011, "enemies": 0b100, "assignment": 1},
		{"id": 1, "allies": 0b011, "enemies": 0b100, "assignment": 2},
		{"id": 2, "allies": 0b100, "enemies": 0b011, "assignment": 3},
	]


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("zone_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	printerr("zone_cases: %s %s (tick %d)" % [name, "PASS" if ok else "FAIL", MatchClock.now()])
	return checks
