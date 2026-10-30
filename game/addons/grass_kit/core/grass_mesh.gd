@tool
class_name GrassMesh
extends Resource

## One kind of blade in a look: the kit's own blade, or any mesh (a modelled blade, a tuft, a
## flower, a fern), its share of the blades, its textures and where it grows. A look mixes several
## by `weight` (90 % blades, 8 % tufts, 2 % flowers); each kind is a prefix of the same evenly
## spread blades, so mixing keeps the density smooth. A kind that grows where a map says
## (`map_name`, `mask_texture`) adds its blades there on top of the others instead of taking a
## share of them: painting flowers in a meadow leaves the rest of the meadow as dense. A mesh
## stands in its own space: y up, the root at y 0; it is scaled to the look's blade height, turned
## at random and bent by the wind, more the higher a vertex is (or by its vertex colour's red, with
## `bend_from_color`).

## Null = the kit's blade (its segments come from the quality; it is bent along a curve).
@export var mesh: Mesh:
	set(value):
		mesh = value
		emit_changed()
## Share of the blades (the weights of a look's meshes are relative to each other). A kind that
## grows by a map adds this share where it grows, against the weights of the kinds that do not.
@export_range(0.0, 100.0, 0.01, "or_greater") var weight := 1.0:
	set(value):
		weight = value
		emit_changed()
## Size against the look's `height_range` (2 = twice as tall).
@export_range(0.05, 10.0, 0.01, "or_greater") var size := 1.0:
	set(value):
		size = value
		emit_changed()
## The name of the ground's painted map that says where this kind grows (`GrassGround.kind_maps`):
## the «Kind» brush paints it, and names the kind when it has no name yet. Looks that share a name
## grow their kinds in the same places (flowers in summer and in autumn). Empty = everywhere, or
## `mask_texture`.
@export var map_name: StringName = &"":
	set(value):
		map_name = value
		emit_changed()
## Where this kind grows, stretched over the ground's area (red: white = here), when the ground has
## no map by `map_name`. Null = everywhere.
@export var mask_texture: Texture2D:
	set(value):
		mask_texture = value
		emit_changed()

@export_group("Material")
## Multiplies the colour (the look's palette still applies, by `palette`).
@export var albedo_texture: Texture2D:
	set(value):
		albedo_texture = value
		emit_changed()
@export var normal_texture: Texture2D:
	set(value):
		normal_texture = value
		emit_changed()
## Occlusion (red), roughness (green), metallic (blue).
@export var orm_texture: Texture2D:
	set(value):
		orm_texture = value
		emit_changed()
## 0 = opaque. Above 0, pixels with less alpha are cut (petals, a card of stalks). Costs more on
## some GPUs: keep it 0 for plain blades.
@export_range(0.0, 1.0, 0.01) var alpha_scissor := 0.0:
	set(value):
		alpha_scissor = value
		emit_changed()
@export var tint := Color.WHITE:
	set(value):
		tint = value
		emit_changed()
## How much the look's colours (base to tip, clumps, the ground's tint) colour this kind: 1 = all,
## 0 = only its own texture and tint (a flower).
@export_range(0.0, 1.0, 0.01) var palette := 1.0:
	set(value):
		palette = value
		emit_changed()
## Bend each vertex by its colour's red (0 root, 1 tip) instead of by its height.
@export var bend_from_color := false:
	set(value):
		bend_from_color = value
		emit_changed()


## What a field builds from this kind (a change here needs new meshes, not only new uniforms).
func build_key() -> String:
	var kind := mesh.get_rid() if mesh != null else "blade"
	return "%s|%s|%s|%s" % [kind, alpha_scissor > 0.0, weight, grows_by_map()]


## True when a map says where this kind grows (`map_name` or `mask_texture`): it adds its blades
## there instead of sharing the others'.
func grows_by_map() -> bool:
	return map_name != &"" or mask_texture != null
