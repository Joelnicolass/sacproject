class_name Corpse
extends Node

## The dead body as the game sees it: it keeps falling until it rests on the floor, and only then counts as a corpse
## that stays on the map until its soul is taken, it is desecrated or it is converted back to life. It counts the fall
## in physics ticks and tells whoever listens (the soul, the look). It never animates anything and never fades the body.
## Ref: sacengine dying -> dead, when the soul appears (state.d:14026).

## The body died and started to lie down (`instant`: it joined late and already lies). CorpseLook listens.
signal laid_down(instant: bool)
## The body rests on the floor: this is when the soul appears.
signal settled
## The corpse started or stopped dissolving (its soul was taken). Every peer hears it, because `dissolving` is replicated.
signal dissolving_changed(on: bool)
## A Convert doctor brought the body back to life: it is a creature again.
signal stood_up

## Every body that lies dead on the map.
const GROUP := &"corpse"

## Physics layer of corpses: off the unit layer (2) so picks and other bodies ignore it.
@export_flags_3d_physics var corpse_layer := 8
## A body on the ground counts as fallen after this long (as the tip-over lasted).
@export_range(0.0, 10.0, 0.0001, "suffix:s") var fall_s := 0.9166
## A body that never lands (it keeps falling) counts as fallen after this long anyway.
@export_range(1.0, 60.0, 0.5, "suffix:s") var max_fall_s := 10.0
## The corpse is removed this long after its soul is taken.
@export var dissolve_s := 2.5
## How far the body leans back when a death clip lays it down (degrees): where the soul sits. See lying_pose().
@export_range(0.0, 90.0) var fall_deg := 90.0

## The body is a corpse now (it fell, or is falling).
var laid := false
## The fall is over: the body rests on the floor.
var is_settled := false
## The clip that lays the body down ("" = none: baked meshes, no dying clip). Set by whoever lays the body down.
var death_role := ""
## true: a clip (the skeleton's death) lays the body down and the pivot stays upright. Only the soul's place changes.
var clip_driven := false
## Server writes it, the clients get it (unit.tscn replicates it).
@export var dissolving := false:
	set(value):
		if value == dissolving:
			return
		dissolving = value
		dissolving_changed.emit(dissolving)

var _body: UnitBody
var _ticks := 0


func _ready() -> void:
	set_physics_process(false)


## The pose the pivot would end in once the body lies. Upright unless a clip lays the body down.
func lying_pose(body_radius: float) -> Transform3D:
	if not clip_driven:
		return Transform3D.IDENTITY
	return Transform3D(Basis.from_euler(Vector3(-deg_to_rad(fall_deg), 0.0, 0.0)), Vector3(0.0, body_radius, 0.0))


## Every peer. The body is dead: it leaves the creatures and starts to fall. `instant`: it joined late, it already lies.
func lay_down(body: UnitBody, role := "", instant := false) -> void:
	if laid:
		return
	laid = true
	death_role = role
	clip_driven = not role.is_empty()
	_body = body
	_ticks = 0
	body.remove_from_group("unit")
	body.add_to_group(GROUP)
	body.collision_layer = corpse_layer
	body.velocity = Vector3.ZERO
	laid_down.emit(instant)
	if instant:
		_settle()
		return
	set_physics_process(true)


## Every peer. Undoes lay_down(): the body is a creature again (group, layer). The one that took it (Captive) decides
## what it is while a doctor holds it.
func stand_up(body: UnitBody) -> void:
	if not laid:
		return
	laid = false
	is_settled = false
	death_role = ""
	clip_driven = false
	dissolving = false
	set_physics_process(false)
	body.remove_from_group(GROUP)
	body.add_to_group("unit")
	body.collision_layer = body.unit_layer
	stood_up.emit()


## Server or solo. The spawner removes it on clients.
func dissolve(body: Node) -> void:
	if dissolving or (MpKit.is_networked() and not MpKit.is_server()):
		return
	dissolving = true
	get_tree().create_timer(dissolve_s, false, true).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free())


## Runs after its body's own physics step (a child follows its parent), so `is_on_floor()` is this tick's.
func _physics_process(_delta: float) -> void:
	_ticks += 1
	var landed := not _body.simulates() or _body.is_on_floor()
	if (landed and _ticks >= MatchClock.ticks_for(fall_s)) or _ticks >= MatchClock.ticks_for(max_fall_s):
		_settle()


func _settle() -> void:
	is_settled = true
	set_physics_process(false)
	settled.emit()
