@tool
class_name ManalithAction
extends SpellAction

## Manalith (htlm): the wizard's own tower over the closest free manafount. It looks for the
## fount near the clicked point (up to 20 m) or, failing that, near the wizard (cast range + 1),
## needs room for the model and puts the structure up when the casting time ends. The click is
## the ground; the fount decides where the structure stands.

const NO_FOUNT := "Sin fuente"
## sacengine: the fount a click picks is the closest free one within this distance of the point.
const POINT_FOUNT_RANGE := 20.0

var _model := ""
var _point := Vector3.ZERO
var _fount_path := NodePath()


func arm_status(wizard: WizardBody, spell: SpellType) -> String:
	return NOT_IMPLEMENTED if _structure_model(wizard, spell).is_empty() else ""


func check(wizard: WizardBody, spell: SpellType, point: Vector3, _picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	aim.point = point
	var fount := _closest_free_manafount(point)
	if fount == null:
		fount = _closest_free_manafount(wizard.global_position, spell.cast_range + 1.0)
	if fount == null:
		aim.status = NO_FOUNT
		return aim
	var anchor: Variant = fount.call("anchor") if fount.has_method("anchor") else fount.global_position
	aim.point = anchor if anchor is Vector3 else fount.global_position
	aim.status = standing_status(funds, wizard, spell, aim.point)
	if aim.status.is_empty() and not _can_place(aim.point, _structure_model(wizard, spell)):
		aim.status = NO_ROOM
	aim.data["fount"] = fount.get_path()
	return aim


func begin(wizard: WizardBody, spell: SpellType, aim: Aim) -> void:
	_model = _structure_model(wizard, spell)
	_point = aim.point
	_fount_path = aim.data.get("fount", NodePath())


func finish(wizard: WizardBody, spell: SpellType, _target: Node3D) -> String:
	var model := _model
	var point := _point
	var fount_path := _fount_path
	cancel()
	if model.is_empty():
		return ""
	var spawner := get_tree().get_first_node_in_group("structure_spawner")
	if spawner == null:
		return ""
	var fount := get_node_or_null(fount_path)
	if fount == null or not fount.has_method("is_free") or not bool(fount.call("is_free")):
		return NO_FOUNT
	spawner.call("spawn_structure", {
		"x": point.x, "y": point.y, "z": point.z,
		"yaw": wizard.rotation.y,
		"slot": wizard.owner_slot,
		"model": model,
		"spell_tag": spell.tag,
		"manafount_path": str(fount_path),
	})
	FxBus.broadcast("summon", point + Vector3.UP)
	return ""


func cancel() -> void:
	_model = ""
	_point = Vector3.ZERO
	_fount_path = NodePath()


## The model of the wizard's god (SpellType.structures is listed in the order of GameData.gods()).
func _structure_model(wizard: WizardBody, spell: SpellType) -> String:
	if spell == null or spell.structures.is_empty():
		return ""
	var index := GameData.gods().find(wizard.god)
	if index < 0:
		index = 0
	if index >= spell.structures.size():
		return ""
	return spell.structures[index]


func _can_place(point: Vector3, model: String) -> bool:
	var radius := maxf(1.0, float(BodyLibrary.info(model).get("radius", 4.0)))
	for group in ["wizard", "unit", "structure"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Node3D or not is_instance_valid(node):
				continue
			if (node as Node3D).global_position.distance_to(point) <= radius + 2.0:
				return false
	return true


func _closest_free_manafount(point: Vector3, max_distance := POINT_FOUNT_RANGE) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("manafount"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		var fount := node as Node3D
		if fount.has_method("is_free") and not bool(fount.call("is_free")):
			continue
		var anchor: Variant = fount.call("anchor") if fount.has_method("anchor") else fount.global_position
		var at: Vector3 = anchor if anchor is Vector3 else fount.global_position
		var d := at.distance_to(point)
		if d <= max_distance and d < best_d:
			best_d = d
			best = fount
	return best
