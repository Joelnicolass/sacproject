class_name IcePatch
extends MeshInstance3D

## The ice of Frozen Ground as a ring of mesh glued to the land: built once when the ice starts to grow, with every vertex on the height of
## the land under it, and drawn by ice_ground.gdshader, which shows only the band between what already broke and how far the ice grew.
## Presentation only, on every peer, from the zone's phase. It freezes nobody (ZoneFreeze) and hurts nobody (ZoneShatter).
## Ref: sacengine GroundPatch and updateFrozenGround (renderer.d:3369-3411, state.d:3632-3646).

@export var zone: GroundZone
@export_range(8, 64) var sides := 32
@export_range(4, 64) var rings := 32
## The texture goes round the circle this many times, and repeats this many times from the centre to the rim.
@export_range(1.0, 32.0, 1.0) var turns := 12.0
@export_range(1.0, 32.0, 1.0) var repeats := 6.0
## How far over the land the ice floats, above the blades of grass.
@export_range(0.0, 2.0, 0.05, "suffix:m") var lift_m := 0.5
## The ice breaks in this many steps of the zone's ending (the steps of ZoneShatter).
@export_range(1, 12) var break_steps := 6

var _radius := 0.0


func _ready() -> void:
	set_process(false)
	visible = false
	if Engine.is_editor_hint() or zone == null:
		return
	zone.phase_changed.connect(_on_phase)
	_on_phase(zone.phase)


func _on_phase(phase: int) -> void:
	if phase == GroundZone.Phase.ACTIVE and mesh == null:
		_build()
	visible = phase >= GroundZone.Phase.ACTIVE and mesh != null
	set_process(visible)


func _process(_delta: float) -> void:
	var broken := 0
	if zone.phase == GroundZone.Phase.ENDING:
		broken = floori(float(zone.phase_ticks) / float(maxi(zone.end_ticks(), 1)) * float(break_steps))
	set_instance_shader_parameter(&"radius", zone.grown_m(_radius))
	set_instance_shader_parameter(&"inner", ZoneRules.ring_radius(broken, break_steps, _radius))


## The ring at the full radius, every vertex at the height of the land under it (the centre's height where there is none).
func _build() -> void:
	_radius = zone.spell.effect_range_m
	var center := zone.points[0]
	var land := TerrainShape.of(self)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings:
		for side in sides:
			var corners := [[ring, side], [ring + 1, side], [ring, side + 1], [ring, side + 1], [ring + 1, side], [ring + 1, side + 1]]
			for corner: Array in corners:
				var uv := Vector2(float(corner[1]) / float(sides) * turns, float(corner[0]) / float(rings) * repeats)
				surface.set_uv(uv)
				surface.add_vertex(_vertex(land, center, corner[0], corner[1]))
	surface.generate_normals()
	mesh = surface.commit()


func _vertex(land: TerrainShape, center: Vector3, ring: int, side: int) -> Vector3:
	var angle := TAU * float(side) / float(sides)
	var at := center + Vector3(cos(angle), 0.0, sin(angle)) * _radius * float(ring) / float(rings)
	var height := land.height_at(at.x, at.z) if land != null else NAN
	return Vector3(at.x - center.x, (center.y if is_nan(height) else height) - center.y + lift_m, at.z - center.z)
