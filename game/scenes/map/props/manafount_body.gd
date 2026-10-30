@tool
class_name ManafountBody
extends StaticBody3D

## One map manafount. Free, it feeds mana to everyone in range and shows the jet and its loop
## (`fountain_loop`). Taken by a tower, the source stops and the jet goes; while that tower rises
## the fount shows nothing, and once it stands the column (tinted with the occupant's side), its
## ManalithLight and its hum (`manalith_loop`) show, until the tower is removed. The look is derived
## from (occupant, rising) in one place (_show), so a late joiner or a client sees the same. The
## dedicated process draws nothing. The mesh is the land's fountain (`mesh`); collision and source
## are the same for every land. Does not decide who builds (StructureAction) nor mark the start or
## the end of a rise (BuildCues).

## The group every manafount joins.
const GROUP := &"manafount"

## The land's fountain model (the mesh of its fountain building in scenes/structures/buildings/),
## drawn by `visual`. The scene's default is the Persephone fountain; a map sets its land's.
@export var mesh: Mesh:
	set(value):
		mesh = value
		if is_node_ready():
			_show_mesh()
## Where the fountain is drawn.
@export var visual: MeshInstance3D
## The ground a tower cast here clears (and the ring of the armed preview). Empty: no push, no ring,
## no building check.
@export var build_area: BuildArea

var _occupied_by := NodePath()
var _source_rate := 0.0

@onready var _free_fx: SpriteEmitter = %FreeFx
@onready var _manalith_fx: SpriteEmitter = %ManalithFx
@onready var _manalith_light: StateLight = %ManalithLight
@onready var _fount_sound: SoundEmitter3D = %FountSound
@onready var _manalith_sound: SoundEmitter3D = %ManalithSound


func _ready() -> void:
	_show_mesh()
	# The editor only shows the model; none of the game runs there.
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	var source := _source()
	if source:
		_source_rate = float(source.get("rate"))
	_show()


func _show_mesh() -> void:
	update_configuration_warnings()
	if visual != null and visual.mesh != mesh:
		visual.mesh = mesh


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if visual == null:
		warnings.append("Assign `visual` (the fount's MeshInstance3D).")
	if mesh == null:
		warnings.append("Assign `mesh` (the fount model of this land).")
	if build_area == null:
		warnings.append("Assign `build_area` (the BuildArea the tower clears when cast).")
	return warnings


func is_free() -> bool:
	if _occupied_by.is_empty():
		return true
	var node := get_node_or_null(_occupied_by)
	return node == null or not is_instance_valid(node)


func occupy(by: NodePath) -> bool:
	if by.is_empty():
		return false
	if not is_free() and _occupied_by != by:
		return false
	_occupied_by = by
	# The look changes the tick a rising tower stands. A stale listener after release is harmless:
	# _show reads the occupant.
	var tower := get_node_or_null(by) as CastTower
	if tower != null and not tower.build_progress_changed.is_connected(_on_occupant_progress):
		tower.build_progress_changed.connect(_on_occupant_progress)
	_show()
	return true


func release(by: NodePath = NodePath()) -> void:
	if by != NodePath() and not _occupied_by.is_empty() and _occupied_by != by:
		return
	_occupied_by = NodePath()
	_show()


func anchor() -> Vector3:
	return global_position


## Occupied by a tower that stands: the column, its light and its hum are on. An occupant that is
## not a CastTower (a structure placed by hand, a probe) counts as standing.
func shows_tower() -> bool:
	if is_free():
		return false
	var tower := get_node_or_null(_occupied_by) as CastTower
	return tower == null or not tower.is_rising()


## The whole look from (occupant, rising): free = source, jet and its loop; taken = none of them;
## standing = column, light, hum.
func _show() -> void:
	var free := is_free()
	var standing := shows_tower()
	var source := _source()
	if source:
		source.set("rate", _source_rate if free else 0.0)
	if standing:
		var slot := _occupant_slot()
		_manalith_fx.set_tint(SideColors.mana_color(slot), SideColors.mana_energy_scale(slot))
		if is_instance_valid(_manalith_light):
			_manalith_light.light_color = SideColors.mana_color(slot)
	if is_instance_valid(_manalith_light):
		_manalith_light.show_lit(standing)
	_free_fx.set_active(free)
	_manalith_fx.set_active(standing)
	_fount_sound.set_active(free)
	_manalith_sound.set_active(standing)


func _on_occupant_progress(progress: float) -> void:
	if progress >= 1.0:
		_show()


func _occupant_slot() -> int:
	var node := get_node_or_null(_occupied_by)
	return int(node.get("owner_slot")) if node != null else 0


func _source() -> Node:
	return get_node_or_null("ManaSource")
