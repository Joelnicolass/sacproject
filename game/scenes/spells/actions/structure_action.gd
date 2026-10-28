@tool
class_name StructureAction
extends SpellAction

## A structure spell (Manalith, Shrine): the wizard's own tower over the closest free manafount. It looks for the fount near the
## clicked point (up to 20 m) or, failing that, near the wizard (cast range + 1); a fount that already has a tower answers
## FOUNT_TAKEN, a building on its BuildArea OCCUPIED. Creatures and wizards never refuse it. The tower is born on the fount when the
## cast starts and rises while it lasts (the wizard stands still, the BuildArea pushes everyone out); a cut cast frees it, an ended
## one makes it stand. The tower scene comes from the wizard's god (GodType.structures), so the same node serves every structure
## spell. Does not build anything itself (StructureSpawner does) nor draw or sound the rise: every peer derives that from the replicated
## CastTower.build_progress (BuildReveal, ManafountBody), so the cast sends no FX.

const NO_FOUNT := Refusal.NO_FOUNT
const FOUNT_TAKEN := Refusal.FOUNT_TAKEN
## The fount a click picks is the closest free one within this distance of the point.
const POINT_FOUNT_RANGE_M := 20.0

var _fount: ManafountBody
var _tower: CastTower
var _wizard: WizardBody
var _frames := 0
var _frames_done := 0


func arm_status(wizard: WizardBody, spell: SpellType) -> String:
	return NOT_IMPLEMENTED if _scene_of(wizard, spell) == null else ""


## Read only, no instancing: cheap enough for the armed preview on every client.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, _picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	aim.point = point
	var fount := _near_fount(wizard, spell, point, true)
	if fount == null:
		aim.site = _near_fount(wizard, spell, point, false)
		aim.status = FOUNT_TAKEN if aim.site != null else NO_FOUNT
		return aim
	aim.site = fount
	aim.point = fount.anchor()
	aim.status = standing_status(funds, wizard, spell, aim.point)
	if aim.status.is_empty() and not TowerRules.has_room(get_tree(), fount.build_area):
		aim.status = NO_ROOM
	return aim


## The tower is born now on the fount, rising (inactive and unhurt until the cast ends).
func begin(wizard: WizardBody, spell: SpellType, aim: Aim) -> void:
	_forget()
	var fount := aim.site as ManafountBody
	var spawner := get_tree().get_first_node_in_group(StructureSpawner.GROUP) as StructureSpawner
	var scene := _scene_of(wizard, spell)
	if fount == null or spawner == null or scene == null:
		return
	_fount = fount
	_wizard = wizard
	_tower = spawner.spawn_tower(scene, fount, wizard.owner_slot, wizard.rotation.y, true)


func started(_wizard_body: WizardBody, _spell: SpellType, _aim: Aim, frames: int) -> void:
	_frames = maxi(frames, 1)


## Server or solo, every tick of the cast: the tower rises and the BuildArea pushes the bodies out.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _fount == null:
		return
	if not is_instance_valid(_fount) or not is_instance_valid(_tower):
		return
	_frames_done += 1
	if _frames > 0:
		_tower.build_progress = minf(float(_frames_done) / float(_frames), 0.99)
	if _fount.build_area != null:
		_fount.build_area.push_bodies(_wizard)


func finish(_wizard_body: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	var tower := _tower
	var fount := _fount
	_forget()
	if fount == null:
		return ""
	if tower == null or not is_instance_valid(tower) or tower.is_queued_for_deletion():
		return NO_FOUNT
	tower.complete()
	return ""


## The cast was cut: the rising tower goes (on every peer: the spawner despawns it) and the fount is free again.
func cancel() -> void:
	if _tower != null and is_instance_valid(_tower) and _tower.is_rising():
		_tower.queue_free()
	_forget()


func _forget() -> void:
	_fount = null
	_tower = null
	_wizard = null
	_frames = 0
	_frames_done = 0


## The fount closest to the click (within POINT_FOUNT_RANGE_M), else to the wizard (cast range + 1); only free ones with `free_only`.
func _near_fount(wizard: WizardBody, spell: SpellType, point: Vector3, free_only: bool) -> ManafountBody:
	var fount := TowerRules.closest_fount(get_tree(), point, POINT_FOUNT_RANGE_M, free_only)
	if fount == null:
		fount = TowerRules.closest_fount(get_tree(), wizard.global_position, spell.cast_range_m + 1.0, free_only)
	return fount


## The tower scene of the wizard's god for this spell, or null.
func _scene_of(wizard: WizardBody, spell: SpellType) -> PackedScene:
	var god := wizard.god_type
	var entry := god.structure_for(spell) if god != null and spell != null else null
	return entry.scene if entry != null else null
