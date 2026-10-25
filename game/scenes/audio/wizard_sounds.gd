@tool
class_name WizardSounds
extends BodySounds

## Child of wizards/wizard_body.tscn. A wizard's sounds from replicated state:
## - `incantation` when a cast starts (Caster.cast_fx_shown goes from "" to a name; it is replicated);
## - `damaged` when Health.current goes down while alive (BodySounds limits it);
## - `death` when GhostForm.stage becomes DYING, `ghost` when it rises (RISING, or GHOST straight from another stage).
## Its set is `sounds` of the body's `wizard_type`. No set: silence.

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

var _last_health := 0.0
var _last_fx := ""
var _last_stage := GhostForm.Stage.ALIVE


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or not _open or body == null or health == null or caster == null or ghost == null:
		return
	_last_health = health.current
	_last_fx = caster.cast_fx_shown
	_last_stage = ghost.stage
	health.changed.connect(_on_health_changed)
	caster.cast_fx_changed.connect(_on_cast_fx_changed)
	ghost.stage_changed.connect(_on_stage_changed)


func own_set() -> SoundSet:
	var type: WizardType = body.wizard_type if body != null else null
	return type.sounds if type != null else null


func anchor() -> Node3D:
	return body


func _on_cast_fx_changed(type_name: String) -> void:
	var started := _last_fx.is_empty() and not type_name.is_empty()
	_last_fx = type_name
	if started:
		play(SoundEvent.INCANTATION)


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
	elif stage == GhostForm.Stage.RISING or (stage == GhostForm.Stage.GHOST and was != GhostForm.Stage.RISING):
		play(SoundEvent.GHOST)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	for pair in [[body, "body"], [health, "health"], [caster, "caster"], [ghost, "ghost"]]:
		if pair[0] == null:
			out.append("Asigná `%s`." % pair[1])
	return out
