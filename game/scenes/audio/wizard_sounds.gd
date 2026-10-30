@tool
class_name WizardSounds
extends BodySounds

## Child of wizards/wizard_body.tscn. A wizard's sounds from replicated state:
## - the chant: `incantation` when a cast starts (Caster.cast_changed goes to casting, from its
##   replicated `cast_fx_shown`), and again `chant_gap_s` after the longest clip of the cue ends,
##   while the cast lasts. Once the cast ends or is cut nothing new starts; the clip that is playing
##   is never cut. Every cast chants, spells and summons alike;
## - `damaged` when Health.current goes down while alive (BodySounds limits it);
## - `death` when GhostForm.stage becomes DYING, `ghost` when it rises (RISING, or GHOST straight
##   from another stage).
## Its set is the `sounds` of the look the body wears (BodyMount.look, the appearance of his body
## scene). No set: silence. Does not decide when a cast starts or ends (Caster) nor pick the clip
## (SoundBus draws one of the cue's streams).

@export var body: WizardBody:
	set(value):
		body = value
		update_configuration_warnings()
@export var health: Health:
	set(value):
		health = value
		update_configuration_warnings()
@export var caster: Caster:
	set(value):
		caster = value
		update_configuration_warnings()
@export var ghost: GhostForm:
	set(value):
		ghost = value
		update_configuration_warnings()
## Silence between two clips of the chant, in game seconds.
@export_range(0.0, 2.0, 0.01, "suffix:s") var chant_gap_s := 0.1

var _last_health := 0.0
## Game second the next clip of the chant starts (only while chanting).
var _next_chant_s := 0.0
var _was_casting := false
var _last_stage := GhostForm.Stage.ALIVE


func _ready() -> void:
	super._ready()
	set_physics_process(false)
	if (
		Engine.is_editor_hint()
		or not _open
		or body == null
		or health == null
		or caster == null
		or ghost == null
	):
		return
	_last_health = health.current
	_was_casting = caster.is_casting()
	_last_stage = ghost.stage
	health.changed.connect(_on_health_changed)
	caster.cast_changed.connect(_on_cast_changed)
	ghost.stage_changed.connect(_on_stage_changed)


func own_set() -> SoundSet:
	return body.mount.sounds() if body != null and body.mount != null else null


func anchor() -> Node3D:
	return body


func _on_cast_changed(casting: bool, _fx: ParticleType) -> void:
	var started := casting and not _was_casting
	_was_casting = casting
	if started:
		_chant()
	set_physics_process(casting and _next_chant_s > 0.0)


## While the cast lasts, the next clip of the chant when the previous one is over (game time:
## follows --fixed-fps).
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or caster == null or not caster.is_casting():
		set_physics_process(false)
		return
	if game_seconds() >= _next_chant_s:
		_chant()


## One clip of the chant now, and when the next one starts (0 = no cue: the chain stops).
func _chant() -> void:
	var cue := cue_for(SoundEvent.INCANTATION)
	if cue == null:
		_next_chant_s = 0.0
		set_physics_process(false)
		return
	play(SoundEvent.INCANTATION)
	_next_chant_s = game_seconds() + cue.longest_s() + chant_gap_s


func _on_health_changed(current: float, _maximum: float) -> void:
	var dropped := current < _last_health
	_last_health = current
	if dropped and current > 0.0 and ghost.stage == GhostForm.Stage.ALIVE:
		play_damaged()


func _on_stage_changed(stage: GhostForm.Stage) -> void:
	var was := _last_stage
	_last_stage = stage
	if stage == GhostForm.Stage.DYING:
		play(SoundEvent.DEATH)
	elif (
		stage == GhostForm.Stage.RISING
		or (stage == GhostForm.Stage.GHOST and was != GhostForm.Stage.RISING)
	):
		play(SoundEvent.GHOST)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	for pair in [[body, "body"], [health, "health"], [caster, "caster"], [ghost, "ghost"]]:
		if pair[0] == null:
			out.append("Assign `%s`." % pair[1])
	return out
