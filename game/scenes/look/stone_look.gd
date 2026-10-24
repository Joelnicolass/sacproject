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
## from the states that are on (petrified grey; the ice is a block of its own, IceBlock). Skin of Stone will
## be one more state with a look there, not a second StoneLook on the same mesh.

@export var mesh: MeshInstance3D
@export var shader: Shader
## The shader's stone_tint: the stone's (1, 1, 0.8, dagon bone.d:189-192) or the ice's; Afflictions sets it from the type that is on.
@export var tint := Color(1.0, 1.0, 0.8):
	set(value):
		if value == tint:
			return
		tint = value
		if is_node_ready() and _dressing() and not Engine.is_editor_hint():
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
## RFC 061c: a texture drawn on every surface instead of its own, with the surface's UV, alpha cut and light (Slime's wet skin, `lthg`).
## Afflictions sets it from the states that are on; with `stone` also on, the stone's grey is made from this texture. Null: the surfaces keep theirs.
var swap_texture: Texture2D:
	set(value):
		if value == swap_texture:
			return
		swap_texture = value
		if is_node_ready():
			_dressed = null
			_refresh()

## One stone material per source material (or per shader with no source) and tint, shared by every body.
static var _materials: Dictionary = {}

var _dressed: Mesh
## RFC-023: when `mesh` is a BodyVisual that a BodyRig draws for, the skinned meshes of the rig are dressed instead. The
## materials they had (OriginalMaterial overrides, not the mesh's own) are kept here to put back: instance id -> Array.
var _dressed_root: Node
var _saved: Dictionary = {}


func _ready() -> void:
	_refresh()


func _process(_delta: float) -> void:
	if mesh == null:
		return
	var rig := _rig()
	var stale := (rig.model_root() != _dressed_root) if rig != null else (mesh.mesh != _dressed)
	if stale:
		_dress()


## The BodyRig that draws `mesh`'s body while it shows a skeleton, else null (the mesh itself is what shows).
func _rig() -> BodyRig:
	var visual := mesh as BodyVisual
	return visual.rig if visual != null and visual.rig != null and visual.rig.is_loaded() else null


## Every knob of the look at once (one redress, whatever changed). Afflictions calls it with the state that is on.
func apply(new_tint: Color, new_base: float, new_gain: float, new_roughness: float, new_metallic: float) -> void:
	if new_tint == tint and new_base == base and new_gain == gain and new_roughness == roughness and new_metallic == metallic:
		return
	tint = new_tint
	base = new_base
	gain = new_gain
	roughness = new_roughness
	metallic = new_metallic
	if is_node_ready() and _dressing() and not Engine.is_editor_hint():
		_dressed = null
		_dress()


## The look of plain stone (sacengine's bone shader grey): what Skin of Stone and a petrified body wear.
func apply_stone() -> void:
	apply(Color(1.0, 1.0, 0.8), 0.3, 0.7, 0.5, 0.5)


## Are the surfaces dressed: stone, a swapped texture, or both.
func _dressing() -> bool:
	return stone or swap_texture != null


func _refresh() -> void:
	var on := _dressing() and not Engine.is_editor_hint()
	set_process(on)
	if on:
		_dress()
	else:
		_undress()


func _dress() -> void:
	if mesh == null:
		return
	var rig := _rig()
	if rig != null:
		_dress_rig(rig)
		return
	_dressed = mesh.mesh
	if _dressed == null or shader == null:
		return
	for i in mesh.get_surface_override_material_count():
		mesh.set_surface_override_material(i, _stone_for(_dressed.surface_get_material(i)))


func _dress_rig(rig: BodyRig) -> void:
	_dressed = null
	_dressed_root = rig.model_root()
	if shader == null:
		return
	for body in rig.skinned_meshes():
		var id := body.get_instance_id()
		if not _saved.has(id):
			var originals := []
			for i in body.get_surface_override_material_count():
				originals.append(body.get_surface_override_material(i))
			_saved[id] = originals
		var source: Array = _saved[id]
		for i in source.size():
			body.set_surface_override_material(i, _stone_for(source[i]))


func _undress() -> void:
	_dressed = null
	_dressed_root = null
	for id: int in _saved:
		var body := instance_from_id(id) as MeshInstance3D
		if body != null:
			var originals: Array = _saved[id]
			for i in originals.size():
				body.set_surface_override_material(i, originals[i])
	_saved.clear()
	if mesh == null or mesh.mesh == null:
		return
	for i in mesh.get_surface_override_material_count():
		mesh.set_surface_override_material(i, null)


func _stone_for(source: Material) -> ShaderMaterial:
	var key: Array = [source if source else shader, tint, base, gain, roughness, metallic, swap_texture, stone]
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
	built.set_shader_parameter("stone_on", stone)
	built.set_shader_parameter("use_swap", swap_texture != null)
	built.set_shader_parameter("swap_tex", swap_texture)
	var base := source as BaseMaterial3D
	if base:
		built.set_shader_parameter("albedo_tex", base.albedo_texture)
		built.set_shader_parameter("albedo_color", base.albedo_color)
		if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			built.set_shader_parameter("alpha_scissor", base.alpha_scissor_threshold)
	_materials[key] = built
	return built

