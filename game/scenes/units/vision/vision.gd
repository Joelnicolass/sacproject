@tool
class_name Vision
extends Area3D

## What one body sees: who stands inside its sight shape (and cone), reported in name order, and
## what its side keeps in mind of them. It does not choose targets (TargetPicker) nor decide what
## the AI knows (AiPerception); the sight of a side is the union of the Visions of its bodies
## (VisionSides). Resize it with the gizmo of its Shape or set `radius_m`; what it can see sits in
## `seen_groups`.

## Who came into sight / left it on the last refresh, and who hurt this body (VisionSides.reveal).
signal seen(node: Node3D)
signal lost(node: Node3D)
signal hurt_by(attacker: Node3D)

## A mark that never lapses (a structure or fount stands still); groups with no physics body, which
## the area cannot see.
const FOREVER := 1 << 30
const BODILESS: Array[StringName] = [&"manafount"]

## Whose eyes these are (default: the parent). Its `owner_slot` is the side.
@export var body: Node3D
## The sight shape; its handle in the viewport is the sight radius.
@export var shape: CollisionShape3D
## The match rules that say if allies share what they see (MatchRules.allied_vision).
@export var rules: MatchRules
## 0 = the slot of the body. The Divine Sight eye takes the slot of the Ranger who sent it.
@export var side_slot := 0
@export_group("Sight")
## 0 = the range the creature type gives (CreatureType.vision_m, WizardType.vision_m).
@export_range(0.0, 1000.0, 0.1, "suffix:m") var radius_m := 0.0:
	set(value):
		radius_m = value
		_apply_shape()
## A sphere also measures height; the default cylinder 400 m tall only measures the flat distance.
@export var spherical := false
## Total angle of the cone in front of the body; 360 = sees all around.
@export_range(1.0, 360.0, 1.0, "suffix:deg") var fov_deg := 360.0
@export var seen_groups: PackedStringArray = PackedStringArray(
	["unit", "wizard", "structure", "doctor", "manafount"]
)
## How long a foe stays known to the side after a Vision last saw it.
@export_range(0.0166, 600.0, 0.0001, "suffix:s") var forget_s := 6.4
## How often it looks again; every body looks on its own tick of the cycle.
@export_range(0.0166, 10.0, 0.0001, "suffix:s") var refresh_s := 0.5
## true: the physics area narrows the candidates (only bodies on its collision mask); false: walks
## the groups. The same answer.
@export var use_area := false
## Off while the body cannot look (dead, summoning, taken, or a client that does not simulate).
@export var watching := true:
	set(value):
		watching = value
		set_physics_process(value and not Engine.is_editor_hint())
		monitoring = value and use_area

var _type_m := 0.0
var _range_m := 0.0
var _phase := 0
var _period := 1
var _sight: Array[Node3D] = []
var _ids: Dictionary = {}
var memory := VisionMemory.new()


func _enter_tree() -> void:
	VisionSides.join(self)


func _exit_tree() -> void:
	VisionSides.leave(self)


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	if Engine.is_editor_hint():
		return
	watching = watching
	memory.forget_ticks = MatchClock.ticks_for(forget_s)
	_period = maxi(1, MatchClock.ticks_for(refresh_s))
	_phase = posmod(String(body.name).hash(), _period)
	_apply_shape()


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if shape != null
		else PackedStringArray(["Missing the shape (shape): a CollisionShape3D child."])
	)


func _physics_process(_delta: float) -> void:
	if (MatchClock.now() + _phase) % _period == 0:
		refresh()


## The owner's type says how far it sees (UnitBody, WizardBody). A `radius_m` set by hand wins.
func adopt_range(meters: float) -> void:
	_type_m = meters
	_apply_shape()


func range_m() -> float:
	return _range_m


func side() -> int:
	return side_slot if side_slot > 0 else VisionRules.slot_of(body)


## Whether `point` lies inside the sight shape and cone, whoever stands there.
func covers(point: Vector3) -> bool:
	return VisionRules.covers(
		spherical, global_position, point, _range_m, body.global_basis.z, fov_deg
	)


## Who is in sight as of the last refresh, sorted by name.
func in_sight() -> Array[Node3D]:
	var found: Array[Node3D] = []
	found.assign(_sight.filter(func(node: Variant) -> bool: return is_instance_valid(node)))
	return found


func sees(node: Node3D) -> bool:
	return node != null and _ids.has(node.get_instance_id())


## Looks again: tells who came in and who left (each in name order) and keeps the foes in mind for
## the side.
func refresh() -> void:
	var before := _sight
	var was := _ids
	_ids = {}
	_sight = VisionRules.filter(_candidates(), body, spherical, global_position, _range_m, fov_deg)
	for other in _sight:
		_ids[other.get_instance_id()] = true
	memory.take_in(_sight, side(), body, MatchClock.now())
	for node in _sight:
		if not was.has(node.get_instance_id()):
			seen.emit(node)
	for node: Variant in before:
		if is_instance_valid(node) and not _ids.has(node.get_instance_id()):
			lost.emit(node)


## Side `slot` has just seen this body strike one of its own.
func expose_to(slot: int) -> void:
	memory.expose_to(slot, MatchClock.now(), body)


func _candidates() -> Array:
	var by_area := use_area and monitoring
	return VisionRules.gather(
		get_tree(), seen_groups, get_overlapping_bodies() if by_area else [], by_area
	)


func _apply_shape() -> void:
	_range_m = radius_m if radius_m > 0.0 else _type_m
	VisionRules.fit(shape, spherical, _range_m)
