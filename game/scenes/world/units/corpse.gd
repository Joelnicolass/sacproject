extends Node

## Turns the dead body into a corpse that stays on the map, as sacengine corpses do until
## desecrated, converted or its soul is taken. The dying SXSK animation is not baked, so the
## pivot tips over backwards with a Tween. Every peer runs lay_down(). A normal death has no
## blood: sacengine only bursts on gib (state.d:8310).

## The fall ended (sacengine dying -> dead, when the soul appears).
signal settled

## Node that holds the mesh and tips over (feet at its origin).
@export var pivot: Node3D
## The body's visual (BodyVisual): the corpse fades it out at the end of its life.
@export var visual: Node3D
## Physics layer of corpses: off the unit layer (2) so picks and other bodies ignore it.
@export_flags_3d_physics var corpse_layer := 8
## sacengine dissolutionTime: the corpse is removed 2.5 s after its soul is taken (state.d:8368).
@export var dissolve_s := 2.5
## RFC-023f: the last seconds of dissolve_s the body fades out in, instead of vanishing at once. sacengine removes it
## with no fade (it only plays a sound, state.d:14073-14078): this one is a request of the user, on top of the original.
@export_range(0.0, 2.5, 0.05, "or_greater") var fade_s := 1.0

## Seconds the body takes to get back on its feet when a Convert doctor revives it (RFC-020e). The
## original `revive` animation is not exported: this is the fall played backwards.
@export var stand_s := 0.9

@export_group("Fall")
@export var anticipation_deg := 9.0
@export var anticipation_s := 0.14
@export var fall_deg := 90.0
@export var fall_s := 0.55
@export var settle_deg := 6.0
@export var settle_s := 0.22

var laid := false
var is_settled := false
## Server writes it, the clients get it (unit.tscn replicates it): every peer fades the body for the last fade_s.
@export var dissolving := false:
	set(value):
		if value == dissolving:
			return
		dissolving = value
		if is_node_ready():
			_show_dissolve()
## true: a clip (the skeleton's death) lays the body down and the pivot stays upright. Only the draw changes: the
## fall lasts the same ticks, because the soul appears when settled is emitted.
var clip_driven := false

var _stand_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	if dissolving:
		_show_dissolve()


## Where the pivot ends when the body lies (the Tween's last pose): the soul sits on it either way.
func laid_pose(body_radius: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(-deg_to_rad(fall_deg), 0.0, 0.0)), Vector3(0.0, body_radius, 0.0))


## `by_clip`: the death clip lays the body down; the pivot is not touched and the timer is the Tween's.
func lay_down(body: CharacterBody3D, body_radius: float, animate := true, by_clip := false) -> void:
	if laid:
		return
	laid = true
	clip_driven = by_clip
	if _stand_tween:
		_stand_tween.kill()
	body.remove_from_group("unit")
	body.add_to_group("corpse")
	body.collision_layer = corpse_layer
	body.velocity = Vector3.ZERO
	if pivot == null:
		_on_settled()
		return
	var tilt := deg_to_rad(fall_deg)
	if by_clip:
		if animate:
			var timer := pivot.create_tween()
			timer.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			# The same four steps as the Tween below, so the last one ends on the same physics tick.
			for seconds in [anticipation_s, fall_s, settle_s * 0.5, settle_s * 0.5]:
				timer.tween_interval(seconds)
			timer.finished.connect(_on_settled)
		else:
			_on_settled()
		return
	if not animate:
		pivot.rotation.x = -tilt
		pivot.position.y = body_radius
		_on_settled()
		return
	var tw := pivot.create_tween()
	## Logic waits on this tween (the soul appears when it ends): it runs on physics ticks, not render frames.
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(pivot, "rotation:x", deg_to_rad(anticipation_deg), anticipation_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "rotation:x", -tilt, fall_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pivot, "position:y", body_radius, fall_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pivot, "rotation:x", -tilt + deg_to_rad(settle_deg), settle_s * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "rotation:x", -tilt, settle_s * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(_on_settled)


## Every peer (RFC-020e). Undoes lay_down(): the body is a creature again (group, layer) and the pivot gets
## back on its feet. The pivot rests at the origin with no rotation (unit.tscn). The one that took it (Captive) decides what it is while a doctor holds it.
func stand_up(body: CharacterBody3D, animate := true) -> void:
	if not laid:
		return
	var was_clip := clip_driven
	laid = false
	is_settled = false
	clip_driven = false
	dissolving = false
	_clear_fade()
	body.remove_from_group("corpse")
	body.add_to_group("unit")
	body.collision_layer = body.get("unit_layer")
	if pivot == null:
		return
	if _stand_tween:
		_stand_tween.kill()
	if not animate or was_clip:
		pivot.rotation = Vector3.ZERO
		pivot.position = Vector3.ZERO
		return
	_stand_tween = pivot.create_tween()
	_stand_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_stand_tween.tween_property(pivot, "rotation", Vector3.ZERO, stand_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_stand_tween.parallel().tween_property(pivot, "position", Vector3.ZERO, stand_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Server or solo. The spawner removes it on clients.
func dissolve(body: Node) -> void:
	if dissolving or (MpKit.is_networked() and not MpKit.is_server()):
		return
	dissolving = true
	get_tree().create_timer(dissolve_s, false, true).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free())


## Every peer: waits for the last fade_s of the dissolve and fades the body out (transparency 0 -> 1).
func _show_dissolve() -> void:
	_clear_fade()
	if not dissolving or visual == null or fade_s <= 0.0 or not visual.has_method("set_fade"):
		return
	_fade_tween = visual.create_tween()
	_fade_tween.tween_interval(maxf(dissolve_s - fade_s, 0.0))
	_fade_tween.tween_method(func(value: float) -> void: visual.call("set_fade", value), 0.0, 1.0, minf(fade_s, dissolve_s))


func _clear_fade() -> void:
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	if visual != null and visual.has_method("set_fade"):
		visual.call("set_fade", 0.0)


func _on_settled() -> void:
	is_settled = true
	settled.emit()
