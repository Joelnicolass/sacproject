class_name WarmCollect
extends RefCounted

## What the warm-up draws, found by walking the typed resources under some roots (a god goes to its book, its spells, their scenes;
## a body scene to the `<name>_look.tscn` next to it, a script to what it preloads): every mesh, every 3D material, every bare
## spatial shader (its material is made at runtime) and every scene whose root is a look (BodyLook, FxScene), which is safe to
## instance because it simulates nothing (as is a scene of bare engine geometry, like a pooled Label3D). Adding content adds no line
## here. The looks it finds are read all at once on the loader's threads while the walk goes on (`read_looks`).
## What it does not do: draw, instance or load files of its own (only the look scene of a body, BodyLook.path_of_body), or keep
## anything beyond what it found (whoever holds it keeps those loaded).

var meshes: Array[Mesh] = []
var materials: Array[Material] = []
## Spatial shaders kept bare (an `@export var shader`, a script's `preload`): their material is made at runtime.
var shaders: Array[Shader] = []
var scenes: Array[PackedScene] = []
## Materials worn by an ImmediateMesh a script fills every frame (a ribbon, a thread): ShaderWarmup draws them on stroke probes,
## whose vertex format and primitives are those of such a mesh, not of a mesh on disk.
var strokes: Array[Material] = []

var _seen: Dictionary[int, bool] = {}
## Look paths asked to the loader and not walked yet, and every look path asked so far.
var _looks_due: PackedStringArray = []
var _looks_asked: Dictionary[String, bool] = {}
## False when it only lists the looks (`look_paths`): nothing is asked to the loader.
var _read_looks := true


## The body looks under `roots`, listed and not read (the flow reads them on its loading thread beside the map).
static func look_paths(roots: Array) -> PackedStringArray:
	var found := WarmCollect.new()
	found._read_looks = false
	found.add(roots)
	return found._looks_due


## Walks `roots` (Resources, Arrays or Dictionaries of them). Each body look found on the way is asked to ResourceLoader's threads at
## once; `read_looks` walks them once they are read.
func add(roots: Array) -> void:
	for root: Variant in roots:
		_visit(root)


## Walks the body looks the loader finished reading (they may lead to more). True when none is left to read: call it again a frame
## later until then, so the screen keeps drawing while they load.
func read_looks() -> bool:
	var due := _looks_due
	_looks_due = PackedStringArray()
	for path in due:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_looks_due.append(path)
		else:
			_visit(ResourceLoader.load_threaded_get(path))
	return _looks_due.is_empty()


## Meshes, materials, the bare shaders no found material wears, then scenes: what ShaderWarmup draws, in order.
func items() -> Array:
	var all: Array = []
	all.append_array(meshes)
	all.append_array(materials)
	for shader in shaders:
		if not materials.any(func(worn: Material) -> bool: return worn is ShaderMaterial and worn.shader == shader):
			all.append(shader)
	all.append_array(scenes)
	return all


func _visit(value: Variant) -> void:
	match typeof(value):
		TYPE_ARRAY:
			var array: Array = value
			if array.is_typed() and not WarmKinds.holds(array.get_typed_builtin()):
				return
			for item: Variant in array:
				if WarmKinds.holds(typeof(item)):
					_visit(item)
		TYPE_DICTIONARY:
			_visit((value as Dictionary).keys())
			_visit((value as Dictionary).values())
		TYPE_OBJECT:
			var resource := value as Resource
			if resource != null:
				_visit_resource(resource)


func _visit_resource(resource: Resource) -> void:
	var id := resource.get_instance_id()
	if _seen.has(id):
		return
	_seen[id] = true
	if resource is PackedScene:
		_visit_scene(resource as PackedScene)
		return
	if resource is Script:
		_visit_script(resource as Script)
		return
	var fields: Variant = WarmKinds.fields_of(resource)
	if fields == null:
		return
	if resource is Mesh:
		var mesh := resource as Mesh
		meshes.append(mesh)
		for surface in mesh.get_surface_count():
			_visit(mesh.surface_get_material(surface))
	elif WarmKinds.is_drawable(resource):
		materials.append(resource as Material)
	elif resource is Shader and (resource as Shader).get_mode() == Shader.MODE_SPATIAL:
		shaders.append(resource as Shader)
	for field: String in fields:
		_visit(resource.get(field))


## What a script preloads (a shader it builds a material from, a scene it spawns: its constants and the defaults of its properties,
## which a scene does not save), and its base script's.
func _visit_script(script: Script) -> void:
	_visit(script.get_script_constant_map().values())
	for property in script.get_script_property_list():
		if WarmKinds.holds(property.type):
			_visit(script.get_property_default_value(property.name))
	_visit(script.get_base_script())


## A scene is read from its saved state (nothing is instanced): its nodes' values, the scenes it instances and, for a body, its look.
func _visit_scene(packed: PackedScene) -> void:
	var state := packed.get_state()
	if state.get_node_count() == 0:
		return
	if WarmKinds.is_look(state):
		scenes.append(packed)
	var look := BodyLook.path_of_body(packed)
	if not look.is_empty() and not _looks_asked.has(look):
		_looks_asked[look] = true
		_looks_due.append(look)
		if _read_looks:
			ResourceLoader.load_threaded_request(look, "", true)
	for node in state.get_node_count():
		_visit(state.get_node_instance(node))
		var drawn: Variant = null
		var worn: Variant = null
		for i in state.get_node_property_count(node):
			var value: Variant = state.get_node_property_value(node, i)
			if WarmKinds.holds(typeof(value)):
				_visit(value)
			match state.get_node_property_name(node, i):
				&"mesh": drawn = value
				&"material_override": worn = value
		if drawn is ImmediateMesh and worn is Material and not worn in strokes:
			strokes.append(worn)
