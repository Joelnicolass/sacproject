class_name CorpseLook
extends Node

## How a death looks. A model with a physical skeleton falls like a rag doll (RagdollDriver); one without it plays its death
## animation once; one with neither tips over (TippingFall). The corpse fades out while it dissolves, and a creature that a
## Convert doctor brings back fades in where it lies. It only listens to Corpse and never writes to the simulation:
## nothing in the sim reads it.

## The unit that dies.
@export var body: UnitBody
## The simulation side of the death: tells when the body lies, dissolves or stands up.
@export var corpse: Corpse
## The model that is drawn and faded.
@export var visual: BodyVisual
## How a body with a physical skeleton falls.
@export var ragdoll: RagdollDriver
## How a body with no death animation falls.
@export var tipping: TippingFall
## The unit's light: goes out with the corpse and comes back when it stands up.
@export var light: ActorLight
## true: a model that has a death animation plays it even if it has a physical skeleton.
@export var prefer_clip := false
@export_group("Fades")
## Seconds a dissolving corpse takes to fade out (never longer than the dissolve itself).
@export_range(0.0, 5.0, 0.05, "suffix:s") var corpse_fade_s := 1.5
## Seconds a revived creature takes to fade in, where it lies.
@export_range(0.0, 3.0, 0.05, "suffix:s") var revive_fade_s := 0.6

## The body lies as a ragdoll (so it stands up by resetting it).
var _ragdolled := false


func _ready() -> void:
	corpse.laid_down.connect(_on_laid_down)
	corpse.dissolving_changed.connect(_on_dissolving_changed)
	corpse.stood_up.connect(_on_stood_up)
	if corpse.dissolving:
		_on_dissolving_changed(true)


## The body died. Who lays it down, in this order: the physical skeleton, the death clip, the tip-over. A body that joined
## late (`instant`) never ragdolls: there is no fall to play, so it lies at once.
func _on_laid_down(instant: bool) -> void:
	if _can_ragdoll(instant):
		_ragdolled = true
		ragdoll.set_pose(RagdollDriver.Pose.FALL, -body.facing_flat())
	elif corpse.clip_driven:
		if instant:
			body.clip_pose.play_ended(corpse.death_role)
		else:
			body.clip_pose.play(corpse.death_role, true)
	else:
		tipping.lay_down(visual.body_radius(), not instant)


func _can_ragdoll(instant: bool) -> bool:
	if instant or prefer_clip and corpse.clip_driven:
		return false
	var model := visual.rig.model_root() if visual.rig != null else null
	if model != null:
		ragdoll.bind_model(model)
		## WORKAROUND: unit.tscn wires the driver's clip_pose socket in 055a-5 s3; until then the body hands it over.
		if ragdoll.clip_pose == null:
			ragdoll.clip_pose = body.clip_pose
	return ragdoll.available()


func _on_dissolving_changed(on: bool) -> void:
	if on:
		visual.fade_to(1.0, minf(corpse_fade_s, corpse.dissolve_s))
	else:
		visual.set_fade(0.0)
	_light_to(not on, minf(corpse_fade_s, corpse.dissolve_s))


## A Convert doctor revived the body: it stands in its place and appears out of thin air.
func _on_stood_up() -> void:
	if _ragdolled:
		_ragdolled = false
		ragdoll.set_pose(RagdollDriver.Pose.OFF)
		body.clip_pose.play("idle", true)
	tipping.stand_up(false)
	visual.set_fade(1.0)
	visual.fade_to(0.0, revive_fade_s)
	_light_to(true, revive_fade_s)


func _light_to(on: bool, seconds: float) -> void:
	if light:
		light.set_lit(on, seconds)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for socket in ["body", "corpse", "visual", "ragdoll", "tipping"]:
		if get(socket) == null:
			warnings.append("Assign `%s`." % socket)
	return warnings
