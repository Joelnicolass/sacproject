@tool
class_name VegetationSpecies
extends Resource

## How one species of plant looks: which mesh, how big, how far it shows. A FloraLayer or a
## VegetationPatch holds one (data/vegetation/species/<name>.tres). The mesh is a
## scenes/props/meshes/<tag>.res with its material saved, shared by every instance. A type template:
## never mutated at runtime.

## The plant tag (CAH1, PYA2...). FloraPlacement hashes it, so it decides where the plants of a cell
## stand: do not rename it on a species a map already uses.
@export var tag := ""
## The plant it draws: drag a scenes/props/meshes/<tag>.res here.
@export var mesh: Mesh
## Off by default: plants cast no shadow. A preset can also turn every shadow of a layer off.
@export var cast_shadow := false
## Camera distance where this species is gone (it dithers out over the layer's `fade_m` before). 0 =
## the layer's radius.
@export_range(0.0, 400.0, 1.0, "suffix:m") var visibility_end_m := 0.0

@export_group("Variation")
## Uniform scale of an instance, picked per instance by FloraPlacement between x and y.
@export var scale_range := Vector2(0.75, 1.3)
## Extra height stretch: each plant is taller or shorter than its width by up to this fraction (0.1
## = +-10 %).
@export_range(0.0, 0.5, 0.01) var height_jitter := 0.1
## The colors an instance is multiplied by: the darkest and the lightest plant. Each plant lies
## between them.
@export var tint_dark := Color(0.88, 0.9, 0.85)
@export var tint_light := Color(1.08, 1.1, 1.0)
## 0: the tint is picked per plant. Above 0: it follows blotches of this size in meters (value noise
## on the map), so a meadow has darker and lighter patches.
@export_range(0.0, 100.0, 0.5, "suffix:m") var tint_cluster_m := 0.0
## Each plant leans up to this angle away from vertical, toward a hashed direction.
@export_range(0.0, 30.0, 0.5, "suffix:deg") var tilt_max_deg := 4.0
@export_group("")


## The tag FloraPlacement hashes: `tag`, or the name of the mesh file for a species made by hand
## without one.
func density_tag() -> String:
	if not tag.is_empty() or mesh == null:
		return tag
	return mesh.resource_path.get_file().get_basename()


## The numbers FloraVariation.instance_transform / instance_color read, as plain values (a planting
## task copies these, never the Resource).
func variation() -> Dictionary:
	return {
		"scale_range": scale_range,
		"height_jitter": height_jitter,
		"tint_dark": tint_dark,
		"tint_light": tint_light,
		"tint_cluster_m": tint_cluster_m,
		"tilt_max_deg": tilt_max_deg
	}
