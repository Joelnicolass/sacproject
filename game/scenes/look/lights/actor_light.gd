class_name ActorLight
extends OmniLight3D

## The small light a unit, a wizard or a spell carries (`Light` child of `unit.tscn`, `wizard_body.tscn`, the spell
## projectiles). No shadows, short range, fades out at 60 m + 20 m. Many of them exist at once: ActorLightBudget turns
## the best few on (`set_budget_on`); the rest stay dark. This node owns its `visible`: it is on only when it is
## `lit` (the thing it belongs to is alive) AND the budget wants it. Without a budget (F6, the editor) it stays on.
## Presentation only: freed in a headless or dedicated process.

const GROUP := &"actor_lights"

## Weight against the other lights when the budget picks the best ones: a wizard 4, a spell 3, a unit 1.
@export_range(0.1, 16.0, 0.1) var priority := 1.0

## How much of its energy the light keeps in full night (1 = all, 0 = none); in between it follows the atmosphere's `night`
## (ActorLightBudget hands it over). By day it changes nothing. The wizard's reveal light drops to 0.4 so it does not outshine the night.
@export_range(0.0, 1.0, 0.01) var night_energy := 1.0

## Off by default on units (no light pool under bodies; only the wizard carries a reveal light); a human can turn it on in the inspector.
@export var enabled := true

## The budget never switches it off (the wizard's reveal light: a tight, neutral pool that lifts the ground around the wizard). Not counted among the budget's lights.
@export var always_on := false

var _lit := true
var _budget_on := true
var _full_energy := 1.0
## The three factors of `light_energy` (see _apply_energy): fade in/out, the level a caller asked for, the atmosphere's night 0..1.
var _fade_k := 1.0
var _level := 1.0
var _night := 0.0
var _fade: Tween


func _ready() -> void:
	if LookRig.is_presentationless():
		queue_free()
		return
	_full_energy = light_energy
	# With a budget around the light waits for its verdict (a hundred new lights must not all flash on for a moment).
	_budget_on = always_on or get_tree().get_first_node_in_group(ActorLightBudget.GROUP) == null
	var budget := get_tree().get_first_node_in_group(ActorLightBudget.GROUP) as ActorLightBudget
	if budget != null:
		_night = budget.night()
	add_to_group(GROUP)
	_apply_energy()
	_refresh()


## The thing the light belongs to is alive (true) or gone (false). `fade_s` > 0 takes that long to go out / come back.
func set_lit(on: bool, fade_s := 0.0) -> void:
	_stop_fade()
	_level = 1.0
	if fade_s <= 0.0 or not is_inside_tree():
		_lit = on
		_fade_k = 1.0
		_apply_energy()
		_refresh()
		return
	if on:
		_lit = true
		_fade_k = 0.0
		_apply_energy()
		_refresh()
	_fade = create_tween()
	_fade.tween_method(_set_fade, _fade_k, 1.0 if on else 0.0, fade_s)
	if not on:
		_fade.finished.connect(_on_faded_out)


## Sets `light_energy` to the scene's energy times `fraction` (a light that grows with something, like a rising tower's edge).
## Stops a running fade.
func set_level(fraction: float) -> void:
	_stop_fade()
	_level = maxf(fraction, 0.0)
	_apply_energy()


## The atmosphere's night, 0 (day) to 1 (full night): the light keeps `lerp(1, night_energy, night)` of its energy.
## Called by ActorLightBudget only.
func set_night(night: float) -> void:
	_night = night
	_apply_energy()


func is_lit() -> bool:
	return _lit


## Called by ActorLightBudget only.
func set_budget_on(on: bool) -> void:
	_budget_on = on
	_refresh()


func is_budget_on() -> bool:
	return _budget_on


func _on_faded_out() -> void:
	_lit = false
	_fade_k = 1.0
	_level = 1.0
	_apply_energy()
	_refresh()


func _set_fade(k: float) -> void:
	_fade_k = k
	_apply_energy()


## The only writer of `light_energy`: scene energy x fade x level x the night's dimming (x1 exactly by day).
func _apply_energy() -> void:
	light_energy = _full_energy * _fade_k * _level * lerpf(1.0, night_energy, _night)


func _stop_fade() -> void:
	if _fade:
		_fade.kill()
		_fade = null


func _refresh() -> void:
	visible = enabled and _lit and _budget_on
