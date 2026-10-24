class_name ZoneDrop
extends SpellProjectile

## Something a cloud lets go: a frog, a drop of fire or of plague, a meteorite. It flies under a pull of `gravity_m_s2`, and its children
## say what it does where it ends (DropBlast, DropPoison) or what else it does on the way (FrogHop, FrogCling). It owns its position,
## velocity and state (flying, resting on the ground, stuck to a body); it never hurts anyone itself. The server (or solo) moves it and
## replicates `position` and `status`; every peer draws it. A cloud's DropLauncher makes it.
## Ref: sacengine updateRainFrog, updatePlagueDrop, updateRainOfFireDrop, updateBombardmentDrop (state.d:19428-19504, 21030-21053, 21172-21196, 21395-21421).

## It touched the ground and stays there (only with `rests`).
signal landed(at: Vector3)
## A body that can be infected is inside its box.
signal touched(body: Node3D, at: Vector3)
## Its flight is over: it hit the ground or a body (`body` null = the ground), or was told to finish. It frees itself right after.
signal ended(body: Node3D, at: Vector3)

enum Status { FLYING, RESTING, ATTACHED }

const GROUP := &"zone_drop"

@export_group("Flight")
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var gravity_m_s2 := 30.0
## Side of the box that touches bodies (0 = never). Only checked this close to the land: a drop high in the sky asks nothing.
@export_range(0.0, 10.0, 0.1, "suffix:m") var contact_m := 1.5
@export_range(1.0, 100.0, 1.0, "suffix:m") var contact_height_m := 30.0
## It touches ground and bodies only while it goes down (a meteorite rises out of the land first).
@export var only_descending := false
## The flight ends at the first body it touches (a frog keeps going: FrogCling decides).
@export var ends_on_contact := true
## It stays on the ground when it lands (a frog sits) instead of ending.
@export var rests := false
## It leaves in the arc that lands on its goal at the time given (a meteorite); else the straight line of that time, under its pull.
@export var lobbed := false
## Seconds after which a drop that never ended goes away.
@export_range(1.0, 120.0, 1.0, "suffix:s") var max_age_s := 60.0

var status := Status.FLYING
var velocity := Vector3.ZERO
## What the cloud's spell does here: the numbers travel with the drop, which knows no spell.
var damage := 0.0
var damage_range := 0.0
var effect_range := 0.0
var from_slot := 0
var caster_path := NodePath()
var _age := 0
var _host: Node3D
var _offset := Vector3.ZERO


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	velocity = ZoneRules.launch_velocity(position, data.get("goal", position), float(data.get("fall_s", 1.0)), gravity_m_s2, lobbed)
	damage = float(data.get("damage", 0.0))
	damage_range = float(data.get("damage_range", 0.0))
	effect_range = float(data.get("effect_range", 0.0))
	from_slot = int(data.get("slot", 0))
	caster_path = NodePath(str(data.get("caster", "")))
	var net := MpReplicate.new()
	net.name = "Net"
	net.interpolate = false
	net.sync_properties = PackedStringArray([".:position", ".:status"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _ready() -> void:
	add_to_group(GROUP)


## Server (or solo): the same drop flies again at `new_velocity` (a frog jumps).
func launch(new_velocity: Vector3) -> void:
	velocity = new_velocity
	status = Status.FLYING


## Server (or solo): it sticks to `body` where it is, and goes with it.
func attach(body: Node3D) -> void:
	_host = body
	_offset = body.global_transform.affine_inverse() * global_position
	velocity = Vector3.ZERO
	status = Status.ATTACHED


## Server (or solo): the flight is over here, on `body` (or null).
func finish(body: Node3D) -> void:
	ended.emit(body, global_position)
	set_physics_process(false)
	queue_free()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	_age += 1
	if _age > MatchClock.ticks_for(max_age_s):
		queue_free()
	elif status == Status.ATTACHED:
		_follow()
	elif status == Status.FLYING:
		_fly()


func _fly() -> void:
	global_position += velocity / MatchClock.TICKS_PER_SECOND_F
	velocity.y -= gravity_m_s2 / MatchClock.TICKS_PER_SECOND_F
	if only_descending and velocity.y >= 0.0:
		return
	var ground := ZoneGround.height(self, global_position.x, global_position.z, 0.0)
	if global_position.y <= ground:
		global_position.y = ground
		_land()
		return
	if contact_m > 0.0 and global_position.y - ground < contact_height_m:
		var body := _touching()
		if body != null:
			touched.emit(body, global_position)
			if ends_on_contact:
				finish(body)


func _land() -> void:
	if not rests:
		finish(null)
		return
	velocity = Vector3.ZERO
	status = Status.RESTING
	landed.emit(global_position)


## The closest body that can be infected inside the contact box.
func _touching() -> Node3D:
	var half := Vector3.ONE * contact_m * 0.5
	var best: Node3D
	var best_d := INF
	for body in BodyNudge.bodies_in(get_tree(), AABB(global_position - half, half * 2.0)):
		var poisoning := Poisoning.of(body)
		var d := global_position.distance_squared_to(BodyNudge.center(body))
		if poisoning != null and poisoning.can_be_poisoned() and d < best_d:
			best = body
			best_d = d
	return best


func _follow() -> void:
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		finish(null)
		return
	global_position = _host.global_transform * _offset
