@tool
class_name CombatGauge
extends Node

## How much fighting the player hears, from what every peer already has (no RPC, nothing written).
## - `intensity` 0..1: the creatures (group «unit») within `radius_m` of the listener
##   (SoundBus.listener_position: ListenerFocus on the local wizard) that fight, over `full_at`. A
##   creature fights when its replicated `mode` is a fighting one (CHASE, ATTACK, SHOOT: a swing is
##   shorter than a sample) or its `swings`/`shots` counters moved since the last sample.
## - Hysteresis: the combat turns on when the intensity reaches `enter` and turns off after it stays
##   under `exit` for `hold_s`, so a pause between two swings does not cut the battle music.
## - The local wizard hurt (Events.body_hurt on that wizard) keeps the battle on for
##   `wizard_damage_s`.
## `is_battle()` is either of the two; `battle_changed(on)` tells when it flips. It chooses no
## music. Sampled every `sample_every_s` of game time. With the AudioGate closed it does nothing.
## `force(value)` pins the intensity (the lab's `battle` step); `force(-1)` lets it go.

signal battle_changed(on: bool)

## The match: its `local_wizard_changed` moves this to the local wizard. Optional: the lab sets
## `wizard`.
@export var world: MatchWorld
@export var wizard: Node3D
@export_range(1.0, 500.0, 1.0, "suffix:m") var radius_m := 40.0
## Fighting creatures in range at which the intensity is 1.
@export_range(1, 64) var full_at := 4
@export_range(0.0, 1.0, 0.01) var enter := 0.4
@export_range(0.0, 1.0, 0.01) var exit := 0.15
@export_range(0.0, 120.0, 0.1, "suffix:s") var hold_s := 8.0
@export_range(0.0, 600.0, 1.0, "suffix:s") var wizard_damage_s := 120.0
@export_range(0.05, 5.0, 0.05, "suffix:s") var sample_every_s := 0.25
## UnitBody.Mode values that count as fighting.
## The group the creatures that may be fighting belong to.
@export var unit_group: StringName = &"unit"
@export
var fighting_modes: Array[int] = [UnitBody.Mode.CHASE, UnitBody.Mode.ATTACK, UnitBody.Mode.SHOOT]

var intensity := 0.0
var _open := false
var _combat := false
var _battle := false
var _clock := 0.0
var _sample_left := 0.0
var _below_since := -1.0
## Clock of the local wizard's last hit; -INF = never.
var _wizard_hit_at := -INF
var _forced := -1.0
## UnitBody instance id -> swings + shots at the last sample.
var _strokes: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open()
	if not _open:
		set_process(false)
		return
	if world != null:
		world.local_wizard_changed.connect(bind_wizard)
		if wizard == null:
			wizard = world.local_wizard()
	Events.body_hurt.connect(_on_body_hurt)


func _process(delta: float) -> void:
	_clock += delta
	_sample_left -= delta
	if _sample_left > 0.0:
		return
	_sample_left = sample_every_s
	sample()


## True while the music should be the battle's: combat near the listener, or the local wizard hurt
## lately.
func is_battle() -> bool:
	return _battle


## True while the combat part alone (the hysteresis on the intensity) is on.
func is_combat() -> bool:
	return _combat


## Seconds since the local wizard was last hurt (INF when never).
func since_wizard_hit() -> float:
	return _clock - _wizard_hit_at


## Pins the intensity at `value` (0..1) from now on; a negative value lets it be measured again.
## Samples at once.
func force(value: float) -> void:
	_forced = value
	sample()


## The local wizard whose health keeps the battle on (MatchWorld.local_wizard_changed; the lab sets
## it).
func bind_wizard(node: Node3D) -> void:
	wizard = node


## Measures now and updates the state (the lab calls it so as not to wait for the next sample).
func sample() -> void:
	if not _open:
		return
	intensity = clampf(_forced, 0.0, 1.0) if _forced >= 0.0 else measure()
	if intensity >= enter:
		_combat = true
		_below_since = -1.0
	elif intensity < exit and _combat:
		if _below_since < 0.0:
			_below_since = _clock
		if _clock - _below_since >= hold_s:
			_combat = false
			_below_since = -1.0
	else:
		_below_since = -1.0
	var on := _combat or since_wizard_hit() < wizard_damage_s
	if on != _battle:
		_battle = on
		battle_changed.emit(on)


## The intensity now, from the replicated modes of the creatures near the listener (0 without a
## listener).
func measure() -> float:
	var at: Vector3 = SoundBus.listener_position()
	if at == Vector3.INF:
		return 0.0
	var fighting := 0
	var reach := radius_m * radius_m
	var strokes := {}
	for node in get_tree().get_nodes_in_group(unit_group):
		var unit := node as UnitBody
		if unit == null or not unit.is_inside_tree():
			continue
		var id := unit.get_instance_id()
		strokes[id] = unit.weapons.swings + unit.weapons.shots
		var struck := _strokes.has(id) and int(_strokes[id]) != int(strokes[id])
		if (
			(struck or fighting_modes.has(int(unit.mode)))
			and unit.global_position.distance_squared_to(at) <= reach
		):
			fighting += 1
	_strokes = strokes
	return clampf(float(fighting) / float(maxi(full_at, 1)), 0.0, 1.0)


func _on_body_hurt(body: Node3D, _lost: float, _current: float, _maximum: float) -> void:
	if body != null and body == wizard:
		_wizard_hit_at = _clock
		sample()
