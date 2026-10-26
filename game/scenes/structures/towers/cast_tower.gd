@tool
class_name CastTower
extends MapBuilding

## A tower a wizard casts over a free manafount (Manalith or Shrine). While it stands it keeps the fount taken, its ManaSource
## feeds mana to its side and the allies, and guardians can tie to its GuardPost. When its health runs out the server frees it
## and the fount is free again on every peer. Its look, health, regeneration and mana rate are the nodes of its scene.
## It is born when the cast starts and rises while it lasts (`build_progress` 0 -> 1, replicated): rising, it cannot be hurt, gives no
## mana and does not stop bodies; the cast that is cut frees it; at 1 it stands (complete).
## Does not decide who may build one (StructureAction) nor how it reaches the other peers (StructureSpawner), nor draw the rise.
## Ref: sacengine makeBuilding(inactive | cannotDamage) at the cast start, destroy on interrupt, activate on finish (state.d:10072-10083,
## 15259-15274).

## `build_progress` changed (every peer): what draws the rise follows it.
signal build_progress_changed(progress: float)

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
## How far the tower has risen: the server sets it from 0 when the cast starts to 1 when it ends; the Sync replicates it. Below 1 the
## tower is rising (is_rising). A tower placed by hand in a map stands: 1.
@export_range(0.0, 1.0, 0.01) var build_progress := 1.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if value == build_progress:
			return
		build_progress = value
		if is_node_ready() and not Engine.is_editor_hint():
			_show_rising()
		build_progress_changed.emit(build_progress)

var _standing_layer := 1


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
	_standing_layer = collision_layer
	_show_rising()


func _exit_tree() -> void:
	if fount != null and is_instance_valid(fount):
		fount.release(get_path())


## Below 1 of `build_progress`: the cast that raises it is still going.
func is_rising() -> bool:
	return build_progress < 1.0


## A rising tower is no target: it takes no damage (Health asks this) and no one aims at it.
func is_targetable() -> bool:
	return not is_rising()


## Server or solo: the cast ended. The tower stands (build_progress 1) and the bodies still on its ground go out of it.
func complete() -> void:
	build_progress = 1.0
	clear_footprint()


## Metres a tower of this scene takes on the ground (half the wider side of its box): the room a cast needs.
func footprint_m() -> float:
	var box := collision.shape as BoxShape3D
	return maxf(1.0, maxf(box.size.x, box.size.z) * 0.5) if box != null else 1.0


## Moves out of the ground the tower just took everything within the footprint plus TowerRules.MARGIN_M: every corpse (its soul
## rides on it), every loose soul and every live creature, wizard and doctor, straight out from the tower's middle to that ring, on
## the ground (a flier keeps its height). A doctor or a collector could never reach the dead inside the box, and nobody stays caught in
## it. Idempotent; the side that runs the game calls it when the tower stands (complete, or the spawner for a tower born standing).
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
	var around := AABB(global_position - Vector3(reach, reach, reach), Vector3.ONE * reach * 2.0)
	for body in BodyNudge.bodies_in(get_tree(), around, BuildArea.PUSHED):
		_push_out(body, reach, exclude)


func _push_out(body: Node3D, reach: float, exclude: Array[RID]) -> void:
	if body == null or not is_instance_valid(body):
		return
	var flat := Vector3(body.global_position.x - global_position.x, 0.0, body.global_position.z - global_position.z)
	if flat.length() >= reach:
		return
	var out := flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	var to := global_position + out * reach
	to.y = body.global_position.y if BodyNudge.airborne(body) \
			else GroundRay.surface_y(self, to, ground_mask, exclude, body.global_position.y)
	body.global_position = to


## Rising: no body stops on it and its ManaSource gives nothing; standing: both as the scene says. The destroyed state
## (MapBuilding) comes after, never while rising (a rising tower takes no damage).
func _show_rising() -> void:
	var rising := is_rising()
	collision_layer = 0 if rising else _standing_layer
	mana_source.process_mode = Node.PROCESS_MODE_DISABLED if rising else Node.PROCESS_MODE_INHERIT


## Only the side that applies damage hears `died`: the others lose the tower when the spawner despawns it.
func _on_died(_from_slot: int) -> void:
	queue_free()
