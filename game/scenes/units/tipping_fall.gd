class_name TippingFall
extends Node

## A body with no death animation falls over backwards like a plank: it leans a little the other way, tips onto its
## back and settles with a small bounce. Standing up is the same fall played softly the other way. Only the model
## moves (the body, its collision and its soul stay where the simulation put them). It is for models without
## a death clip.

## The model that tips over (feet at its origin): the unit's `Tilt/Mesh`.
@export var mesh: Node3D
@export_group("Fall")
## How far the body leans forward before it falls (degrees).
@export_range(0.0, 30.0, 0.5, "suffix:deg") var anticipation_deg := 9.0
## Seconds of that lean.
@export_range(0.0, 1.0, 0.01, "suffix:s") var anticipation_s := 0.14
## How far it tips in the end: 90 lies flat on its back.
@export_range(0.0, 120.0, 1.0, "suffix:deg") var fall_deg := 90.0
## Seconds of the fall itself.
@export_range(0.0, 2.0, 0.01, "suffix:s") var fall_s := 0.55
## How far the body bounces back when it lands (degrees).
@export_range(0.0, 20.0, 0.5, "suffix:deg") var settle_deg := 6.0
## Seconds of the landing bounce.
@export_range(0.0, 1.0, 0.01, "suffix:s") var settle_s := 0.22
## Seconds the body takes to get back on its feet when it is not instant.
@export_range(0.0, 3.0, 0.05, "suffix:s") var stand_s := 0.9

var _tween: Tween


## The body lies from now on. `radius` lifts the model so half of it does not sink into the floor. `animate` false: it
## already lies (it joined late).
func lay_down(radius: float, animate := true) -> void:
	if mesh == null:
		return
	_stop()
	var tilt := deg_to_rad(fall_deg)
	if not animate:
		mesh.rotation.x = -tilt
		mesh.position.y = radius
		return
	_tween = mesh.create_tween()
	(
		_tween
		. tween_property(mesh, "rotation:x", deg_to_rad(anticipation_deg), anticipation_s)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.tween_property(mesh, "rotation:x", -tilt, fall_s).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	(
		_tween
		. parallel()
		. tween_property(mesh, "position:y", radius, fall_s)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. tween_property(mesh, "rotation:x", -tilt + deg_to_rad(settle_deg), settle_s * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(mesh, "rotation:x", -tilt, settle_s * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)


## The body is upright again. `animate` false: at once.
func stand_up(animate := true) -> void:
	if mesh == null:
		return
	_stop()
	if not animate:
		mesh.rotation = Vector3.ZERO
		mesh.position = Vector3.ZERO
		return
	_tween = mesh.create_tween()
	(
		_tween
		. tween_property(mesh, "rotation", Vector3.ZERO, stand_s)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_tween
		. parallel()
		. tween_property(mesh, "position", Vector3.ZERO, stand_s)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if mesh != null
		else PackedStringArray(["Assign the model that tips over in `mesh`."])
	)
