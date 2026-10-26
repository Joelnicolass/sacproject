@tool
class_name FxAtlas
extends RefCounted

## The shared look of a ParticleType: its material (shader, atlas and knobs) and its quad, cached per type. Every effect holds its
## own Texture2D (ParticleType.atlas, BeamType.atlas, a node's `atlas`); nothing here looks an atlas up by name. Static and @tool so
## the editor and a headless run can use it without autoloads.

const SHADER_ADD := preload("res://scenes/fx/sprite_particle_add.gdshader")
const SHADER_MIX := preload("res://scenes/fx/sprite_particle_mix.gdshader")
const SHADER_MIX_LIT := preload("res://scenes/fx/sprite_particle_mix_lit.gdshader")
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Shared shadeless material of a ParticleType; null when its atlas is missing.
## The material is cached per ParticleType, but its parameters are refreshed on every call,
## so an edit in the inspector (energy, atlas, blending) shows up when the emitter rebuilds.
static func material_for(particle: ParticleType) -> ShaderMaterial:
	var texture := particle.atlas
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


## One quad per (size, flat): a flat type gets a quad lying on the ground (FACE_Y), the rest face the camera (FACE_Z).
static func quad_for(particle: ParticleType) -> QuadMesh:
	var key := Vector3(particle.size.x, particle.size.y, 1.0 if particle.flat else 0.0)
	if not _meshes.has(key):
		var quad := QuadMesh.new()
		quad.size = particle.size
		if particle.flat:
			quad.orientation = PlaneMesh.FACE_Y
		_meshes[key] = quad
	return _meshes[key]
