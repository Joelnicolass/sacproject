@tool
class_name ActorLightBudget
extends LookLayer

## Actor-lights layer of the rig: a map can hold hundreds of `ActorLight`s (every unit, wizard and spell) but only
## `LookQuality.actor_max_lights` of them are on. Every `refresh_s` it ranks the lights by
## `priority / max(distance to the camera, min_distance_m)` and turns the best ones on. A light that is on keeps its place
## unless another beats it by `hysteresis` (no flicker between two almost equal lights). Lights past their own fade
## distance and lights whose owner is gone (`lit` false) never take a place.
## Classic mode (null profile), a hidden layer and a cap of 0 leave every light off. Presentation only: freed with the rig
## in a headless or dedicated process.

const GROUP := &"actor_light_budget"

## Cap while no preset has been handed over (a rig without quality).
@export_range(0, 64) var fallback_max_lights: int = 12
@export_range(0.05, 2.0, 0.05, "suffix:s") var refresh_s: float = 0.2
## A light that is on counts this many times its score against the ones that are off.
@export_range(1.0, 2.0, 0.05) var hysteresis: float = 1.25
## Closer than this to the camera counts as this distance in the score (no division by ~0).
@export_range(0.5, 50.0, 0.5, "suffix:m") var min_distance_m: float = 4.0

## The atmosphere whose `night` dims the lights (0 = day, 1 = full night); empty = they keep their energy.
@export var atmosphere: Atmosphere

var _max_lights := -1
var _night := 0.0
var _enabled := true
var _clock := 0.0


class _Entry:
	var score: float
	var light: ActorLight


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if _max_lights < 0:
		_max_lights = fallback_max_lights
	visibility_changed.connect(rank)
	if atmosphere != null:
		_night = atmosphere.current().night
		atmosphere.changed.connect(_on_atmosphere)
	set_process(true)


func apply_look(profile: LookProfile, _rig: LookRig) -> void:
	_enabled = profile != null
	rank()


func apply_quality(preset: LookQuality) -> void:
	_max_lights = preset.actor_max_lights if preset else fallback_max_lights
	rank()


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= refresh_s:
		rank()


## The atmosphere's night now (0 when there is no atmosphere).
func night() -> float:
	return _night


func _on_atmosphere(sample: AtmosphereSample) -> void:
	_night = sample.night
	rank()


func max_lights() -> int:
	return maxi(_max_lights, 0)


## Re-ranks now (the tick calls it; the lab and quality changes call it too).
func rank() -> void:
	_clock = 0.0
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var cap := _max_lights if _enabled and is_visible_in_tree() else 0
	var camera := get_viewport().get_camera_3d()
	var entries: Array[_Entry] = []
	for node in get_tree().get_nodes_in_group(ActorLight.GROUP):
		var light := node as ActorLight
		light.set_night(_night)
		if light.always_on:
			light.set_budget_on(true)
			continue
		var distance := (
			light.global_position.distance_to(camera.global_position) if camera else min_distance_m
		)
		if cap <= 0 or not light.is_lit() or distance > _reach(light):
			light.set_budget_on(false)
			continue
		var entry := _Entry.new()
		entry.light = light
		entry.score = (
			light.priority
			/ maxf(distance, min_distance_m)
			* (hysteresis if light.is_budget_on() else 1.0)
		)
		entries.append(entry)
	entries.sort_custom(func(a: _Entry, b: _Entry) -> bool: return a.score > b.score)
	for i in entries.size():
		entries[i].light.set_budget_on(i < cap)


## Past this distance the light has faded out by itself: it is not worth a place.
func _reach(light: ActorLight) -> float:
	return (
		light.distance_fade_begin + light.distance_fade_length
		if light.distance_fade_enabled
		else INF
	)
