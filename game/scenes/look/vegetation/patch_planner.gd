class_name PatchPlanner
extends RefCounted

## What a VegetationPatch plants and shows: the instances (pure: the same inputs give the same
## floats) and the editor ring. Spot i of a patch has its place, yaw and scale from the hash of
## (seed, tag, i), so a lower density keeps a prefix of the same plants. Presentation only.


## World-space MultiMesh buffer (MeshPlanter.XFORM_STRIDE floats each): the spots of the disc around
## `patch_xform` that are on the ground of `shape` (placed at `map_xform`) and outside every clear
## (rows x, z, radius, edge in world coordinates).
static func plan(
	species: VegetationSpecies,
	seed: int,
	count: int,
	radius_m: float,
	patch_xform: Transform3D,
	shape: Terrain,
	map_xform: Transform3D,
	density_scale: float,
	clears: PackedVector4Array
) -> PackedFloat32Array:
	var tag := species.density_tag()
	var tag_h := FloraPlacement.tag_hash(tag)
	var n := FloraPlacement.instance_count(seed, tag, 0, 0, count, density_scale)
	var height := shape.sampler()
	var to_map := map_xform.affine_inverse()
	var variation := species.variation()
	var buffer := PackedFloat32Array()
	buffer.resize(n * MeshPlanter.XFORM_STRIDE)
	var kept := 0
	for i in n:
		var radius := radius_m * sqrt(_unit(seed, FloraPlacement.SALT_JITTER_X, tag_h, i))
		var angle := TAU * _unit(seed, FloraPlacement.SALT_JITTER_Z, tag_h, i)
		var spot := patch_xform * Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if (
			not clears.is_empty()
			and MeshPlanter.is_cleared(clears, spot.x, spot.z, seed, tag_h, 0, 0, i)
		):
			continue
		var on_map := to_map * spot
		var y: float = height.call(on_map.x, on_map.z)
		if is_nan(y):
			continue
		var yaw := TAU * _unit(seed, FloraPlacement.SALT_YAW, tag_h, i)
		var at := FloraVariation.instance_transform(
			variation,
			seed,
			tag_h,
			0,
			0,
			i,
			yaw,
			_unit(seed, FloraPlacement.SALT_SCALE, tag_h, i),
			map_xform * Vector3(on_map.x, y, on_map.z)
		)
		FloraVariation.write_instance(
			buffer,
			kept,
			at,
			FloraVariation.instance_color(variation, seed, tag_h, 0, 0, i, on_map.x, on_map.z)
		)
		kept += 1
	buffer.resize(kept * MeshPlanter.XFORM_STRIDE)
	return buffer


static func _unit(seed: int, salt: int, tag_h: int, i: int) -> float:
	return FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ salt, tag_h, 0, 0, i))


## The MultiMeshInstance3D of a buffer from `plan`: world space (top level), culled past
## `range_end_m`.
static func instance(
	mesh: Mesh, buffer: PackedFloat32Array, material: Material, shadows: bool, range_end_m: float
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = buffer.size() / MeshPlanter.XFORM_STRIDE
	multimesh.buffer = buffer
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	node.visibility_range_end = range_end_m
	node.top_level = true
	return node


## A unit circle of lines (scale it by the radius), drawn over the ground in the editor.
static func ring() -> MeshInstance3D:
	var points := PackedVector3Array()
	for step in 49:
		points.append(Vector3(cos(TAU * step / 48.0), 0.3, sin(TAU * step / 48.0)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.4, 1.0, 0.4)
	material.no_depth_test = true
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
