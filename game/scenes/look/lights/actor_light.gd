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

## Off by default on units (the original has no light pool under bodies; only the wizard carries a reveal light); a human can turn it on in the inspector.
@export var enabled := true

## The budget never switches it off (the wizard's reveal light: a tight, neutral pool that lifts the ground around the wizard). Not counted among the budget's lights.
@export var always_on := false

var _lit := true
var _budget_on := true
var _full_energy := 1.0
var _fade: Tween


func _ready() -> void:
	if LookRig.is_presentationless():
		queue_free()
		return
	_full_energy = light_energy
	# With a budget around the light waits for its verdict (a hundred new lights must not all flash on for a moment).
	_budget_on = always_on or get_tree().get_first_node_in_group(ActorLightBudget.GROUP) == null
	add_to_group(GROUP)
	_refresh()


## The thing the light belongs to is alive (true) or gone (false). `fade_s` > 0 takes that long to go out / come back.
func set_lit(on: bool, fade_s := 0.0) -> void:
	_stop_fade()
	if fade_s <= 0.0 or not is_inside_tree():
		_lit = on
		light_energy = _full_energy
		_refresh()
		return
	if on:
		_lit = true
		light_energy = 0.0
		_refresh()
	_fade = create_tween()
	_fade.tween_property(self, "light_energy", _full_energy if on else 0.0, fade_s)
	if not on:
		_fade.finished.connect(_on_faded_out)


## Sets `light_energy` to the scene's energy times `fraction` (a light that grows with something, like a rising tower's edge).
## Stops a running fade. The only other writer of `light_energy` is set_lit.
func set_level(fraction: float) -> void:
	_stop_fade()
	light_energy = _full_energy * maxf(fraction, 0.0)


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
	light_energy = _full_energy
	_refresh()


func _stop_fade() -> void:
	if _fade:
		_fade.kill()
		_fade = null


func _refresh() -> void:
	visible = enabled and _lit and _budget_on
