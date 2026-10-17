class_name StoneLook
extends Node

## F137 (RFC-030i-b): a body turned to stone (sacengine effects.stoneEffect = petrified || skinOfStone, stats.d:91;
## the bone shader's grey, dagon bone.d:189-192). Presentation only, on every peer: while `stone` is on, every surface
## of `mesh` gets a stone override built from that surface's own material (its texture and alpha scissor), so the
## textures still show through as grey. Reusable: Skin of Stone is one more owner with its own StoneLook.
##
## The mesh may be swapped under it (a clip frame, a model set up late on a client): it re-dresses whatever mesh is
## there each frame it is on, so it does not matter whether the clip froze before or after the stone came on.
## F149 (REVIEW-030k-b B1): one StoneLook per body, owned by Afflictions (its `look`), which sets `tint` and `stone`
## from the states that are on (petrified grey, frozen ice; the `frez` cube is not drawn, declared). Skin of Stone will
## be one more state with a look there, not a second StoneLook on the same mesh.

@export var mesh: MeshInstance3D
@export var shader: Shader
## The shader's stone_tint: the stone's (1, 1, 0.8, dagon bone.d:189-192) or the ice's; Afflictions sets it from the type that is on.
@export var tint := Color(1.0, 1.0, 0.8):
	set(value):
		if value == tint:
			return
		tint = value
		if is_node_ready() and stone and not Engine.is_editor_hint():
			_dressed = null
			_dress()
## The shader's stone_base, stone_gain, stone_roughness and stone_metallic (F155: the oil is a dark glossy coat, not grey stone;
## Afflictions sets them with the tint from the state that is on). The defaults are the stone's.
@export var base := 0.3
@export var gain := 0.7
@export var roughness := 0.5
@export var metallic := 0.5
## On: the stone overrides are on the mesh. Off: the surfaces get their own materials back.
@export var stone := false:
	set(value):
		if value == stone:
			return
		stone = value
		if is_node_ready():
			_refresh()

## One stone material per source material (or per shader with no source) and tint, shared by every body.
static var _materials: Dictionary = {}

var _dressed: Mesh


func _ready() -> void:
	_refresh()


func _process(_delta: float) -> void:
	if mesh and mesh.mesh != _dressed:
		_dress()


## Every knob of the look at once (one redress, whatever changed). Afflictions calls it with the state that is on.
func apply(new_tint: Color, new_base: float, new_gain: float, new_roughness: float, new_metallic: float) -> void:
	if new_tint == tint and new_base == base and new_gain == gain and new_roughness == roughness and new_metallic == metallic:
		return
	tint = new_tint
	base = new_base
	gain = new_gain
	roughness = new_roughness
	metallic = new_metallic
	if is_node_ready() and stone and not Engine.is_editor_hint():
		_dressed = null
		_dress()


func _refresh() -> void:
	var on := stone and not Engine.is_editor_hint()
	set_process(on)
	if on:
		_dress()
	else:
		_undress()


func _dress() -> void:
	if mesh == null:
		return
	_dressed = mesh.mesh
	if _dressed == null or shader == null:
		return
	for i in mesh.get_surface_override_material_count():
		mesh.set_surface_override_material(i, _stone_for(_dressed.surface_get_material(i)))


func _undress() -> void:
	_dressed = null
	if mesh == null:
		return
	for i in mesh.get_surface_override_material_count():
		mesh.set_surface_override_material(i, null)


func _stone_for(source: Material) -> ShaderMaterial:
	var key: Array = [source if source else shader, tint, base, gain, roughness, metallic]
	var found := _materials.get(key) as ShaderMaterial
	if found and found.shader == shader:
		return found
	var built := ShaderMaterial.new()
	built.shader = shader
	built.set_shader_parameter("stone_tint", Vector3(tint.r, tint.g, tint.b))
	built.set_shader_parameter("stone_base", base)
	built.set_shader_parameter("stone_gain", gain)
	built.set_shader_parameter("stone_roughness", roughness)
	built.set_shader_parameter("stone_metallic", metallic)
	var base := source as BaseMaterial3D
	if base:
		built.set_shader_parameter("albedo_tex", base.albedo_texture)
		built.set_shader_parameter("albedo_color", base.albedo_color)
		if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			built.set_shader_parameter("alpha_scissor", base.alpha_scissor_threshold)
	_materials[key] = built
	return built

