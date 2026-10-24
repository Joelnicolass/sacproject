extends Node

## RFC-061d check scene: souls to play the soul spells on. Ahead of the local wizard (`ahead_m` away, `side_m` to his right) it puts a
## free soul and the soul of a creature of his side that dies where it stands. Soul Mole and Soul Wind work on either; Animate Dead
## only on the creature's. Enemies to be stunned come from rock_hit.gd (the other node of cast_souls.tscn). Press `spell_N`, then click
## the soul. Not part of the product: the real match gets its souls from creatures that die.

@export var world: Node
@export var souls: SoulSystem
@export var creature_scene: PackedScene
@export var arena: Node3D
## The creature that dies (its soul waits on the corpse).
@export var dead_tag := "nmuh"
@export var free_soul_spot := Vector2(0.0, 25.0)
@export var dead_spot := Vector2(10.0, 30.0)
@export var settle_frames := 8

var _started := false


func _ready() -> void:
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.call("local_wizard"):
		_start.call_deferred()


func _start() -> void:
	var wizard := world.call("local_wizard") as Node3D
	if wizard == null or _started:
		return
	_started = true
	for _frame in settle_frames:
		await get_tree().physics_frame
	var ahead := wizard.call("facing_flat") as Vector3
	var right := ahead.cross(Vector3.UP)
	var free_at := wizard.global_position + right * free_soul_spot.x + ahead * free_soul_spot.y
	souls.spawn_soul({"x": free_at.x, "y": free_at.y, "z": free_at.z, "number": 1, "owner_slot": 0, "emerging": false})
	var creature := creature_scene.instantiate() as UnitBody
	creature.name = "Fallen"
	creature.creature_tag = dead_tag
	creature.owner_slot = int(wizard.get("owner_slot"))
	creature.target_groups = PackedStringArray()
	arena.add_child(creature)
	creature.global_position = wizard.global_position + right * dead_spot.x + ahead * dead_spot.y
	await get_tree().physics_frame
	(creature.get_node("Health") as Health).damage(99999.0, 0)
	print("almas: una libre a %d m y la de %s caido a %d m" % [roundi(free_soul_spot.y), dead_tag, roundi(dead_spot.y)])
