@tool
class_name DoctorBody
extends CharacterBody3D

## A Sac Doctor (CRE8 `dcas`, model `sacd`): falls out of a vortex, walks to a point, stands working
## and dies. It is not a UnitBody: no orders, no attack, no stun, no corpse and no soul. Creatures,
## shots and direct spells can still attack it (group «doctor», see Attackable).
## The server (or solo) runs the States machine and moves the body; clients get position, rotation,
## pose, work and Health through the MultiplayerSynchronizer of doctor.tscn and only present them.
## Numbers: health, speed and regeneration come from GameData.creature(creature_tag); the plazos
## from `rules` (MatchRules, group «Sacrificios»).

## The drop is over (the bounce included). Server only.
signal landed
## walk_to reached its goal. Server only.
signal arrived(goal: Vector3)
## The doctor died, by damage or kill(). Server only. Leaves no corpse and no soul.
signal died(from_slot: int)
## The StuckGuard gave up on it; it dies right after. Server only.
signal stuck

const GROUP := &"doctor"

## What the doctor is doing. Replicated; it is also how a client knows what to show.
enum Pose { IDLE, FALLING, WALKING, WORKING, DYING }
## What a working doctor does (sacengine pumping, lifting, torturing).
enum Work { PUMP, LIFT, TORTURE }

## CreatureType tag read from GameData.
@export var creature_tag := "dcas"
## Player slot that cast the ritual (0 = nobody).
@export var owner_slot := 0:
	set(value):
		owner_slot = value
		if is_node_ready() and health_bar:
			(health_bar as UnitHealthBar).set_owner_slot(owner_slot)
@export var pose: Pose = Pose.IDLE:
	set(value):
		pose = value
		if is_node_ready():
			_apply_pose()
@export var work: Work = Work.PUMP:
	set(value):
		work = value
		if is_node_ready():
			_apply_pose()
## The creature this doctor carries (absolute path; empty = none). Replicated: it is how a client
## knows who carries whom, to draw the rope (CarryRope). The server sets it from Captive.
@export var carried := NodePath()
## Only for the test bench: the server drops it straight down from where it is placed.
@export var drop_on_ready := false
## sacengine ground creatures turn at π rad/s (stats.d:104).
@export var turn_rate := PI
@export var arrive_distance := 0.25
@export var rules: MatchRules
## RFC-024 024d: a goal that moved less than this from the one the PathFollower is walking to is the same goal (a carrier
## chasing a creature that shuffles would otherwise plan a path every tick).
@export var repath_goal_m := 3.0

@export_group("Clips")
## Pose -> clip role of the CRE8 (idle, run). A pose without an entry keeps the clip it had.
## The falling doctor has no clip of its own in the cache: it holds the idle one.
@export var pose_roles := {
	Pose.IDLE: &"idle",
	Pose.FALLING: &"idle",
	Pose.WALKING: &"run",
	Pose.DYING: &"idle",
}
## Work -> slot of the CRE8 `melee_animations` list. sacengine animations.d: stab = attack0,
## pumpCorpse = attack1, pickUpCorpse = attack2. Torture has no exported clip: it uses the stab.
@export var work_slots := {
	Work.PUMP: 1,
	Work.LIFT: 2,
	Work.TORTURE: 0,
}
## Work -> role of the BodyRig state machine that plays that slot's clip (023e). The rig has one state per role of
## BodyModel.ROLES and the doctor has no states of its own, so each work borrows the role closest to what it does.
@export var work_roles := {
	Work.PUMP: &"work",
	Work.LIFT: &"cast",
	Work.TORTURE: &"attack",
}

@export_group("Sockets")
@export var health: Health
@export var visual: BodyVisual
@export var collision: CollisionShape3D
@export var health_bar: MeshInstance3D
@export var states: FsmMachine
## Plays the clips by role on the BodyRig under `visual` (BodyAnimator, RFC-023 023e). Presentation only: the dedicated
## server has no meshes.
@export var clip_player: ClipPlayback

## Multiplies the pace (Speedup-like effects).
var speed_factor := 1.0
var type: CreatureType
## Where the walk goes / where the drop lands. Server only.
var goal := Vector3.ZERO
var landing := Vector3.ZERO
## Sideways nudge of the StuckGuard: radians the walk heading is rotated for dodge_left seconds.
var dodge_angle := 0.0
var dodge_left := 0.0

var _walking := false
var _killer_slot := 0
var _fade: Tween
## The carrier doctors have one (carrier_doctor.tscn): they walk by waypoints around pillars and buildings (RFC-024 024d,
## the debt of F73). The ritual doctors do not: they stand on the ring of the altar, inside what the grid blocks.
@onready var _path_follower: PathFollower = get_node_or_null("PathFollower")
@onready var _avoidance: BodyAvoidance = $Avoidance


## The Fsm states and the StuckGuard read the model through here (BodyBox, melee reach).
var model: String:
	get:
		return visual.model if visual else ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	type = GameData.creature(creature_tag)
	_fit_collision()
	if clip_player and BodyCatalog.loads_meshes():
		clip_player.setup(visual.model)
	(health_bar as UnitHealthBar).bind(health, owner_slot)
	_apply_pose()
	if MpKit.is_networked() and not MpKit.is_server():
		return
	health.died.connect(_on_health_died)
	if type:
		health.setup(float(type.health))
	if drop_on_ready:
		drop_to(Vector3(global_position.x, _ground_height(global_position), global_position.z))
	else:
		stand()


# --- Verbs (server or solo) ---

## Stands on the ground, still.
func stand() -> void:
	_walking = false
	velocity = Vector3.ZERO
	states.transition(&"Grounded")


## Falls from where it is to `landing` (a point on the ground) in a ballistic arc, bounces and
## lands. Invulnerable until `landed`. Place the body at the start point first.
func drop_to(point: Vector3) -> void:
	landing = point
	_walking = false
	states.transition(&"Dropping")


## Walks to `point` with collision, as the engine moves a CharacterBody3D: by the waypoints of the PathFollower child when
## there is one (RFC-024 024d), else in a line. `arrived` fires at the end of each leg. Calling it again with a new
## point just moves the goal; the same point (within `repath_goal_m`) while a path is on is a no-op.
func walk_to(point: Vector3) -> void:
	if pose == Pose.DYING or pose == Pose.FALLING:
		return
	if is_instance_valid(_path_follower):
		var follower_goal := _path_follower.goal
		if _walking and _path_follower.is_active() \
				and Vector2(point.x - follower_goal.x, point.z - follower_goal.z).length() < repath_goal_m:
			return
		_path_follower.go_to(point)
	else:
		begin_walk(point)


## One straight leg to `point` (what the PathFollower hands out, and what walk_to does without one).
func begin_walk(point: Vector3) -> void:
	if pose == Pose.DYING or pose == Pose.FALLING:
		return
	goal = point
	_walking = true
	states.transition(&"Grounded")


## Stops walking and stands.
func stop() -> void:
	if pose == Pose.DYING or pose == Pose.FALLING:
		return
	if is_instance_valid(_path_follower):
		_path_follower.cancel()
	stand()


## Stands still on the spot doing `kind`.
func begin_work(kind: Work) -> void:
	if pose == Pose.DYING or pose == Pose.FALLING:
		return
	work = kind
	_walking = false
	states.transition(&"Working")


func end_work() -> void:
	if pose == Pose.WORKING:
		stand()


## Dies at once: no corpse, no soul. `from_slot` goes out with `died`.
func kill(from_slot := 0) -> void:
	if pose == Pose.DYING:
		return
	health.current = 0.0
	_die(from_slot)


## The StuckGuard's last resort: tells everyone it is stuck, then dies.
func give_up() -> void:
	if pose == Pose.DYING:
		return
	stuck.emit()
	kill()


# --- Questions ---

func is_walking() -> bool:
	return _walking


func is_dead() -> bool:
	return pose == Pose.DYING or (health != null and health.is_dead())


func is_alive() -> bool:
	return not is_dead()


## Not a target while it falls or dies (the original bounce makes it invulnerable). Health.damage
## and every target search ask this.
func is_targetable() -> bool:
	return pose != Pose.FALLING and pose != Pose.DYING


## sacengine isObstacle (state.d:112-126): it blocks the others, but not once dead.
func is_obstacle() -> bool:
	return pose != Pose.DYING


func display_name() -> String:
	return type.display_name if type else creature_tag


func facing_flat() -> Vector3:
	var ahead := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, rotation.y)
	ahead.y = 0.0
	return ahead.normalized() if ahead.length_squared() > 0.000001 else Vector3(0.0, 0.0, 1.0)


## Defense and size for MeleeAttack.profile_of: evasion and resistance of the CRE8, size of `sacd`.
func melee_profile() -> Dictionary:
	var info := BodyCatalog.info(model)
	return {
		"evasion": float(type.melee_evasion) if type else 0.0,
		"resistance": type.melee_resistance if type else 1.0,
		"reach": float(info.get("reach", 0.35)),
		"height": float(info.get("height", 1.8)),
	}


## Running speed of the CRE8 (the PathFollower reads it to tell when the body is stuck).
var move_speed: float:
	get:
		return type.running_speed if type else 0.0


## Pace in m/s (running speed of the CRE8 times speed_factor).
func pace() -> float:
	return (type.running_speed if type else 0.0) * speed_factor


# --- Shared by the states ---

## sacengine updateCreatureStats: regeneration is continuous, a fresh hit does not pause it.
func regenerate(delta: float) -> void:
	if type and pose != Pose.DYING and not health.is_full():
		health.heal(type.regeneration_per_s * delta)


## Gravity, the avoidance around the other bodies, the ground guard and move_and_slide, as UnitBody.
## `horizontal` is the wanted velocity on x/z.
func advance_on_ground(horizontal: Vector3, delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity() * delta
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	## RFC-036 036f: the engine's avoidance steers the body around the others; the step ends in _on_avoided, this same
	## physics step.
	if is_obstacle() and _avoidance.steer(velocity):
		return
	_finish_step()


## The velocity (x, z) the avoidance gave back: the second half of the step of advance_on_ground.
func _on_avoided(flat_velocity: Vector3) -> void:
	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z
	_finish_step()


func _finish_step() -> void:
	velocity = EdgeClamp.clamp_velocity(self, velocity, get_physics_process_delta_time())
	move_and_slide()
	if FallCheck.has_fallen(self):
		kill()


func turn_toward(direction: Vector3, delta: float) -> void:
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), turn_rate * delta)


static func gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity"))


func _ground_height(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else at.y


func _fit_collision() -> void:
	var height := visual.body_height()
	var capsule := CapsuleShape3D.new()
	capsule.height = maxf(height, 0.6)
	capsule.radius = minf(visual.body_radius(), capsule.height * 0.45)
	collision.shape = capsule
	collision.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	(health_bar as UnitHealthBar).place_above(height)


func _on_health_died(from_slot: int) -> void:
	_die(from_slot)


func _die(from_slot: int) -> void:
	_killer_slot = from_slot
	_walking = false
	states.transition(&"Dying")


## Called by the Dying state once, on the server.
func announce_death() -> void:
	died.emit(_killer_slot)


## What every peer shows for the current pose: the clip, and a dying doctor is not a body any more.
func _apply_pose() -> void:
	## In the editor a pose set from the inspector must not change groups, collision or the bar.
	if Engine.is_editor_hint():
		return
	_play_clip()
	if pose != Pose.DYING:
		return
	remove_from_group(GROUP)
	collision.set_deferred("disabled", true)
	health_bar.visible = false
	if not BodyCatalog.loads_meshes():
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	## BodyVisual.set_fade fades the rig's meshes too (transparency does not inherit).
	_fade.tween_method(visual.set_fade, 0.0, 1.0, rules.doctor_death_s if rules else 2.0)


func _play_clip() -> void:
	if clip_player == null or not BodyCatalog.loads_meshes():
		return
	var role := ""
	if pose == Pose.WORKING:
		role = str(work_roles.get(work, ""))
	else:
		role = str(pose_roles.get(pose, ""))
	if not role.is_empty():
		clip_player.play(role)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if health == null:
		out.append("Asigná `health` (nodo Health).")
	if visual == null:
		out.append("Asigná `visual` (BodyVisual con el modelo sacd).")
	if collision == null:
		out.append("Asigná `collision` (CollisionShape3D).")
	if health_bar == null:
		out.append("Asigná `health_bar` (unit_health_bar.tscn).")
	if states == null:
		out.append("Asigná `states` (FsmMachine con Off, Dropping, Grounded, Working, Dying).")
	if clip_player == null:
		out.append("Asigná `clip_player` (BodyAnimator): sin él el doctor queda en pose fija.")
	if rules == null:
		out.append("Asigná `rules` (MatchRules): plazos de caída, muerte y trabado.")
	return out

