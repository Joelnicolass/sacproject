extends Node

## Debug only (056): K (`debug_hit`) hits the next of `targets` for `hit_fraction` of its maximum as a splash spell of slot 1;
## two K bring one down, then the next. `report` says what the last fall did (bursts, fount, shake, the BuildingBreak sounds in the SoundLog) for the flow.

@export var targets: Array[MapBuilding] = []
@export_range(0.05, 1.0, 0.05) var hit_fraction := 0.5
@export var mods := 0
## Read only for the report.
@export var fount: ManafountBody
@export var shake: CameraShake

var broke := 0
var report := ""
var _next := 0


func _ready() -> void:
	for target in targets:
		for child in target.get_children():
			if child is StructureBreak:
				(child as StructureBreak).broke.connect(func(_at: Vector3) -> void: broke += 1)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"debug_hit") or _next >= targets.size():
		return
	var target := targets[_next]
	target.health.damage_typed(hit_fraction * target.health.maximum, Health.SPLASH_SPELL, 1, false, false, mods)
	if target.is_destroyed():
		_next += 1
	var sounds := 0
	if SoundBus.sound_log != null:
		for entry in SoundBus.sound_log.entries():
			sounds += 1 if StringName(entry.get("emitter", &"")) == &"BuildingBreak" else 0
	report = "%s health=%.0f destroyed=%s broke=%d fount_free=%s trauma=%.2f explosion_sounds=%d" % [target.name,
			target.health.current, target.is_destroyed(), broke, fount.is_free() if fount != null else false,
			shake.trauma if shake != null else -1.0, sounds]
	print("break_key: ", report)
