class_name CorpseLook
extends Node

## How a death looks. A creature with a death animation plays it once; one without it tips over (TippingFall). The
## corpse fades out while it dissolves, and a creature that a Convert doctor brings back fades in where it lies. It
## only listens to Corpse and never writes to the simulation: nothing in the sim reads it.

## The unit that dies.
@export var body: UnitBody
## The simulation side of the death: tells when the body lies, dissolves or stands up.
@export var corpse: Corpse
## The model that is drawn and faded.
@export var visual: BodyVisual
## How a body with no death animation falls.
@export var tipping: TippingFall
@export_group("Fades")
## Seconds a dissolving corpse takes to fade out (never longer than the dissolve itself).
@export_range(0.0, 5.0, 0.05, "suffix:s") var corpse_fade_s := 1.5
## Seconds a revived creature takes to fade in, where it lies.
@export_range(0.0, 3.0, 0.05, "suffix:s") var revive_fade_s := 0.6

var _fade: Tween


func _ready() -> void:
	corpse.laid_down.connect(_on_laid_down)
	corpse.dissolving_changed.connect(_on_dissolving_changed)
	corpse.stood_up.connect(_on_stood_up)
	if corpse.dissolving:
		_on_dissolving_changed(true)


## The body died. With a death clip, the clip lays it down; without one, the model tips over.
func _on_laid_down(instant: bool) -> void:
	if corpse.clip_driven:
		if instant:
			body.clip_pose.play_ended(corpse.death_role)
		else:
			body.clip_pose.play(corpse.death_role, true)
	else:
		tipping.lay_down(visual.body_radius(), not instant)


func _on_dissolving_changed(on: bool) -> void:
	_stop_fade()
	if on:
		_fade_to(1.0, minf(corpse_fade_s, corpse.dissolve_s))
	else:
		visual.set_fade(0.0)


## A Convert doctor revived the body: it stands in its place and appears out of thin air.
func _on_stood_up() -> void:
	tipping.stand_up(false)
	_stop_fade()
	visual.set_fade(1.0)
	_fade_to(0.0, revive_fade_s)


func _fade_to(target: float, seconds: float) -> void:
	if seconds <= 0.0:
		visual.set_fade(target)
		return
	_fade = create_tween()
	_fade.tween_method(visual.set_fade, 1.0 - target, target, seconds)


func _stop_fade() -> void:
	if _fade:
		_fade.kill()
		_fade = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for socket in ["body", "corpse", "visual", "tipping"]:
		if get(socket) == null:
			warnings.append("Assign `%s`." % socket)
	return warnings
