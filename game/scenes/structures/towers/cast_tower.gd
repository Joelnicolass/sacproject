@tool
class_name CastTower
extends MapBuilding

## A tower a wizard casts over a free manafount (Manalith or Shrine). Standing, it keeps the fount taken, its ManaSource feeds its
## side and the allies, and guardians tie to its GuardPost. It is born when the cast starts and rises while it lasts (`build_progress`
## 0 -> 1, replicated): rising, it takes no damage, gives no mana and stops no body; a cut cast frees it; at 1 it stands. At 0 health
## it falls on every peer the same tick (fount free, out of the tower group, no mana, no target), stays `linger_s` so every peer sees
## it fall, and the server frees it. Does not decide who may build one (StructureAction), how it reaches the peers (StructureSpawner),
## nor draw the rise or the fall (BuildReveal, StructureBreak).

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
## Seconds a fallen tower stays before the server frees it (every peer gets the 0 of its health first).
@export_range(0.0, 10.0, 0.1, "suffix:s") var linger_s := 1.0
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
			_show_state()
		build_progress_changed.emit(build_progress)

var _standing_layer := 1
## MatchClock tick of the fall on the server; -1 while it stands.
var _fallen_at := -1


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if mana_source == null:
		warnings.append("Assign in `mana_source` the tower's ManaSource.")
	if guard_post == null:
		warnings.append("Assign in `guard_post` the tower's GuardPost.")
	return warnings


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group(TOWER_GROUP)
	mana_source.owner_slot = owner_slot
	destroyed.connect(_on_destroyed)
	set_physics_process(false)
	if fount != null:
		fount.occupy(get_path())
	_standing_layer = collision_layer
	_show_state()


func _exit_tree() -> void:
	if fount != null and is_instance_valid(fount):
		fount.release(get_path())


## Below 1 of `build_progress`: the cast that raises it is still going.
func is_rising() -> bool:
	return build_progress < 1.0


## A rising or fallen tower is no target: it takes no damage (Health asks this) and no one aims at it.
func is_targetable() -> bool:
	return not is_rising() and not is_destroyed()


## Server or solo: the cast ended. The tower stands (build_progress 1) and the bodies still on its ground go out of it.
func complete() -> void:
	build_progress = 1.0
	clear_footprint()


## Metres a tower of this scene takes on the ground (half the wider side of its box): the room a cast needs.
func footprint_m() -> float:
	var box := collision.shape as BoxShape3D
	return maxf(1.0, maxf(box.size.x, box.size.z) * 0.5) if box != null else 1.0


## Moves everything within the footprint plus TowerRules.MARGIN_M (every corpse with its soul, loose soul, creature, wizard and doctor)
## straight out from the tower's middle to that ring, on the ground (a flier keeps its height): nobody stays caught in the box.
## Idempotent; the side that runs the game calls it when the tower stands (complete, or the spawner for a tower born standing).
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
	BodyNudge.place(body, to)


## Rising or fallen: no body stops on it and its ManaSource gives nothing; standing: both as the scene says.
func _show_state() -> void:
	var off := is_rising() or is_destroyed()
	collision_layer = 0 if off else _standing_layer
	mana_source.process_mode = Node.PROCESS_MODE_DISABLED if off else Node.PROCESS_MODE_INHERIT


## Every peer, the tick the health reaches 0. Only the server counts the linger and frees it (the spawner despawns it elsewhere).
func _on_destroyed(_building: MapBuilding) -> void:
	remove_from_group(TOWER_GROUP)
	_show_state()
	if fount != null and is_instance_valid(fount):
		fount.release(get_path())
	if multiplayer.is_server():
		_fallen_at = MatchClock.now()
		set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _fallen_at >= 0 and MatchClock.now() - _fallen_at >= MatchClock.ticks_for(linger_s):
		queue_free()
