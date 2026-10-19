class_name GodTheme
extends Resource

## Land look of one god. The committed .tres keeps engine knobs and neutral defaults; the ENVI colours
## come from `envi` (assets/original/themes/<god>/envi.tres, tools/import/import_themes.py) and the images
## from OriginalAssets.theme_dir(god).

@export var god: StringName = &"james"
@export var envi: GodEnvi
## renderer.d setupEnvironment sunStrength (persephone 6, pyro 2, james 14, stratos 12, charnel 4).
@export var sun_strength: float = 14.0
## Light energy when sun_strength * ENVI direct strength equals reference_sun_strength.
@export var sun_energy_at_reference: float = 1.0
@export var reference_sun_strength: float = 14.0
@export var min_sun_energy: float = 0.35
@export var sun_direct_strength: float = 1.0
@export var background_color: Color = Color(1.0, 0.706, 0.471)
@export var ambient_color: Color = Color(0.38, 0.4, 0.52)
@export var ambient_energy: float = 1.0
@export var sun_color: Color = Color(1.0, 1.0, 1.0)
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.5, 0.55, 0.82)
## Depth fog: maximum fog amount at fog_end.
@export var fog_density: float = 1.0
@export var fog_begin: float = 100.0
@export var fog_end: float = 1600.0
## Remaster look of this biome (RFC-022). Empty = classic mode: nothing from data/look/ applies.
@export var look: LookProfile
## The classic ground of this biome (sacrifice_ground.gdshader with this god's atlas and edge and the map's
## light map), shared by every match that rolls the god. Edit it in the inspector.
@export var ground_material: ShaderMaterial

var missing: PackedStringArray = []


## Copy with the ENVI colours of `envi`; keeps the defaults when it is missing.
func resolved() -> Resource:
	var result: Resource = duplicate()
	if envi == null:
		result.missing = PackedStringArray(["envi"])
		return result
	result.background_color = envi.background_color
	result.ambient_color = envi.ambient_color
	result.sun_color = envi.sun_color
	result.fog_color = envi.fog_color
	result.fog_begin = envi.fog_begin
	result.fog_end = envi.fog_end
	result.sun_direct_strength = envi.sun_direct_strength
	return result


## Folder with this god's images (atlas, edge, sky, skyb, skyt, sun, undr) and its ground_classic.tres.
func dir() -> String:
	return OriginalAssets.theme_dir(String(god))


## Path of one of this god's images, e.g. file("atlas.png").
func file(file_name: String) -> String:
	return dir().path_join(file_name)


func sun_energy() -> float:
	var strength := minf(sun_strength * sun_direct_strength, 30.0)
	return maxf(min_sun_energy, sun_energy_at_reference * strength / reference_sun_strength)


## deferred.d adds the sun as albedo/PI * sunEnergy (383) and the ambient as albedo * 1 (403);
## Godot's sun already folds the PI in, so the ambient keeps that ratio to the sun scale.
func ambient_light_energy() -> float:
	return ambient_energy * sun_energy_at_reference * PI / reference_sun_strength
