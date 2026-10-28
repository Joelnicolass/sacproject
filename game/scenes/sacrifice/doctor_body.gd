@tool
class_name DoctorBody
extends GameBody

## A Sac Doctor: falls out of a vortex, walks to a point, stands working and dies. Not a UnitBody: no orders, attack, corpse or soul;
## creatures, shots and spells can still attack it (group «doctor»). It keeps the pose, the work and the health and offers the verbs;
## it does not walk (its `motor`, DoctorMotor) or draw (DoctorLook listens to `pose_changed`); `errand` is what a carrier came for.
## The server (or solo) runs the States machine; clients get the pose (drawn smoothly by its MpActor, BUFFERED), `pose`, `work`, `carried` and Health from the MpActor's MpSync (doctor.tscn) and only present them.

## Server only: the drop is over (the bounce included) / walk_to reached its goal / it died (no corpse, no soul) / the StuckGuard gave up.
signal landed
signal arrived(goal: Vector3)
signal died(from_slot: int)
signal stuck
## The pose or the work changed (on every peer, and once when it is ready): whoever draws the doctor shows the clip.
signal pose_changed(pose: Pose, work: Work)

const GROUP := &"doctor"

enum Pose { IDLE, FALLING, WALKING, WORKING, DYING, LANDING }
enum Work { PUMP, LIFT, TORTURE }

@export var type: CreatureType
@export var pose: Pose = Pose.IDLE:
	set(value):
		pose = value
		_announce_pose()
@export var work: Work = Work.PUMP:
	set(value):
		work = value
		_announce_pose()
## The creature this doctor carries (absolute path, replicated: a client draws the rope from it).
@export var carried := NodePath()
@export var drop_on_ready := false
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var launch_up_m_s := 10.0
@export var rules: MatchRules
@export var health: Health
@export var collision: CollisionShape3D
@export var mount: BodyMount
@export var health_bar: MeshInstance3D
@export var states: FsmMachine
@export var motor: DoctorMotor
@export var errand: CarryErrand

var speed_factor := 1.0
var move_speed: float:
	get:
		return type.run_speed_m_s if type else 0.0
var _killer_slot := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if type:
		mount.wear(type.body)
	(health_bar as UnitHealthBar).place_above(mount.facts.height_m)
	(health_bar as UnitHealthBar).bind(health, owner_slot)
	_announce_pose()
	if not simulates():
		return
	health.died.connect(_die)
	if type:
		health.setup(float(type.health))
	if drop_on_ready:
		drop_to(
			Vector3(
				global_position.x,
				GroundRay.surface_y(self, global_position, 1, [get_rid()], global_position.y),
				global_position.z
			)
		)
	else:
		stand()


func _owner_slot_changed() -> void:
	if is_node_ready() and health_bar:
		(health_bar as UnitHealthBar).set_owner_slot(owner_slot)


func stand() -> void:
	motor.halt()
	velocity = Vector3.ZERO
	_go(&"Grounded")


## Falls out of the vortex to `point` (the payload of Dropping).
func drop_to(point: Vector3) -> void:
	motor.halt()
	_go(&"Dropping", point)


## Walks to `point` with collision; `begin_walk` is one straight leg (what the PathFollower hands out).
func walk_to(point: Vector3) -> void:
	motor.walk_to(point)


func begin_walk(point: Vector3) -> void:
	motor.begin_walk(point)


func turn_toward(direction: Vector3, delta: float) -> void:
	motor.turn_toward(direction, delta)


## Stops walking and stands.
func stop() -> void:
	if is_targetable():
		motor.cancel_path()
		stand()


func begin_work(kind: Work) -> void:
	if is_targetable():
		work = kind
		motor.halt()
		_go(&"Working")


func end_work() -> void:
	if pose == Pose.WORKING:
		stand()


## Dies at once: no corpse, no soul. `from_slot` goes out with `died`.
func kill(from_slot := 0) -> void:
	if pose != Pose.DYING:
		health.current = 0.0
		_die(from_slot)


## The StuckGuard's last resort: tells everyone it is stuck, then dies.
func give_up() -> void:
	if pose != Pose.DYING:
		stuck.emit()
		kill()


## The server or a solo game moves and rules it; a client only shows it.
func simulates() -> bool:
	return is_multiplayer_authority()


func is_walking() -> bool:
	return motor.is_walking()


func is_dead() -> bool:
	return pose == Pose.DYING or (health != null and health.is_dead())


func is_alive() -> bool:
	return not is_dead()


func is_dropping() -> bool:
	return pose == Pose.FALLING or pose == Pose.LANDING


## Not a target while it falls or dies (the bounce makes it invulnerable). Health.damage and every target search ask this.
func is_targetable() -> bool:
	return not is_dropping() and pose != Pose.DYING


func is_obstacle() -> bool:
	return pose != Pose.DYING


func display_name() -> String:
	return type.display_name if type else name


func pace() -> float:
	return (type.run_speed_m_s if type else 0.0) * speed_factor


func landing_s() -> float:
	return motor.landing_s()


## Defense and size for MeleeRules.profile_of: evasion and resistance of the CRE8, size of `sacd`.
func melee_profile() -> Dictionary:
	return {
		"evasion": float(type.melee_evasion_milli()) if type else 0.0,
		"resistance": type.melee_resistance if type else 1.0,
		"reach": mount.facts.reach_m,
		"height": mount.facts.height_m
	}


func regenerate(delta: float) -> void:
	if type and pose != Pose.DYING and not health.is_full():
		health.heal(type.regeneration_per_s * delta)


func announce_death() -> void:
	died.emit(_killer_slot)


func _die(from_slot: int) -> void:
	_killer_slot = from_slot
	motor.halt()
	_go(&"Dying")


## The one way into `states` (autostart is off, so a client never runs it): the first call starts it in `state_name`, the rest transition.
func _go(state_name: StringName, payload: Variant = null) -> void:
	if states.is_started():
		states.transition(state_name, payload)
	else:
		states.start(states.get_node(NodePath(String(state_name))) as FsmState, payload)


## A dying doctor is not a body any more; the rest is told to whoever draws it. Not in the editor.
func _announce_pose() -> void:
	if Engine.is_editor_hint() or not is_node_ready():
		return
	if pose == Pose.DYING:
		remove_from_group(GROUP)
		collision.set_deferred("disabled", true)
	pose_changed.emit(pose, work)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	for socket in [
		"type", "rules", "health", "collision", "mount", "health_bar", "states", "motor"
	]:
		if get(socket) == null:
			out.append("Assign `%s` (see doctor.tscn)." % socket)
	return out
