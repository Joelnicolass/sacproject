@tool
class_name UnitSounds
extends BodySounds

## RFC-052 052c (F362): child of units/unit.tscn. A creature's sounds from what every peer already has (replicated state):
## - `summon` when its mode becomes SUMMONING, or when it is born in it (a summon spawned on a client);
## - `swing` and `shoot` on UnitBody.swung / shot_started (the setters of the replicated `swings` and `shots`);
## - `damaged` when Health.current goes down and the body is alive (BodySounds limits it per body);
## - `death` when its mode becomes DEAD.
## Its set is data/audio/creatures/<file>.tres of the replicated `creature_tag` (SoundLibrary.creature). No set: silence.
## Remove the node to silence every creature.

@export var body: UnitBody:
	set(value):
		body = value
		update_configuration_warnings()
@export var health: Health:
	set(value):
		health = value
		update_configuration_warnings()

var _last_health := 0.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or not _open or body == null or health == null:
		return
	_last_health = health.current
	body.swung.connect(_on_swung)
	body.shot_started.connect(_on_shot_started)
	body.mode_changed.connect(_on_mode_changed)
	health.changed.connect(_on_health_changed)
	if body.mode == UnitBody.Mode.SUMMONING:
		play.call_deferred(SoundEvent.SUMMON)


func own_set() -> SoundSet:
	return SoundLibrary.creature(StringName(body.creature_tag)) if body != null else null


func anchor() -> Node3D:
	return body


func _on_swung() -> void:
	play(SoundEvent.SWING)


func _on_shot_started() -> void:
	play(SoundEvent.SHOOT)


func _on_mode_changed(was: UnitBody.Mode, now: UnitBody.Mode) -> void:
	if now == UnitBody.Mode.DEAD and was != UnitBody.Mode.DEAD:
		play(SoundEvent.DEATH)
	elif now == UnitBody.Mode.SUMMONING and was != UnitBody.Mode.SUMMONING:
		play(SoundEvent.SUMMON)


func _on_health_changed(current: float, _maximum: float) -> void:
	var dropped := current < _last_health
	_last_health = current
	if dropped and current > 0.0 and not body.is_dead():
		play_damaged()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if body == null:
		out.append("Asigná `body` (el UnitBody de esta criatura).")
	if health == null:
		out.append("Asigná `health` (su Health).")
	return out
