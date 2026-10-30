@tool
class_name GrassQuality
extends Resource

## How many blades and how far: the cost of the grass. The blades stand in square cells around the
## camera; near it there are `density` blades per m², farther fewer and wider ones down to
## `far_density` at `radius`, and none past it. A cell holds as many blades as the density at its
## nearest point asks for, so its count is fixed and nothing pops: the shader thins the rest by
## distance. `blades_in_ring()` says what a whole ring instances, the number that costs frames.
## `preset()` gives a low, a medium and a high one.

enum Level { LOW, MEDIUM, HIGH }

## What a preset sets.
const _PRESET_VALUES := [&"density", &"radius", &"near_radius", &"segments"]

## Blades per m² near the camera.
@export_range(1.0, 400.0, 1.0, "or_greater") var density := 40.0:
	set(value):
		density = value
		emit_changed()
## How far from the camera grass reaches (m).
@export_range(4.0, 1000.0, 1.0, "or_greater", "suffix:m") var radius := 45.0:
	set(value):
		radius = value
		emit_changed()
## Full density up to this distance (m); from there it thins to `far_density` at `radius`.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:m") var near_radius := 15.0:
	set(value):
		near_radius = value
		emit_changed()
## The density at `radius`, as a part of `density`. The blades there are wider to cover as much.
@export_range(0.01, 1.0, 0.01) var far_density := 0.12:
	set(value):
		far_density = value
		emit_changed()
## Side of a cell (m). Bigger = fewer nodes, coarser culling.
@export_range(2.0, 128.0, 1.0, "or_greater", "suffix:m") var cell_size := 16.0:
	set(value):
		cell_size = value
		emit_changed()
## Distance bands between full and far density, each a set of cells holding fewer blades.
@export_range(2, 16) var tiers := 8:
	set(value):
		tiers = value
		emit_changed()
## A blade is never thinner than this on screen (pixels): far ones widen instead of shimmering.
@export_range(0.0, 8.0, 0.1) var min_blade_pixels := 1.5:
	set(value):
		min_blade_pixels = value
		emit_changed()
## Blades closer to the camera than this (m) shrink to the ground, so none fills the lens.
@export_range(0.0, 10.0, 0.1, "suffix:m") var near_fade := 1.5:
	set(value):
		near_fade = value
		emit_changed()
## Segments of the nearest blades (1, 2, 4 or 8; more = a smoother curve). Every step out halves
## them down to one triangle, and a blade blends into the coarser shape before its cell switches,
## so the change never shows.
@export_range(1, 8) var segments := 4:
	set(value):
		segments = 1 << int(log(float(maxi(value, 1))) / log(2.0) + 0.001)
		emit_changed()
@export var cast_shadows := false:
	set(value):
		cast_shadows = value
		emit_changed()

@export_group("Presets")
## Sets every value above to the low preset (weak GPUs), as one step of the editor's history.
@export_tool_button("Low", "Remove") var low_button := _apply.bind(Level.LOW)
@export_tool_button("Medium", "Node") var medium_button := _apply.bind(Level.MEDIUM)
@export_tool_button("High", "Add") var high_button := _apply.bind(Level.HIGH)
## What these settings instance: read it while tuning them.
@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var cost: String:
	get:
		return describe()
	set(_value):
		pass


## A ready-made quality: LOW for weak GPUs, MEDIUM, HIGH.
static func preset(level: Level) -> GrassQuality:
	var out := GrassQuality.new()
	match level:
		Level.LOW:
			out.density = 20.0
			out.radius = 30.0
			out.near_radius = 10.0
			out.segments = 2
		Level.MEDIUM:
			out.density = 32.0
			out.radius = 40.0
			out.near_radius = 13.0
			out.segments = 4
		Level.HIGH:
			out.density = 45.0
			out.radius = 56.0
			out.near_radius = 16.0
			out.segments = 8
	return out


## Takes `level`'s values (density, radius, near radius, segments). In the editor, one step of its
## history.
func apply_preset(level: Level) -> void:
	_apply(level)


func _apply(level: Level) -> void:
	var preset := preset(level)
	# Looked up by name: EditorInterface is not in an exported game.
	var editor := Engine.get_singleton(&"EditorInterface") if Engine.is_editor_hint() else null
	if editor == null:
		for property in _PRESET_VALUES:
			set(property, preset.get(property))
		return
	var history: Object = editor.call(&"get_editor_undo_redo")
	history.call(&"create_action", "GrassQuality preset", UndoRedo.MERGE_DISABLE, self)
	for property in _PRESET_VALUES:
		history.call(&"add_do_property", self, property, preset.get(property))
		history.call(&"add_undo_property", self, property, get(property))
	history.call(&"commit_action")


## How far the ring's centre moves before the cells follow (m): a quarter of a cell. A cell takes
## its tier this much nearer than its nearest point, so it holds every blade it must show.
func ring_margin() -> float:
	return cell_size * 0.25


## The segments of a blade in `tier`: `segments`, halved at each level out, down to 1.
func segments_in_tier(tier: int) -> int:
	var levels := int(log(float(segments)) / log(2.0) + 0.001) + 1
	var level := clampi(tier * levels / tiers, 0, levels - 1)
	return maxi(segments >> level, 1)


## For blades of 2^k segments (index k): the distance by which they have blended into half as many,
## so the cell can switch to the coarser mesh unseen. 0 = they never switch.
func morph_ends() -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var starts := tier_starts()
	for tier in range(1, tiers):
		var before := segments_in_tier(tier - 1)
		if segments_in_tier(tier) < before:
			var k := int(log(float(before)) / log(2.0) + 0.001)
			if out[k] == 0.0:
				out[k] = starts[tier] + ring_margin()
	return out


## The part of `density` at `distance` from the field's centre (1 near, `far_density` at `radius`,
## 0 past it). The shader uses the same curve.
func density_at(distance: float) -> float:
	if distance > radius:
		return 0.0
	var start := minf(near_radius, radius)
	if distance <= start:
		return 1.0
	var t := smoothstep(start, radius, distance)
	return lerpf(1.0, far_density, t)


## The blades of a full cell (the nearest tier): density times the cell's area.
func blades_per_cell() -> int:
	return ceili(density * cell_size * cell_size)


## Where each tier starts (m from the centre to a cell's nearest point): tier 0 at 0.
func tier_starts() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var start := minf(near_radius, radius)
	out.append(0.0)
	for k in range(1, tiers):
		out.append(lerpf(start, radius, float(k - 1) / float(tiers - 1)))
	return out


## The tier of a cell whose nearest point is `distance` from the centre.
func tier_at(distance: float) -> int:
	var starts := tier_starts()
	var tier := 0
	for k in starts.size():
		if distance >= starts[k]:
			tier = k
	return tier


## The blades a cell of `tier` holds: what the density asks for at the tier's start. Never more
## than the tier before it, so every tier is a prefix of the same blades.
func blades_in_tier(tier: int) -> int:
	var starts := tier_starts()
	return ceili(blades_per_cell() * density_at(starts[clampi(tier, 0, starts.size() - 1)]))


## The blades a whole ring instances around a centre (every cell within `radius`), the number that
## costs frames. A cell counts by the distance to its nearest point, as the field does.
func blades_in_ring() -> int:
	var total := 0
	var reach := ceili(radius / cell_size) + 1
	for x in range(-reach, reach):
		for z in range(-reach, reach):
			var rect := Rect2(x * cell_size, z * cell_size, cell_size, cell_size)
			var nearest := Vector2.ZERO.clamp(rect.position, rect.end).length()
			if nearest <= radius:
				total += blades_in_tier(tier_at(nearest))
	return total


## One line for a log: the settings and what a ring instances.
func describe() -> String:
	return "%d blades/m² to %d m (full to %d m, %d%% at the edge), %d m cells, %d blades a ring" % [
		density, radius, near_radius, roundi(far_density * 100.0), cell_size, blades_in_ring()
	]
