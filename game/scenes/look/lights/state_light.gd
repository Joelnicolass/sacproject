class_name StateLight
extends ActorLight

## The glow of something that comes and goes: a shield, a state of a body, a zone, a carrier. It stays dark until its owner says "on"
## (`show_lit`, connected in the scene to the owner's `shown_changed`, or by the zone's phase, or at once with `lit_on_ready`), fades in,
## and fades out when the owner says "off". Being dark it takes no place in the ActorLightBudget. It does not decide when the thing it
## belongs to starts or ends, and it casts no shadow (ActorLight). It is in the budget's group only while it shines: a hundred
## dormant ones (every unit carries a Healing Aura) cost the ranking nothing. Presentation only: freed with the rig in a headless process.
## A light under something that frees itself in one go (a carrier, a vortex) goes out with it: the fade-out needs an "off" first.

## Seconds to go from dark to its energy / from its energy to dark.
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in_s := 0.3
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out_s := 0.6
## Lights up the moment it enters the tree, for what lives exactly as long as the effect (the mole, the vortex, a spirit).
@export var lit_on_ready := false
@export_group("Zone")
## A zone it follows: on from the phase `from_phase` to `to_phase` (inclusive), on every peer. Empty = it follows `show_lit` or `lit_on_ready`.
@export var zone: GroundZone
@export var from_phase := GroundZone.Phase.CASTING
@export var to_phase := GroundZone.Phase.ACTIVE

## What the owner asked for last (an "on" can arrive before the node is ready, from the scene's connections).
var _wanted := false
## What the light is doing now (on or going out), so a repeated "on" does not restart the fade.
var _applied := false
var _started := false


func _ready() -> void:
	super()
	if is_queued_for_deletion():
		return
	set_lit(false)
	remove_from_group(GROUP)
	_started = true
	if zone != null:
		zone.phase_changed.connect(follow_phase)
		follow_phase(zone.phase)
	elif lit_on_ready or _wanted:
		show_lit(true)


## The owner went on (true) or off (false): the light fades in or out.
func show_lit(on: bool) -> void:
	_wanted = on
	if not _started or is_queued_for_deletion() or on == _applied:
		return
	_applied = on
	if on:
		add_to_group(GROUP)
	set_lit(on, fade_in_s if on else fade_out_s)
	if on:
		_ask_for_a_place()
	elif fade_out_s <= 0.0:
		remove_from_group(GROUP)


## The zone entered `phase`: lit while it is inside the window.
func follow_phase(phase: int) -> void:
	show_lit(in_window(phase))


func in_window(phase: int) -> bool:
	return phase >= from_phase and phase <= to_phase


## The budget ranks every 0.2 s; a light that starts to shine asks for a place now, so it does not wait dark.
func _ask_for_a_place() -> void:
	var budget := get_tree().get_first_node_in_group(ActorLightBudget.GROUP) as ActorLightBudget
	if budget != null:
		budget.rank()


func _on_faded_out() -> void:
	super()
	if not _applied:
		remove_from_group(GROUP)
