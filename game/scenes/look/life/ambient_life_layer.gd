@tool
class_name AmbientLifeLayer
extends LookLayer

## The ambient life layer of the rig: the god's swarms in the air around the camera (a fixed pool, `air_slots`) and,
## in each of the map's LifeSpots, the swarm of its habitat, both by the hour and the weather of the atmosphere's
## sample. It places no spot (they are nodes of the map). Hidden, without a look or at density 0 (low quality) nothing
## shows. Presentation only: freed with the rig in a headless or dedicated process.

## The rig's atmosphere layer.
@export var atmosphere: Atmosphere
## The map's `LifeSpots` (its children are LifeSpot). Empty = only the air life.
@export var spots: Node3D
## The pool of air swarms (Air1..Air3 under the FollowCamera): slot i shows the look's `air[i]`.
@export var air_slots: Array[GPUParticles3D] = []

var _set: AmbientLifeSet
var _density := 1.0
var _shown: Array[AmbientSwarm] = []
var _since_log := 0.0


func _ready() -> void:
	visibility_changed.connect(_refresh)
	if atmosphere:
		atmosphere.changed.connect(_on_atmosphere_changed)
	set_process(not Engine.is_editor_hint() and DebugLog.on(&"life"))


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_set = profile.life if profile else null
	_density = rig.quality_preset.life_density_scale if rig.quality_preset else 1.0
	update_configuration_warnings()
	_refresh()


func apply_quality(preset: LookQuality) -> void:
	_density = preset.life_density_scale if preset else 1.0
	_refresh()


func _process(delta: float) -> void:
	_since_log += delta
	if _since_log >= 10.0:
		_since_log = 0.0
		if DebugLog.on(&"life"): print("vida spots activos %d/%d" % [_active_spots(), _spot_nodes().size()])


func _on_atmosphere_changed(sample: AtmosphereSample) -> void:
	if _choice(sample) != _shown:
		_refresh()


## Which swarm each air slot and each spot shows now, recomputed from (look, density, visible, sample). Idempotent.
func _refresh() -> void:
	var sample := atmosphere.current() if atmosphere else AtmosphereSample.neutral()
	_shown = _choice(sample)
	for i in air_slots.size():
		_show_air(air_slots[i], _shown[i])
	var on := _set != null and _density > 0.0 and is_visible_in_tree()
	for spot in _spot_nodes():
		spot.show_swarm(_set.swarm_for(spot.habitat, sample) if on else null, _density)


## The air swarm of each slot (null = off), then the swarm of each spot: what `_refresh` would draw.
func _choice(sample: AtmosphereSample) -> Array[AmbientSwarm]:
	var out: Array[AmbientSwarm] = []
	var on := _set != null and _density > 0.0 and is_visible_in_tree()
	for i in air_slots.size():
		var swarm: AmbientSwarm = _set.air[i] if on and i < _set.air.size() else null
		out.append(swarm if swarm and swarm.shows_in(sample) else null)
	for spot in _spot_nodes():
		out.append(_set.swarm_for(spot.habitat, sample) if on else null)
	return out


func _show_air(slot: GPUParticles3D, swarm: AmbientSwarm) -> void:
	if slot == null:
		return
	slot.emitting = swarm != null
	slot.visible = swarm != null
	if swarm == null:
		return
	slot.process_material = swarm.process_material
	slot.draw_pass_1 = swarm.mesh
	slot.lifetime = swarm.lifetime_s
	var count := maxi(1, roundi(swarm.amount * _density))
	if slot.amount != count:
		slot.amount = count


func _spot_nodes() -> Array[LifeSpot]:
	var out: Array[LifeSpot] = []
	if spots:
		for child in spots.get_children():
			if child is LifeSpot:
				out.append(child)
	return out


func _active_spots() -> int:
	var active := 0
	for spot in _spot_nodes():
		if spot.is_active():
			active += 1
	return active


func _get_configuration_warnings() -> PackedStringArray:
	var found := PackedStringArray()
	if atmosphere == null:
		found.append("Falta el socket Atmosphere.")
	if _set and _set.air.size() > air_slots.size():
		found.append("El bioma tiene %d enjambres de aire y el pool solo %d (Air1..Air%d): sobran." % [
				_set.air.size(), air_slots.size(), air_slots.size()])
	return found
