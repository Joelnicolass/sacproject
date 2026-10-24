@tool
class_name WallTouch
extends Node

## What a SpellWall does to the creatures and wizards inside it, once its casting time is over. One script, many walls: damage and mana
## drained every tick while a body is inside (Firewall burns, Wailing Wall saps), and, no more than once per `cooldown_s` for each body,
## a touch: a hit, a stun, a slowdown, a state (Wall of Spikes stuns, hurts and slows; Wailing Wall slows; Vinewall ties). The knobs of
## the scene say which. It does not move, grow or draw the wall (SpellWall and the look) nor make the states it lays (Vined, Stunned,
## PaceFactors, Health). Server (or solo) only.

## A body took its touch this tick (a hit, a stun, a state or a slowdown). Server only.
signal touched(body: Node3D)

enum Affects { EVERYBODY, NOT_ALLIES }

@export var wall: SpellWall
@export var affects := Affects.EVERYBODY
## The wall hurts only while it stands (Wall of Spikes, Vinewall); off: also while it sinks (Firewall, Wailing Wall).
@export var only_while_standing := false
## Only the part of the thickness within this fraction of the axis touches (Wall of Spikes 0.4, Vinewall 0.35); 0 = all of it.
@export_range(0.0, 1.0, 0.05) var core_fraction := 0.0
@export_group("Every tick")
## The spell's `damage` is dealt per second (Firewall); or this much per second (0 = none).
@export var spell_damage_per_s := false
@export var damage_per_s := 0.0
## The damage ramps 0 to 1 over this long (0 = no ramp), from `ramp_start_s` (negative = once the wall is at full height); one ramp for the whole wall.
@export_range(0.0, 20.0, 0.1, "suffix:s") var ramp_s := 0.0
@export var ramp_start_s := -1.0
@export var kind: StringName = Health.DIRECT_SPELL
@export var pierce_shield := false
@export var mods := 0
## Fraction of the body's maximum mana drained per second (Wailing Wall 1).
@export_range(0.0, 1.0, 0.05) var mana_drain_per_s := 0.0
@export_group("Touch")
## Seconds a body is left alone after a touch (0 = it touches every tick).
@export_range(0.0, 60.0, 0.5, "suffix:s") var cooldown_s := 0.0
## While the state is still on the body the wait starts over (Vinewall).
@export var renew_while_afflicted := false
## The spell's `damage` is dealt once per touch (Wall of Spikes).
@export var spell_damage_on_touch := false
@export_range(0.0, 60.0, 0.0001, "suffix:s") var stun_cooldown_s := 0.0
## Pace factor and how long it lasts (1 = none), under the name `pace_source`.
@export_range(0.05, 1.0, 0.05) var slow_factor := 1.0
@export_range(0.0, 60.0, 0.5, "suffix:s") var slow_s := 0.0
@export var pace_source: StringName = &"wall"
## The state laid with the wall's remaining time as a cap (Grasping Vines).
@export var affliction: AfflictionType
## Played on every peer at the body's feet (`target` and `ticks` go with `hit_params`): the spike that rises, the spirit that orbits.
@export var hit_scene: PackedScene
@export var hit_params: Dictionary = {}
@export var stunned_path := NodePath("Afflictions/Stunned")

var _until := {}
var _slows := {}


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if wall != null else PackedStringArray(["Falta el SpellWall."])

func _ready() -> void:
	if Engine.is_editor_hint() or not multiplayer.is_server():
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if wall == null or not wall.armed or wall.spell == null:
		return
	var now := MatchClock.now()
	_end_slows(now)
	if only_while_standing and wall.vanish_at >= 0:
		return
	for body in wall.bodies_inside():
		if affects == Affects.NOT_ALLIES and SideRelations.stance(wall.from_slot, int(body.get("owner_slot"))) == SideRelations.Stance.ALLY:
			continue
		if core_fraction > 0.0 and absf(WallRules.lateral(body.global_position, wall.center, wall.direction)) >= core_fraction * wall.thickness_m():
			continue
		_every_tick(body)
		_touch(body, now)


func _every_tick(body: Node3D) -> void:
	var health := Health.of(body)
	var per_s := float(wall.spell.damage) if spell_damage_per_s else damage_per_s
	if per_s > 0.0 and health != null:
		var scale := wall.ramp(ramp_start_s, ramp_s) if ramp_s > 0.0 else 1.0
		health.damage_typed(per_s * scale / MatchClock.TICKS_PER_SECOND_F, kind, wall.from_slot, false, pierce_shield, mods)
	var mana := ManaPool.of(body)
	if mana_drain_per_s > 0.0 and mana != null:
		mana.drain(mana.maximum * mana_drain_per_s / MatchClock.TICKS_PER_SECOND_F)


func _touch(body: Node3D, now: int) -> void:
	if stun_cooldown_s <= 0.0 and not spell_damage_on_touch and slow_factor >= 1.0 and affliction == null and hit_scene == null:
		return
	var id := body.get_instance_id()
	var wait := MatchClock.ticks_for(cooldown_s)
	if int(_until.get(id, 0)) > now:
		if renew_while_afflicted and affliction != null and _afflicted(body):
			_until[id] = now + wait
		return
	if affliction != null and not _lay(body):
		return
	_until[id] = now + wait
	var stunned := body.get_node_or_null(stunned_path) as Stunned
	if stun_cooldown_s > 0.0 and stunned != null:
		stunned.stun_with_cooldown(MatchClock.ticks_for(stun_cooldown_s))
	var health := Health.of(body)
	if spell_damage_on_touch and health != null:
		health.damage_typed(float(wall.spell.damage), Health.DIRECT_SPELL, wall.from_slot)
	var pace := PaceFactors.of(body)
	if slow_factor < 1.0 and pace != null:
		pace.set_factor(pace_source, slow_factor)
		_slows[id] = [body, now + MatchClock.ticks_for(slow_s)]
	if hit_scene != null:
		var params := hit_params.duplicate()
		params["target"] = str(body.get_path())
		params["ticks"] = MatchClock.ticks_for(slow_s)
		params["seed"] = id ^ now
		FxBus.broadcast_scene(hit_scene.resource_path, body.global_position, params)
	touched.emit(body)


## Ties the body with what is left of the wall's time: the state's own duration, but never longer.
func _lay(body: Node3D) -> bool:
	var state := _state_of(body)
	if state == null or Afflictions.of(body).cc_protected():
		return false
	var left_s := wall.spell.duration_s - float(wall.age - wall.grow_ticks) / MatchClock.TICKS_PER_SECOND_F
	return state.lay_within(wall.spell, wall.from_slot, maxf(0.0, left_s))


func _afflicted(body: Node3D) -> bool:
	var state := _state_of(body)
	return state != null and state.is_on()


func _state_of(body: Node3D) -> Affliction:
	var afflictions := Afflictions.of(body)
	return afflictions.child_for(affliction) if afflictions != null else null


func _end_slows(now: int) -> void:
	for id in _slows.keys():
		var entry: Array = _slows[id]
		if int(entry[1]) > now and is_instance_valid(entry[0]):
			continue
		var pace := PaceFactors.of(entry[0]) if is_instance_valid(entry[0]) else null
		if pace != null:
			pace.clear(pace_source)
		_slows.erase(id)
