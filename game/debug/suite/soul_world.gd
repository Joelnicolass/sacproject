extends RefCounted

## RFC-061d: the little world the soul cases play in: a floor, the match's SoulSystem, a SpellSpawner with its container, and the
## factories for wizards, creatures and souls. No network: everything runs as solo. `build(host)` adds it under `host`; `clear()` removes it.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const RULES := preload("res://data/match_rules.tres")
## Frames a scenario may take before it counts as stuck.
const GUARD_FRAMES := 1500

var host: Node3D
var root: Node3D
var souls: SoulSystem
## Where SpellSpawner puts what it spawns.
var spells: Node3D


func build(for_host: Node3D, name: String) -> void:
	host = for_host
	root = Node3D.new()
	root.name = name
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200.0, 2.0, 1200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	souls = SOUL_SYSTEM_SCENE.instantiate() as SoulSystem
	root.add_child(souls)
	spells = Node3D.new()
	spells.name = "Spells"
	root.add_child(spells)
	var spawner := SpellSpawner.new()
	spawner.name = "SpellSpawner"
	spawner.spawn_path = NodePath("../Spells")
	root.add_child(spawner)
	host.add_child(root)
	SideRelations.set_rows(_rows(), 3)


func clear() -> void:
	SideRelations.refresh()
	root.queue_free()


## Seat 1 and 2 are allies; seat 3 is the enemy of both.
func _rows() -> Array:
	return [
		{"id": 0, "allies": 0b011, "enemies": 0b100, "assignment": 1},
		{"id": 1, "allies": 0b011, "enemies": 0b100, "assignment": 2},
		{"id": 2, "allies": 0b100, "enemies": 0b011, "assignment": 3},
	]


## A wizard of `god` with full mana, ready to cast.
func wizard(slot: int, at: Vector3, god: String, level := 5) -> WizardBody:
	var body := WIZARD_SCENE.instantiate() as WizardBody
	body.owner_slot = slot
	body.god = god
	body.level = level
	body.position = at
	root.add_child(body)
	body.god = god
	(body.get_node("Health") as Health).setup(10000.0)
	var pool := body.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0
	return body


func unit(at: Vector3, slot: int, health := 5000.0) -> UnitBody:
	var type := GameData.creature("nmuh")
	var body := UNIT_SCENE.instantiate() as UnitBody
	body.owner_slot = slot
	body.type = GameData.creature("nmuh")
	body.model = str(type.model) if type else ""
	body.rules = RULES
	body.idle_aggro = false
	body.target_groups = PackedStringArray()
	body.position = at
	root.add_child(body)
	(body.get_node("Health") as Health).setup(health)
	return body


## A free soul (nobody's), already grown.
func free_soul(at: Vector3) -> Soul:
	return souls.spawn_soul({"x": at.x, "y": at.y, "z": at.z, "number": 1, "owner_slot": 0, "emerging": false}) as Soul


## A creature of `slot` that dies where it stands; returns it once its soul waits on the corpse.
func corpse_with_soul(at: Vector3, slot: int) -> UnitBody:
	var body := unit(at, slot)
	await frames(3)
	(body.get_node("Health") as Health).damage(99999.0, 3)
	await until(func() -> bool: return soul_of(body) != null, GUARD_FRAMES)
	return body


func soul_of(body: Node) -> Soul:
	for node in host.get_tree().get_nodes_in_group("soul"):
		var soul := node as Soul
		if soul != null and is_instance_valid(soul) and not soul.is_queued_for_deletion() and soul.corpse == body:
			return soul
	return null


## The carrier the SpellSpawner made (the first one), or null.
func carrier() -> SpellCarrier:
	for child in spells.get_children():
		if child is SpellCarrier and not child.is_queued_for_deletion():
			return child as SpellCarrier
	return null


func stunned(body: Node) -> bool:
	var state := body.get_node_or_null("Afflictions/Stunned") as Stunned
	return state != null and state.is_on()


func frames(count: int) -> void:
	for _i in count:
		await host.get_tree().physics_frame


## Frames until `condition` is true (-1 if it never is within `limit`).
func until(condition: Callable, limit: int) -> int:
	for frame in limit:
		if condition.call():
			return frame
		await host.get_tree().physics_frame
	return 0 if condition.call() else -1


func verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("soul_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
