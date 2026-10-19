extends StaticBody3D

## One map manafount. While free it feeds mana to everyone in range and shows the jet; once a
## Manalith occupies it, the source is disabled and the Manalith column (tinted with the
## occupant's slot) replaces the jet, until that structure is removed. The Manalith is spawned on
## every peer with its manafount_path, so occupy()/release() run on clients and a late joiner sees
## the right state. The dedicated process draws nothing (SpriteEmitter.set_active is a no-op there).

var _occupied_by := NodePath()
var _source_rate := 0.0

@onready var _free_fx: SpriteEmitter = %FreeFx
@onready var _manalith_fx: SpriteEmitter = %ManalithFx


func _ready() -> void:
	add_to_group("manafount")
	var source := _source()
	if source:
		_source_rate = float(source.get("rate"))
	_free_fx.set_active(true)
	_manalith_fx.set_active(false)


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
	_set_active(false)
	return true


func release(by: NodePath = NodePath()) -> void:
	if by != NodePath() and not _occupied_by.is_empty() and _occupied_by != by:
		return
	_occupied_by = NodePath()
	_set_active(true)


func anchor() -> Vector3:
	return global_position


func _set_active(active: bool) -> void:
	var source := _source()
	if source:
		source.set("rate", _source_rate if active else 0.0)
	if not active:
		var slot := _occupant_slot()
		_manalith_fx.set_tint(SideColors.mana_color(slot), SideColors.mana_energy_scale(slot))
	_free_fx.set_active(active)
	_manalith_fx.set_active(not active)


func _occupant_slot() -> int:
	var node := get_node_or_null(_occupied_by)
	return int(node.get("owner_slot")) if node != null else 0


func _source() -> Node:
	return get_node_or_null("ManaSource")
