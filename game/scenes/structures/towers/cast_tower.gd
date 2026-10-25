@tool
class_name CastTower
extends MapBuilding

## A tower a wizard casts over a free manafount (Manalith or Shrine). While it stands it keeps the fount taken, its ManaSource
## feeds mana to its side and the allies, and guardians can tie to its GuardPost. When its health runs out the server frees it
## and the fount is free again on every peer. Its look, health, regeneration and mana rate are the nodes of its scene.
## Does not decide who may build one (StructureAction) nor how it reaches the other peers (StructureSpawner).

## Every tower in play, whoever's it is.
const TOWER_GROUP := &"cast_tower"

@export_group("Tower parts")
@export var mana_source: ManaSource
@export var guard_post: GuardPost
@export_group("")

## The fount this tower stands on: it keeps it taken while the tower stands. The spawner sets it before the tower enters the
## tree; a tower placed by hand in a map points to its fount here. Empty: the tower stands on no fount.
@export var fount: ManafountBody
## Layers that count as ground when the dead are moved out of the footprint (clear_footprint).
@export_flags_3d_physics var ground_mask := 1


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if mana_source == null:
		warnings.append("Asigná en `mana_source` el ManaSource de la torre.")
	if guard_post == null:
		warnings.append("Asigná en `guard_post` el GuardPost de la torre.")
	return warnings


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group(TOWER_GROUP)
	mana_source.owner_slot = owner_slot
	health.died.connect(_on_died)
	if fount != null:
		fount.occupy(get_path())


func _exit_tree() -> void:
	if fount != null and is_instance_valid(fount):
		fount.release(get_path())


## Metres a tower of this scene takes on the ground (half the wider side of its box): the room a cast needs.
func footprint_m() -> float:
	var box := collision.shape as BoxShape3D
	return maxf(1.0, maxf(box.size.x, box.size.z) * 0.5) if box != null else 1.0


## Moves the dead out of the ground the tower just took: every corpse (its soul rides on it) and every loose soul within the
## footprint plus TowerRules.MARGIN_M goes straight out from the tower's middle to that ring, on the ground. A doctor or a
## collector could never reach them inside the box. The spawner calls it once, on the side that runs the game.
func clear_footprint() -> void:
	var reach := footprint_m() + TowerRules.MARGIN_M
	var exclude: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group(Corpse.GROUP):
		_push_out(node as Node3D, reach, exclude)
	for node in get_tree().get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if soul != null and not soul.attached and soul.carrier == null \
				and soul.state in [Soul.State.NORMAL, Soul.State.EMERGING]:
			_push_out(soul, reach, exclude)


func _push_out(body: Node3D, reach: float, exclude: Array[RID]) -> void:
	if body == null or not is_instance_valid(body):
		return
	var flat := Vector3(body.global_position.x - global_position.x, 0.0, body.global_position.z - global_position.z)
	if flat.length() >= reach:
		return
	var out := flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	var to := global_position + out * reach
	to.y = GroundRay.surface_y(self, to, ground_mask, exclude, body.global_position.y)
	body.global_position = to


## Only the side that applies damage hears `died`: the others lose the tower when the spawner despawns it.
func _on_died(_from_slot: int) -> void:
	queue_free()
