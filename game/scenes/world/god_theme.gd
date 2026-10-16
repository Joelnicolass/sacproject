extends Resource

## Land look of one god. The committed .tres keeps engine knobs and neutral
## defaults; the ENVI colors come from <cache_dir>/theme.json (tools/export_tilesets.py).

@export var god: StringName = &"james"
@export_dir var cache_dir: String = "res://cache/look/themes/james"
## Used when a file is not in cache_dir.
@export_dir var fallback_dir: String = "res://cache/look/themes/james"## renderer.d setupEnvironment sunStrength (persephone 6, pyro 2, james 14, stratos 12, charnel 4).
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

var missing: PackedStringArray = []


## Copy with the ENVI colors from theme.json; keeps the defaults if the cache is missing.
func with_cache() -> Resource:
	var resolved: Resource = duplicate()
	var path := cache_dir.path_join("theme.json")
	if not FileAccess.file_exists(path):
		resolved.missing = PackedStringArray(["theme.json"])
		return resolved
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		resolved.missing = PackedStringArray(["theme.json"])
		return resolved
	resolved.missing = PackedStringArray(data.get("missing", []))
	resolved.background_color = _color(data, "background_color", background_color)
	resolved.ambient_color = _color(data, "ambient_color", ambient_color)
	resolved.sun_color = _color(data, "sun_color", sun_color)
	resolved.fog_color = _color(data, "fog_color", fog_color)
	resolved.fog_begin = float(data.get("fog_begin", fog_begin))
	resolved.fog_end = float(data.get("fog_end", fog_end))
	var envi: Dictionary = data.get("envi", {})
	resolved.sun_direct_strength = float(envi.get("sun_direct_strength", sun_direct_strength))
	return resolved


## Path of a cached file, or the same name in fallback_dir.
func file(file_name: String) -> String:
	var path := cache_dir.path_join(file_name)
	if FileAccess.file_exists(path):
		return path
	return fallback_dir.path_join(file_name)


func sun_energy() -> float:
	var strength := minf(sun_strength * sun_direct_strength, 30.0)
	return maxf(min_sun_energy, sun_energy_at_reference * strength / reference_sun_strength)


## deferred.d adds the sun as albedo/PI * sunEnergy (383) and the ambient as albedo * 1 (403);
## Godot's sun already folds the PI in, so the ambient keeps that ratio to the sun scale.
func ambient_light_energy() -> float:
	return ambient_energy * sun_energy_at_reference * PI / reference_sun_strength


func _color(data: Dictionary, key: String, fallback: Color) -> Color:
	var rgb: Array = data.get(key, [])
	if rgb.size() < 3:
		return fallback
	return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
