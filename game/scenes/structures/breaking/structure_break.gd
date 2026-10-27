@tool
class_name StructureBreak
extends Node

## When its building falls, every part of it bursts where it stands: the scene `scene` (an FxScene: fire spheres, rocks, sound)
## and each burst of `bursts`, at BuildingFit.part_center of each holder under the building's `Visuals`. It runs on every peer
## from the replicated fall (`MapBuilding.destroyed`), local FxBus.play_scene / play: nothing goes on the wire, and a headless
## process only emits `played` and `broke`. A building that was already down when this peer joined does not burst (`arm_after_s`).
## Does not decide the fall (MapBuilding), show the ruin (BuildingRuin) nor hurt anyone. Take the node out: it falls with no FX.
## Ref: sacengine updateBuildingDestruction and destructionAnimation (state.d:15157-15181, 27650-27660).

## A part burst at `at` (world), once per part with a mesh, on every peer.
signal broke(at: Vector3)

## The building that falls (the root of map_building.tscn).
@export var building: MapBuilding:
	set(value):
		building = value
		update_configuration_warnings()
## What bursts at each part: building_break.tscn, or a smaller one set on the scene of one building.
@export var scene: PackedScene:
	set(value):
		scene = value
		update_configuration_warnings()
## Sprite bursts played beside `scene` at each part (explosion_blast, explosion_blast2). Empty: only the scene.
@export var bursts: Array[ParticleType] = []
## Seconds after this peer loaded the building before a fall bursts: a late join sees the ruin, not an old explosion.
@export_range(0.0, 10.0, 0.1, "suffix:s") var arm_after_s := 2.0

var _born_tick := 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if building == null:
		warnings.append("Asigná `building` (la raíz MapBuilding).")
	if scene == null:
		warnings.append("Asigná `scene` (scenes/structures/breaking/building_break.tscn).")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint() or building == null:
		return
	_born_tick = MatchClock.now()
	building.destroyed.connect(_on_destroyed)


## A fall would burst now: `arm_after_s` passed since this peer loaded the building.
func is_armed() -> bool:
	return MatchClock.now() - _born_tick >= MatchClock.ticks_for(arm_after_s)


func _on_destroyed(_building: MapBuilding) -> void:
	if not is_armed() or building.visuals == null:
		return
	for holder in building.visuals.get_children():
		var part := holder as Node3D
		if part == null:
			continue
		var at := BuildingFit.part_center(part)
		if is_nan(at.x):
			continue
		FxBus.play_scene(scene, at, {})
		for fx in bursts:
			FxBus.play(fx, at)
		broke.emit(at)
