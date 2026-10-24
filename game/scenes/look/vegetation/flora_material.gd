class_name FloraMaterial
extends RefCounted

## The material a flora MultiMesh draws with. The prop's own material is shared (OriginalMaterial), so it is never touched:
## a copy multiplies its albedo by the instance color (`vertex_color_use_as_albedo`, MultiMesh.use_colors) and, when
## `fade_m` > 0, dithers out between end - fade and end (camera distance). Presentation only.


## A copy of the mesh's only material for the whole MultiMesh. Null for a mesh with several surfaces (use `mesh_for`) or a
## material that is not a BaseMaterial3D.
static func for_mesh(mesh: Mesh, end_m: float, fade_m: float) -> Material:
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	var base := mesh.surface_get_material(0) as BaseMaterial3D
	if base == null:
		return null
	var copy := base.duplicate() as BaseMaterial3D
	copy.vertex_color_use_as_albedo = true
	if fade_m > 0.0:
		copy.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		# max < min reverses the fade: opaque up to max, gone at min.
		copy.distance_fade_max_distance = maxf(end_m - fade_m, 0.0)
		copy.distance_fade_min_distance = end_m
	return copy


## The mesh to draw: itself when `for_mesh` covers it; for several surfaces a copy whose materials take the instance color
## (no distance fade: the node's visibility range still ends it).
static func mesh_for(mesh: Mesh) -> Mesh:
	if mesh == null or mesh.get_surface_count() == 1:
		return mesh
	var copy := mesh.duplicate() as Mesh
	for i in copy.get_surface_count():
		var base := copy.surface_get_material(i) as BaseMaterial3D
		if base:
			var tinted := base.duplicate() as BaseMaterial3D
			tinted.vertex_color_use_as_albedo = true
			copy.surface_set_material(i, tinted)
	return copy
