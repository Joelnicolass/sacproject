@tool
class_name SpellWall
extends SpellProjectile

## A wall a wizard raises on the ground (Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence): it is centred on the click and runs
## across the line from the wizard to it. Both ends grow outwards while he casts and stop at `effect_range`, at a building or at the edge
## of the land. It rises, stands for the spell's `duration` and sinks. The children say what it does (WallTouch hurts what is inside,
## FencePosts and FenceZap are the Fence, the rest is the look). It does not hurt, slow or draw anything itself. The server (or solo)
## grows the ends and decides when it ends; `age`, `left`, `right` and `vanish_at` are replicated and every peer derives the height
## (`top()`) from them. Its size is the `Body` shape: x the whole reach, y the height, z the thickness.

## Its `effect_range` is how far each end may go, its `duration` how long the wall stands.
@export var spell: SpellType
## The wall's box: size.y is the height it rises to, size.z the thickness, size.x the whole reach (2 * effect_range, to show it).
@export var body: CollisionShape3D
## Ticks the ends take to reach `effect_range` when nothing stops them.
@export_range(1, 3600) var grow_ticks := 240
@export_range(0.0, 10.0, 0.05, "suffix:s") var rise_s := 2.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var vanish_s := 1.0
## Seconds the wall stays after it sank (Wailing Wall's spirits fade out over 4 s).
@export_range(0.0, 10.0, 0.05, "suffix:s") var linger_s := 0.0
## An end may go this far beyond `effect_range` (Fence).
@export_range(0.0, 5.0, 0.1, "suffix:m") var reach_slack_m := 0.0
## The clock starts when the casting time is over, not when the cast begins (Fence).
@export var starts_when_armed := false
## Extra properties of children the synchronizer carries (`Node:property`).
@export var sync_extra := PackedStringArray()

## Replicated: ticks since the cast began, the ends in metres along the wall, and the tick it began to sink (-1 = not yet).
var age := 0
var left := 0.0
var right := 0.0
var vanish_at := -1
## The casting time is over (or was cut): the children may act.
var armed := false
var center := Vector3.ZERO
var direction := Vector2.RIGHT
var wizard_path := NodePath()
var from_slot := 0

## An end stopped growing (a building, the edge of the land, its reach).
var left_stopped := false
var right_stopped := false
var _ended := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if spell == null:
		warnings.append("Falta `spell`: el SpellType del muro (alcance y duración).")
	if body == null or not body.shape is BoxShape3D:
		warnings.append("Falta `body` con un BoxShape3D: su y es el alto y su z el espesor.")
	return warnings


## `data`: name, x, y, z (the click), dir_x, dir_z (where the wall runs), caster (path), slot.
func setup(data: Dictionary) -> void:
	name = str(data["name"])
	center = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	direction = Vector2(float(data["dir_x"]), float(data["dir_z"]))
	wizard_path = NodePath(str(data.get("caster", "")))
	from_slot = int(data.get("slot", 0))
	position = center
	rotation.y = WallRules.yaw_of(direction)
	var props := PackedStringArray([".:age", ".:left", ".:right", ".:vanish_at"])
	props.append_array(sync_extra)
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = props
	net.interpolate = false
	MpAuthority.ensure_sync(self, props)
	add_child(net)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)


func wizard() -> Node3D:
	return get_node_or_null(wizard_path) as Node3D if not wizard_path.is_empty() else null


func height_m() -> float:
	return (body.shape as BoxShape3D).size.y if body != null and body.shape is BoxShape3D else 0.0


func thickness_m() -> float:
	return (body.shape as BoxShape3D).size.z if body != null and body.shape is BoxShape3D else 0.0

func reach_m() -> float:
	return spell.effect_range if spell != null else 0.0


func rise_ticks() -> int:
	return MatchClock.ticks_for(rise_s)


func vanish_ticks() -> int:
	return MatchClock.ticks_for(vanish_s)


func top() -> float:
	return height_m() * WallRules.rise(age, rise_ticks(), vanish_at, vanish_ticks())


## 0 to 1 over `ramp_s` once `start_s` have passed (a negative start: once the wall is at full height).
func ramp(start_s: float, ramp_s: float) -> float:
	var start := rise_ticks() if start_s < 0.0 else MatchClock.ticks_for(start_s)
	return WallRules.ramp(age, start, MatchClock.ticks_for(ramp_s))


func point_at(t: float) -> Vector3:
	var flat := center + Vector3(direction.x, 0.0, direction.y) * t
	flat.y = ground_y(flat.x, flat.z)
	return flat


func ground_y(x: float, z: float) -> float:
	return WallGround.ground_y(self, center.y, x, z)


func bodies_inside() -> Array[Node3D]:
	return WallGround.bodies_inside(self)


## Server or solo: the casting time is over, the children may act.
func arm() -> void:
	armed = true


## Server or solo: the wizard was cut, the wall sinks now (and acts while it does).
func stop() -> void:
	armed = true
	if vanish_at < 0:
		vanish_at = age


func _physics_process(_delta: float) -> void:
	if _ended or (starts_when_armed and not armed and age == 0):
		return
	if multiplayer.is_server():
		WallGround.grow(self)
		if vanish_at < 0 and age >= grow_ticks + MatchClock.ticks_for(spell.duration):
			vanish_at = age
		if vanish_at >= 0 and age - vanish_at >= vanish_ticks() + MatchClock.ticks_for(linger_s):
			_ended = true
			queue_free()
			return
	age += 1
