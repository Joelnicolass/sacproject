@tool
class_name CloudLook
extends Node3D

## The storm cloud of a zone, on every peer, from its replicated phase: twenty layers of a noisy sphere (a MultiMesh) that swell while the
## wizard casts and while the zone acts, and shrink away when it ends or the cast is cut. The cloud is wider than tall and its radius is a
## share of the spell's effect range (or a fixed one). It does not drop anything (ZoneDropper) nor time the zone (GroundZone).
## Ref: sacengine SacCloud, SacCloud2, renderCloud (sacobject.d:2778-2819, renderer.d:451-475, 1844-1853, 2477-2486).

@export var zone: GroundZone
## The layers: a MultiMeshInstance3D of a unit sphere with the cloud_sphere shader.
@export var layers: MultiMeshInstance3D
## The radius of the cloud: this share of the spell's effect range, unless `fixed_radius_m` says one.
@export_range(0.0, 2.0, 0.01) var radius_share := 1.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var fixed_radius_m := 0.0
## Wider than tall, as the original's cloud (radius times this).
@export var shape := Vector3(1.3, 0.4, 1.3)
## The mean radius of a noisy layer, as a share of its largest (the sphere of the mesh has radius 0.5 on average).
@export_range(0.5, 1.0, 0.01) var mean_radius := 0.84
@export_range(1, 40) var layer_count := 20
## Each layer is this much smaller than the one before (Cloudkill's layers thin out; Rain's do not).
@export_range(0.0, 0.1, 0.001) var layer_shrink := 0.0
## How far the drift of each layer is from the one before, in layers of drift (the original: 4 s of an 8 s layer).
@export_range(0.0, 2.0, 0.05) var layer_drift := 0.5
## The share of the cloud that grows in a second while the zone lives, and shrinks in a second when it ends.
@export_range(0.05, 5.0, 0.01, "suffix:/s") var grow_per_s := 0.5
@export_range(0.05, 5.0, 0.01, "suffix:/s") var shrink_per_s := 1.0

var _size := 0.0


func _ready() -> void:
	if layers == null or layers.multimesh == null:
		return
	var multimesh := layers.multimesh
	multimesh.use_custom_data = true
	multimesh.instance_count = layer_count
	for i in layer_count:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (1.0 - layer_shrink * i)), Vector3.ZERO))
		multimesh.set_instance_custom_data(i, Color(layer_drift * i, 0.0, 0.0, 0.0))
	set_process(not Engine.is_editor_hint() and zone != null and DisplayServer.get_name() != "headless")
	visible = false


func _process(delta: float) -> void:
	var ending := zone.phase == GroundZone.Phase.ENDING
	_size = clampf(_size + (-shrink_per_s if ending else grow_per_s) * delta, 0.0, 1.0)
	visible = _size > 0.001
	var radius := fixed_radius_m if fixed_radius_m > 0.0 else zone.spell.effect_range * radius_share
	layers.scale = shape * radius * (0.5 + 0.5 * _size) * 2.0 * mean_radius
	layers.set_instance_shader_parameter(&"size", _size)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null and layers != null else PackedStringArray(["Faltan la zona (GroundZone) y las capas (MultiMeshInstance3D)."])
