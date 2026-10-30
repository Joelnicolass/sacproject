@tool
class_name CloudLook
extends Node3D

## The storm cloud of a zone, on every peer, from its replicated phase: twenty layers of a noisy
## sphere (a MultiMesh) that swell while the wizard casts and while the zone acts, and shrink away
## when it ends or the cast is cut. The cloud is wider than tall and its radius is a share of the
## spell's effect range (or a fixed one). It does not drop anything (ZoneDropper) nor time the zone
## (GroundZone).

@export var zone: GroundZone
## The layers: a MultiMeshInstance3D of a unit sphere with the cloud_sphere shader (its MultiMesh
## uses custom data and has no instances: this sets them).
@export var layers: MultiMeshInstance3D
## The radius of the cloud: this share of the spell's effect range, unless `fixed_radius_m` says
## one.
@export_range(0.0, 2.0, 0.01) var radius_share := 1.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var fixed_radius_m := 0.0
## Wider than tall, as the original's cloud (radius times this).
@export var shape := Vector3(1.3, 0.4, 1.3)
## The shader draws the original's lumpy sphere in its own units (radius 1 at the most); this scales
## it (1 = as the original).
@export_range(0.5, 1.5, 0.01) var mean_radius := 1.0
@export_range(1, 40) var layer_count := 20
## Each layer is this much smaller than the one before (Cloudkill's layers thin out; Rain's do not:
## 0).
@export_range(0.0, 0.1, 0.001) var layer_shrink := 0.0
## Where each layer is in the noise relative to the one before (the shader's INSTANCE_CUSTOM.x): the
## lumps of every layer differ, as the original's twenty random shapes do. 0 would pile twenty
## identical spheres into one flat, solid oval.
@export_range(0.0, 20.0, 0.05) var layer_drift := 7.13
## The share of the cloud that grows in a second while the zone lives, and shrinks in a second when
## it ends.
@export_range(0.05, 5.0, 0.01, "suffix:/s") var grow_per_s := 0.5
@export_range(0.05, 5.0, 0.01, "suffix:/s") var shrink_per_s := 1.0

var _size := 0.0


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	if layers == null or layers.multimesh == null:
		return
	var multimesh := layers.multimesh
	if multimesh.instance_count != layer_count:
		multimesh.instance_count = layer_count
		for i in layer_count:
			multimesh.set_instance_transform(
				i,
				Transform3D(Basis.from_scale(Vector3.ONE * (1.0 - layer_shrink * i)), Vector3.ZERO)
			)
			multimesh.set_instance_custom_data(i, Color(layer_seed(i), 0.0, 0.0, 0.0))
	set_process(
		not Engine.is_editor_hint() and zone != null and DisplayServer.get_name() != "headless"
	)
	visible = false


## Where layer `i` stands in the noise.
func layer_seed(i: int) -> float:
	return layer_drift * float(i)


func _process(delta: float) -> void:
	var ending := zone.phase == GroundZone.Phase.ENDING
	_size = clampf(_size + (-shrink_per_s if ending else grow_per_s) * delta, 0.0, 1.0)
	visible = _size > 0.001
	var radius := (
		fixed_radius_m if fixed_radius_m > 0.0 else zone.spell.effect_range_m * radius_share
	)
	layers.scale = shape * radius * (0.5 + 0.5 * _size) * 2.0 * mean_radius
	InstanceParams.set_on(layers, &"size", _size)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null and layers != null
		else PackedStringArray(
			["The zone (GroundZone) and the layers (MultiMeshInstance3D) are missing."]
		)
	)
