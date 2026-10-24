extends Node

## Debug of cast_zones.tscn: after the enemy targets are born, an own Troll stands near the wizard with half its health, so Healing Aura has
## someone to carry it and heal. The wizard fills his mana before every cast. It casts nothing and moves nobody.

@export var world: Node
@export var arena: Node3D
@export var unit_scene: PackedScene
## Metres to the wizard's right and ahead of him.
@export var troll_spot := Vector2(8.0, 12.0)
@export var after_frames := 30


func _ready() -> void:
	for _frame in after_frames:
		await get_tree().physics_frame
	var wizard := world.call("local_wizard") as WizardBody
	if wizard == null:
		return
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = pool.maximum
	var ahead := wizard.facing_flat()
	var troll := unit_scene.instantiate() as UnitBody
	troll.name = "OwnTroll"
	troll.creature_tag = "lort"
	troll.owner_slot = wizard.owner_slot
	troll.idle_aggro = false
	arena.add_child(troll)
	troll.global_position = wizard.global_position + ahead.cross(Vector3.UP) * troll_spot.x + ahead * troll_spot.y
	var health := troll.get_node("Health") as Health
	health.current = health.maximum * 0.5
	print("zones_setup: own Troll at (%.1f, %.1f, %.1f) with half its health" % [troll.global_position.x, troll.global_position.y, troll.global_position.z])
