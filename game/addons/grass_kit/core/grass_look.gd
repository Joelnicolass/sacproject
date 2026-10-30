@tool
class_name GrassLook
extends Resource

## What the blades look like: their shape, colours, light, how they take the wind, and which kinds
## of blade grow (`meshes`: the kit's blade, or any mesh with its textures). A look is a .tres to
## duplicate and edit; a game keeps several (a meadow, a desert, snow, flowers) and swaps them in
## play. Its values are shader uniforms, so changing them rebuilds nothing; only other meshes, or
## other shares of them, build the field's meshes again.

@export_group("Shape")
## Height of the shortest (x) and tallest (y) blades (m).
@export var height_range := Vector2(0.25, 0.8):
	set(value):
		height_range = value
		emit_changed()
## Width of a blade at its base (m).
@export_range(0.005, 0.5, 0.005, "suffix:m") var width := 0.06:
	set(value):
		width = value
		emit_changed()
## Width at the tip, as a part of the base's (0 = a point).
@export_range(0.0, 1.0, 0.01) var tip_width := 0.15:
	set(value):
		tip_width = value
		emit_changed()
## How far a blade leans and curves at rest (0 = straight up).
@export_range(0.0, 1.0, 0.01) var lean := 0.35:
	set(value):
		lean = value
		emit_changed()
## On a slope a blade's base grows along the ground's normal (1) or straight up (0); its tip
## always turns up. Along the normal, the slope does not swallow the base.
@export_range(0.0, 1.0, 0.01) var align_to_normal := 0.7:
	set(value):
		align_to_normal = value
		emit_changed()
## Blades grow in clumps of this size (m): taller and leaning out at a clump's heart. 0 = no clumps.
@export_range(0.0, 10.0, 0.1, "suffix:m") var clump_size := 1.6:
	set(value):
		clump_size = value
		emit_changed()

@export_group("Colour")
@export var base_color := Color(0.13, 0.33, 0.07):
	set(value):
		base_color = value
		emit_changed()
@export var tip_color := Color(0.45, 0.62, 0.18):
	set(value):
		tip_color = value
		emit_changed()
## Random change of shade from blade to blade and clump to clump.
@export_range(0.0, 1.0, 0.01) var color_variation := 0.2:
	set(value):
		color_variation = value
		emit_changed()
## How much the ground's colour under a blade shows at its base (the ground's color texture, or
## `ground_color`), so the grass does not look pasted on.
@export_range(0.0, 1.0, 0.01) var ground_tint := 0.35:
	set(value):
		ground_tint = value
		emit_changed()
## The ground's colour where the ground has no color texture.
@export var ground_color := Color(0.26, 0.3, 0.13):
	set(value):
		ground_color = value
		emit_changed()
## From this part of the radius on, blades take the ground's colour, all of it at the edge.
@export_range(0.0, 1.0, 0.01) var fade_to_ground := 0.6:
	set(value):
		fade_to_ground = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var roughness := 0.6:
	set(value):
		roughness = value
		emit_changed()

@export_group("Light")
## Light through the blades from behind (translucency), the colour it takes.
@export var translucency := Color(0.35, 0.45, 0.1):
	set(value):
		translucency = value
		emit_changed()
## How dark the base of a blade is against its tip (shade from the blades around it).
@export_range(0.0, 1.0, 0.01) var root_shade := 0.45:
	set(value):
		root_shade = value
		emit_changed()
## How round a blade looks across its width (its normal turns out at the edges).
@export_range(0.0, 1.0, 0.01) var roundness := 0.6:
	set(value):
		roundness = value
		emit_changed()
## Blades seen edge-on widen up to this much more, so a field never looks thin from the side.
@export_range(0.0, 2.0, 0.01) var view_thicken := 0.6:
	set(value):
		view_thicken = value
		emit_changed()

@export_group("Wind")
## How much a gust bends the blades (the wind itself is the field's GrassWind).
@export_range(0.0, 2.0, 0.01) var wind_response := 1.0:
	set(value):
		wind_response = value
		emit_changed()
## A blade's own shiver across the wind, each at its own phase.
@export_range(0.0, 1.0, 0.01) var flutter := 0.15:
	set(value):
		flutter = value
		emit_changed()
## How much a gust lightens the tips it passes (so waves read from far away).
@export_range(0.0, 1.0, 0.01) var gust_lighten := 0.4:
	set(value):
		gust_lighten = value
		emit_changed()

@export_group("Distance")
## The far grass, and the game's ground beyond it (grass_ground.gdshaderinc), meet in a colour
## between the ground's and the grass's: this much grass. The edge of the drawn grass never shows.
@export_range(0.0, 1.0, 0.01) var far_grass := 0.5:
	set(value):
		far_grass = value
		emit_changed()

@export_group("Ground under the grass")
## How much the game's ground takes the grass's colour under the drawn blades
## (grass_ground.gdshaderinc), so what shows between them reads as more grass instead of bare,
## mottled ground. 0 = the ground keeps its own colour up to where the far grass fades.
@export_range(0.0, 1.0, 0.01) var under_grass := 0.6:
	set(value):
		under_grass = value
		emit_changed()
## How much of the ground's own light and dark it keeps there (against the brightness of
## `ground_color`), so its relief still shows through.
@export_range(0.0, 1.0, 0.01) var under_relief := 0.35:
	set(value):
		under_relief = value
		emit_changed()

@export_group("Meshes")
## The kinds of blade and their shares. Empty = the kit's blade only.
@export var meshes: Array[GrassMesh] = []:
	set(value):
		for old in meshes:
			if old != null and old.changed.is_connected(emit_changed):
				old.changed.disconnect(emit_changed)
		meshes = value
		for kind in meshes:
			if kind != null and not kind.changed.is_connected(emit_changed):
				kind.changed.connect(emit_changed)
		emit_changed()


## The colour a field of these blades reads as from afar (linear): the palette halfway up a blade,
## with the ground's tint and the root's shade. The far grass and the game's ground meet towards it.
func average_color() -> Color:
	var base := base_color.srgb_to_linear()
	var tip := tip_color.srgb_to_linear()
	var ground := ground_color.srgb_to_linear()
	var middle := base.lerp(tip, 0.5).lerp(ground, ground_tint * 0.5)
	return middle * (1.0 - root_shade * 0.5)


## The kinds a field draws: `meshes`, or the kit's blade alone.
func kinds() -> Array[GrassMesh]:
	var out: Array[GrassMesh] = []
	for kind in meshes:
		if kind != null and kind.weight > 0.0:
			out.append(kind)
	if out.is_empty():
		out.append(GrassMesh.new())
	return out


## What a field builds from this look: when it changes, the field builds its meshes again; any other
## change is uniforms only.
func build_key() -> String:
	var parts := PackedStringArray()
	for kind in kinds():
		parts.append(kind.build_key())
	return ";".join(parts)


## What the game's ground reads under the drawn grass (grass_ground.gdshaderinc's
## `grasskit_under`): `under_grass`, `under_relief`, and the brightness of `ground_color` (linear)
## that counts as neither light nor dark.
func ground_under() -> Vector4:
	var plain := ground_color.srgb_to_linear()
	var light := plain.r * 0.2126 + plain.g * 0.7152 + plain.b * 0.0722
	return Vector4(under_grass, under_relief, light, 0.0)


## Writes this look into `material` (the field's shader for one kind of blade).
func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"height_range", height_range)
	material.set_shader_parameter(&"blade_width", width)
	material.set_shader_parameter(&"tip_width", tip_width)
	material.set_shader_parameter(&"lean", lean)
	material.set_shader_parameter(&"align_to_normal", align_to_normal)
	material.set_shader_parameter(&"clump_size", clump_size)
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"tip_color", tip_color)
	material.set_shader_parameter(&"color_variation", color_variation)
	material.set_shader_parameter(&"ground_tint", ground_tint)
	material.set_shader_parameter(&"ground_color", ground_color)
	material.set_shader_parameter(&"fade_to_ground", fade_to_ground)
	material.set_shader_parameter(&"roughness_value", roughness)
	material.set_shader_parameter(&"translucency", translucency)
	material.set_shader_parameter(&"root_shade", root_shade)
	material.set_shader_parameter(&"roundness", roundness)
	material.set_shader_parameter(&"view_thicken", view_thicken)
	material.set_shader_parameter(&"wind_response", wind_response)
	material.set_shader_parameter(&"flutter", flutter)
	material.set_shader_parameter(&"gust_lighten", gust_lighten)
	material.set_shader_parameter(&"far_grass", far_grass)
	material.set_shader_parameter(&"grass_average", average_color())
