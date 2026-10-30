class_name InstanceParams
extends RefCounted

## Writes a shader's per-instance values (PER_INSTANCE uniforms, per_instance.gdshaderinc) the way
## the renderer can take them:
## - Forward+ and Mobile: `set_instance_shader_parameter`, as before.
## - Compatibility (the web): the instance's own copy of the material that declares the uniform
##   (made once, on first write), so no instance takes a slot of WebGL's 1024.
## A scene saves a node's own values as metadata (`instance_params`, {name: value}), never as
## `instance_shader_parameters/*`: Godot sends those to the renderer on load, and there every node
## that has one takes a block of 16 slots even when the shader no longer declares it (WebGL fills
## its buffer at about 60 nodes). `install` writes the metadata when the node enters the tree.

const META := &"instance_params"

const OWNER_META := &"instance_params_owner"

static var _compat := -1
## Shader -> {uniform name: true}.
static var _uniforms := {}


static func is_compat() -> bool:
	if _compat < 0:
		_compat = int(RenderingServer.get_current_rendering_method() == "gl_compatibility")
	return _compat == 1


## Sets `param` of `geom` to `value` for this instance only.
static func set_on(geom: GeometryInstance3D, param: StringName, value: Variant) -> void:
	if not is_compat():
		geom.set_instance_shader_parameter(param, value)
		return
	var mat := _own_material(geom, param)
	if mat != null:
		mat.set_shader_parameter(param, value)


## Every node that enters `tree` with `instance_params` metadata gets those values. Call once, from
## an autoload.
static func install(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D and node.has_meta(META):
		_adopt.call_deferred(node)


## `node` may be freed by the time the call runs: a typed argument would fail before the check.
static func _adopt(node: Variant) -> void:
	var geom := node as GeometryInstance3D if is_instance_valid(node) else null
	if geom == null:
		return
	var values: Dictionary = geom.get_meta(META, {})
	for param: Variant in values:
		set_on(geom, StringName(param), values[param])


## The material of `geom` whose shader declares `param`, made the instance's own on first use.
static func _own_material(geom: GeometryInstance3D, param: StringName) -> ShaderMaterial:
	if _declares(geom.material_override, param):
		if not _owned(geom.material_override, geom):
			geom.material_override = _copy(geom.material_override, geom)
		return geom.material_override
	if _declares(geom.material_overlay, param):
		if not _owned(geom.material_overlay, geom):
			geom.material_overlay = _copy(geom.material_overlay, geom)
		return geom.material_overlay
	var mesh := geom as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		for i in mesh.get_surface_override_material_count():
			var mat := mesh.get_active_material(i)
			if _declares(mat, param):
				if not _owned(mat, geom):
					mat = _copy(mat, geom)
					mesh.set_surface_override_material(i, mat)
				return mat
	return null


static func _declares(mat: Material, param: StringName) -> bool:
	var shader_mat := mat as ShaderMaterial
	if shader_mat == null or shader_mat.shader == null:
		return false
	var shader := shader_mat.shader
	if not _uniforms.has(shader):
		var names := {}
		for uniform in shader.get_shader_uniform_list():
			names[StringName(uniform.name)] = true
		_uniforms[shader] = names
	return _uniforms[shader].has(param)


static func _owned(mat: Material, geom: GeometryInstance3D) -> bool:
	return mat.get_meta(OWNER_META, 0) == geom.get_instance_id()


static func _copy(mat: Material, geom: GeometryInstance3D) -> ShaderMaterial:
	var copy := mat.duplicate() as ShaderMaterial
	copy.set_meta(OWNER_META, geom.get_instance_id())
	return copy
