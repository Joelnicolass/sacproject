@tool
class_name FxAtlas
extends RefCounted

## Atlases of the particle importer (tools/import_ui.py) by TXTR tag: `res://assets/original/fx/<tag>.png` (RFC-033d), imported
## textures read with `load()`. Static and @tool so the editor and a headless run can use it without autoloads. A missing
## file is null: the caller draws its own fill and warns.

static var _textures: Dictionary = {}


static func texture(tag: String) -> Texture2D:
	if tag.is_empty():
		return null
	if _textures.has(tag):
		return _textures[tag]
	var path := OriginalAssets.fx(tag)
	var texture_out: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[tag] = texture_out
	return texture_out


const SHADER_ADD := preload("res://scenes/fx/sprite_particle_add.gdshader")
const SHADER_MIX := preload("res://scenes/fx/sprite_particle_mix.gdshader")
const SHADER_MIX_LIT := preload("res://scenes/fx/sprite_particle_mix_lit.gdshader")
const CATALOG := OriginalAssets.FX_CATALOG

static var _catalogs: Dictionary = {}
static var _catalog_textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Entry of an fx.json catalog (empty when the catalog or the key is missing).
static func catalog_entry(atlas_key: String, path: String = CATALOG) -> Dictionary:
	if not _catalogs.has(path):
		var data: Dictionary = {}
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				data = parsed
		_catalogs[path] = data
	return _catalogs[path].get(atlas_key, {})


## Atlas PNG of a catalog entry (imported with mipmaps: particles shrink far away).
static func catalog_texture(atlas_key: String, path: String = CATALOG) -> Texture2D:
	var png: String = catalog_entry(atlas_key, path).get("png", "")
	if png.is_empty():
		return null
	if _catalog_textures.has(png):
		return _catalog_textures[png]
	var texture: Texture2D = load(png) as Texture2D if ResourceLoader.exists(png) else null
	_catalog_textures[png] = texture
	return texture


## Shared shadeless material of a ParticleType; null when its atlas is missing.
## The material is cached per ParticleType, but its parameters are refreshed on every call,
## so an edit in the inspector (energy, atlas, blending) shows up when the emitter rebuilds.
static func material_for(particle: ParticleType, path: String = CATALOG) -> ShaderMaterial:
	var texture := catalog_texture(particle.atlas_key, path)
	if texture == null:
		return null
	var material: ShaderMaterial = _materials.get(particle)
	if material == null:
		material = ShaderMaterial.new()
		_materials[particle] = material
	material.shader = shader_for(particle)
	material.set_shader_parameter("atlas", texture)
	material.set_shader_parameter("energy", particle.energy)
	material.set_shader_parameter("h_frames", particle.h_frames)
	material.set_shader_parameter("v_frames", particle.v_frames)
	material.set_shader_parameter("billboard", particle.billboard)
	material.set_shader_parameter("soft_distance_m", particle.soft_distance_m)
	material.set_shader_parameter("frame_blend", particle.frame_blend)
	material.set_shader_parameter("frame_wrap", particle.frames_wrap())
	material.set_shader_parameter("use_color_ramp", particle.color_ramp != null)
	material.set_shader_parameter("color_ramp", particle.color_ramp)
	return material


## Additive glows unshaded; a mix sprite is shaded (`lit`) or unshaded like the original.
static func shader_for(particle: ParticleType) -> Shader:
	if particle.additive:
		return SHADER_ADD
	return SHADER_MIX_LIT if particle.lit else SHADER_MIX


static func quad_for(particle: ParticleType) -> QuadMesh:
	if not _meshes.has(particle.size):
		var quad := QuadMesh.new()
		quad.size = particle.size
		_meshes[particle.size] = quad
	return _meshes[particle.size]
