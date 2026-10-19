@tool
class_name FxLightLayer
extends LookLayer

## Light layer of the effects (RFC-029 029c): a pool of shadowless OmniLight3D that the bursts of a
## ParticleType with a `light` (FxLightSpec) borrow through the group `fx_light_pool`. The cap is the
## preset's `fx_max_lights` (0 = no light). With the cap full, a new light takes the place of the
## weakest one (energy × range / distance to the camera, at its current point of the fade) or is dropped.
## A light that loses its place while still lit (stolen, or its emitter played again elsewhere) does not
## go out at once: its node fades out on its own for `fade_out_s` and the new light takes a spare node.
## Fading nodes do not count for the cap; at most `max_fading` at a time (beyond that it is cut).
## Classic mode (null profile) and a hidden layer give no light. Presentation only: the rig, and this
## layer with it, is freed in a headless or dedicated process.

const GROUP := &"fx_light_pool"

## Cap while no preset has been handed over (a rig without quality).
@export_range(0, 64) var fallback_max_lights: int = 8
## `light_specular` of every light: the PBR ground shows a hot spot above ~0.5.
@export_range(0.0, 1.0, 0.05) var specular: float = 0.35
## `light_volumetric_fog_energy`: 0 keeps the lights out of the volumetric fog pass (cost).
@export_range(0.0, 4.0, 0.05) var fog_energy: float = 0.0
## Closer than this to the camera counts as this distance in the priority (no division by ~0).
@export_range(0.5, 50.0, 0.5, "suffix:m") var min_priority_distance_m: float = 4.0
## Most lights fading out at once after losing their place. 0 = they are cut, as before.
@export_range(0, 16) var max_fading: int = 4
## Seconds a light that lost its place takes to go from its energy to 0.
@export_range(0.02, 1.0, 0.01, "suffix:s") var fade_out_s: float = 0.1

var _max_lights := -1
var _enabled := false
## OmniLight3D children not lighting anything (hidden).
var _free: Array[OmniLight3D] = []
## Lighting now, in request order.
var _slots: Array[_Slot] = []
## Lights going out after losing their place: {light, from, t}. Outside the cap.
var _fading: Array[Dictionary] = []


class _Slot:
	var key: int
	var spec: FxLightSpec
	var at: Vector3
	var t: float
	var light: OmniLight3D


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	visibility_changed.connect(_on_visibility_changed)
	if _max_lights < 0:
		_max_lights = fallback_max_lights


func apply_look(profile: LookProfile, _rig: LookRig) -> void:
	_enabled = profile != null
	if not _enabled:
		_clear()


func apply_quality(preset: LookQuality) -> void:
	_max_lights = preset.fx_max_lights if preset else fallback_max_lights
	while _slots.size() > _max_lights:
		_end(_weakest(_camera()))
	while _free.size() + _slots.size() + _fading.size() > _max_lights + max_fading and not _free.is_empty():
		_free.pop_back().queue_free()


## Lights `spec` at `at` for one burst of `source`. The same source again restarts its light (a pooled
## emitter that plays somewhere else) instead of taking a second one.
func flash(source: Object, spec: FxLightSpec, at: Vector3) -> void:
	if spec == null or not _enabled or _max_lights <= 0 or not is_visible_in_tree():
		return
	var key := source.get_instance_id() if source != null else 0
	var slot: _Slot = _slot_of(key) if key != 0 else null
	if slot == null:
		slot = _open_slot(spec, at)
		if slot == null:
			return
	else:
		_hand_off(slot)
	slot.key = key
	slot.spec = spec
	slot.at = at
	slot.t = 0.0
	_place(slot)
	set_process(true)


func active_count() -> int:
	return _slots.size()


## Lights fading out after losing their place (outside the cap).
func fading_count() -> int:
	return _fading.size()


## Specs of the lights on now, in request order (for the labs of debug/).
func lit_specs() -> Array[FxLightSpec]:
	var out: Array[FxLightSpec] = []
	for slot in _slots:
		out.append(slot.spec)
	return out


func max_lights() -> int:
	return maxi(_max_lights, 0)


## Lights of the pool (lighting or not) that cast a shadow. Always 0.
func shadow_count() -> int:
	var n := 0
	for child in get_children():
		if child is OmniLight3D and (child as OmniLight3D).shadow_enabled:
			n += 1
	return n


## "fx_luces activas <n> tope <m> sombras <s>" for the labs.
func report() -> String:
	return "fx_luces activas %d tope %d fundiendo %d sombras %d" % [active_count(), max_lights(), fading_count(), shadow_count()]


func _process(delta: float) -> void:
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		slot.t += delta
		if slot.t >= slot.spec.total_s():
			_end(slot)
			continue
		slot.light.light_energy = slot.spec.energy * slot.spec.envelope(slot.t)
	for i in range(_fading.size() - 1, -1, -1):
		var fade: Dictionary = _fading[i]
		fade["t"] += delta
		var light: OmniLight3D = fade["light"]
		if fade["t"] >= fade_out_s:
			_fading.remove_at(i)
			light.visible = false
			_free.append(light)
			continue
		light.light_energy = fade["from"] * (1.0 - fade["t"] / fade_out_s)
	if _slots.is_empty() and _fading.is_empty():
		set_process(false)


func _open_slot(spec: FxLightSpec, at: Vector3) -> _Slot:
	if _slots.size() < _max_lights:
		var slot := _Slot.new()
		slot.light = _take_node()
		_slots.append(slot)
		return slot
	var camera := _camera()
	var weakest := _weakest(camera)
	if weakest == null or _priority(weakest.spec, _level(weakest), weakest.at, camera) >= _priority(spec, 1.0, at, camera):
		return null
	_slots.erase(weakest)
	_slots.append(weakest)
	_hand_off(weakest)
	return weakest


## The slot's lit node keeps its place and fades out on its own; the slot gets a spare node for its
## new light. With `max_fading` reached (or the node dark) the slot keeps its node and the light is cut.
func _hand_off(slot: _Slot) -> void:
	if not slot.light.visible or slot.light.light_energy <= 0.0 or _fading.size() >= max_fading:
		return
	_fading.append({"light": slot.light, "from": slot.light.light_energy, "t": 0.0})
	slot.light = _take_node()


func _take_node() -> OmniLight3D:
	return _free.pop_back() if not _free.is_empty() else _new_light()


func _place(slot: _Slot) -> void:
	var light := slot.light
	light.global_position = slot.at + Vector3.UP * slot.spec.height_m
	light.light_color = slot.spec.color
	light.omni_range = slot.spec.range_m
	light.omni_attenuation = slot.spec.attenuation
	light.light_energy = slot.spec.energy * slot.spec.envelope(0.0)
	light.visible = true


func _end(slot: _Slot) -> void:
	if slot == null:
		return
	_slots.erase(slot)
	slot.light.visible = false
	_free.append(slot.light)


func _clear() -> void:
	while not _slots.is_empty():
		_end(_slots.back())
	for fade in _fading:
		(fade["light"] as OmniLight3D).visible = false
		_free.append(fade["light"])
	_fading.clear()
	set_process(false)


func _slot_of(key: int) -> _Slot:
	for slot in _slots:
		if slot.key == key:
			return slot
	return null


func _weakest(camera: Camera3D) -> _Slot:
	var found: _Slot = null
	var lowest := INF
	for slot in _slots:
		var p := _priority(slot.spec, _level(slot), slot.at, camera)
		if p < lowest:
			lowest = p
			found = slot
	return found


## Level a slot competes with: its peak (1.0) while it is still rising, so a light born this frame
## (envelope ~0) is not the weakest one; afterwards, where its fade is.
func _level(slot: _Slot) -> float:
	return 1.0 if slot.t < slot.spec.attack_s else slot.spec.envelope(slot.t)


func _priority(spec: FxLightSpec, level: float, at: Vector3, camera: Camera3D) -> float:
	var distance := min_priority_distance_m
	if camera != null:
		distance = maxf(distance, camera.global_position.distance_to(at))
	return spec.energy * level * spec.range_m / distance


func _camera() -> Camera3D:
	return get_viewport().get_camera_3d() if is_inside_tree() else null


func _new_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "FxLight%d" % get_child_count()
	light.shadow_enabled = false
	light.light_specular = specular
	light.light_volumetric_fog_energy = fog_energy
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.visible = false
	add_child(light)
	return light


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear()
