class_name InstanceParams
extends RefCounted

## Writes a shader's per-instance values (PER_INSTANCE uniforms, per_instance.gdshaderinc) the way
## the renderer can take them:
## - Forward+ and Mobile: `set_instance_shader_parameter`, as before.
## - Compatibility (the web): the instance's own copy of the material that declares the uniform
##   (made once, on first write), so no instance takes a slot of WebGL's 1024.
## `install` also moves the values a scene saved on a node (`instance_shader_parameters/*`) into
## that copy when the node enters the tree. Inert outside Compatibility.

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


## On Compatibility, every node that enters `tree` with saved instance values gets them on its own
## material. Call once, from an autoload.
static func install(tree: SceneTree) -> void:
	if is_compat() and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		_adopt.call_deferred(node)


## `node` may be freed by the time the call runs: a typed argument would fail before the check.
static func _adopt(node: Variant) -> void:
	var geom := node as GeometryInstance3D if is_instance_valid(node) else null
	if geom == null:
		return
	for prop in geom.get_property_list():
		var path: String = prop.name
		if path.begins_with("instance_shader_parameters/"):
			var value: Variant = geom.get(path)
			if value != null:
				set_on(geom, StringName(path.trim_prefix("instance_shader_parameters/")), value)


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
