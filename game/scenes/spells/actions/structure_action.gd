@tool
class_name StructureAction
extends SpellAction

## A structure spell (Manalith, Shrine): the wizard's own tower over the closest free manafount. It looks for the fount near
## the clicked point (up to 20 m) or, failing that, near the wizard (cast range + 1), needs room for the tower and raises
## it when the casting time ends. The tower scene comes from the wizard's god (GodType.structures), so the same node serves
## every structure spell: `tag` says which one. The click is the ground; the fount decides where the tower stands.
## Does not build anything itself: StructureSpawner does.

const NO_FOUNT := Refusal.NO_FOUNT
## The fount a click picks is the closest free one within this distance of the point.
const POINT_FOUNT_RANGE_M := 20.0

var _scene: PackedScene
var _fount: ManafountBody


func arm_status(wizard: WizardBody, spell: SpellType) -> String:
	return NOT_IMPLEMENTED if _scene_of(wizard, spell) == null else ""


func check(wizard: WizardBody, spell: SpellType, point: Vector3, _picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	aim.point = point
	var fount := TowerRules.closest_free_fount(get_tree(), point, POINT_FOUNT_RANGE_M)
	if fount == null:
		fount = TowerRules.closest_free_fount(get_tree(), wizard.global_position, spell.cast_range_m + 1.0)
	if fount == null:
		aim.status = NO_FOUNT
		return aim
	aim.point = fount.anchor()
	aim.status = standing_status(funds, wizard, spell, aim.point)
	var scene := _scene_of(wizard, spell)
	if aim.status.is_empty() and not _can_place(scene, aim.point):
		aim.status = NO_ROOM
	aim.data["fount"] = fount
	aim.data["scene"] = scene
	return aim


func begin(_wizard: WizardBody, _spell: SpellType, aim: Aim) -> void:
	_scene = aim.data.get("scene")
	_fount = aim.data.get("fount")


func finish(wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	var scene := _scene
	var fount := _fount
	cancel()
	var spawner := get_tree().get_first_node_in_group(StructureSpawner.GROUP) as StructureSpawner
	if scene == null or spawner == null:
		return ""
	if fount == null or not is_instance_valid(fount) or not fount.is_free():
		return NO_FOUNT
	spawner.spawn_tower(scene, fount, wizard.owner_slot, wizard.rotation.y)
	FxBus.broadcast("summon", fount.anchor() + Vector3.UP)
	return ""


func cancel() -> void:
	_scene = null
	_fount = null


## The tower scene of the wizard's god for this spell, or null.
func _scene_of(wizard: WizardBody, spell: SpellType) -> PackedScene:
	var god := wizard.god_type()
	var entry := god.structure_for(spell) if god != null and spell != null else null
	return entry.scene if entry != null else null


func _can_place(scene: PackedScene, point: Vector3) -> bool:
	var tower := scene.instantiate() as CastTower
	var footprint := tower.footprint_m()
	tower.free()
	return TowerRules.has_room(get_tree(), point, footprint)
