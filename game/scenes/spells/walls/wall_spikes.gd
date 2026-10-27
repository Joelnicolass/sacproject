class_name WallSpikes
extends MultiMeshInstance3D

## The spikes of a Wall of Spikes: `count` of them are born one after another while the wall's ends grow, each near an end that is still
## moving and somewhere across the thickness, grow in half a second, stand leaning every which way and sink in a second when the wall does.
## They are the mesh of the Rhinok's spikes (SpikeField); their skin is the `material_override` of this node in the scene (the texture is a
## Texture2D dragged onto that material). Presentation only, on every peer, from the wall's age
## and ends; it does not hurt anybody (WallTouch) and its dice are its own. The wall must be the parent.
## Ref: sacengine WallOfSpikes, makeWallOfSpikesSpike (state.d:3898-3937, 20504-20538, 20608-20662; renderer.d:2626-2655).

@export var wall: SpellWall
@export_range(1, 400) var count := 180
## Width of a spike (a 1.5 scale) and how high and how far over it leans, in metres.
@export_range(0.5, 4.0, 0.1) var spike_scale := 1.5
@export_range(0.5, 8.0, 0.1, "suffix:m") var spike_height := 3.0
@export_range(0.0, 6.0, 0.1, "suffix:m") var lean_m := 3.0
## A spike is born within this many metres of an end.
@export_range(0.0, 10.0, 0.1, "suffix:m") var near_end_m := 1.5
@export_range(0.05, 5.0, 0.05, "suffix:s") var grow_s := 0.5
@export_range(0.05, 5.0, 0.05, "suffix:s") var vanish_s := 1.0
@export var sides := 12

var _born := PackedInt32Array()
var _bases := PackedVector3Array()
var _axes := PackedVector3Array()
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if wall == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	MatchSeed.seed_rng(_rng, ["wall_spikes", String(wall.name)])
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = SpikeField.spike_mesh(sides, 0.3, 0.25, 0.75)
	multimesh.instance_count = count
	custom_aabb = AABB(Vector3(-wall.reach_m() - 5.0, -5.0, -10.0), Vector3(2.0 * wall.reach_m() + 10.0, 20.0, 20.0))
	_born.resize(count)
	_born.fill(-1)
	_bases.resize(count)
	_axes.resize(count)
	for i in count:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _process(_delta: float) -> void:
	while _next < count and wall.vanish_at < 0 and wall.age * count >= wall.grow_ticks * _next:
		_born_at(_next, ceili(float(wall.grow_ticks * _next) / float(count)))
		_next += 1
	for i in _next:
		var grown := clampf(float(minf(wall.age, wall.vanish_at if wall.vanish_at >= 0 else wall.age) - _born[i]) / (grow_s * MatchClock.TICKS_PER_SECOND_F), 0.0, 1.0)
		if wall.vanish_at >= 0:
			grown = maxf(0.0, grown - float(wall.age - wall.vanish_at) / (vanish_s * MatchClock.TICKS_PER_SECOND_F))
		var width := spike_scale * grown
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3(width, 0.0, 0.0), _axes[i] * grown, Vector3(0.0, 0.0, width)), _bases[i]))


## The spike `index` is born at `age`, near one of the ends and leaning every which way.
func _born_at(index: int, age: int) -> void:
	var at_left := _rng.randi_range(0, 1) == 1
	var t := _rng.randf_range(wall.left, minf(wall.left + near_end_m, wall.right)) if at_left else _rng.randf_range(maxf(wall.right - near_end_m, wall.left), wall.right)
	var across := 0.5 * wall.thickness_m() * _rng.randf_range(-1.0, 1.0)
	var land := wall.ground_y(wall.center.x + wall.direction.x * t, wall.center.z + wall.direction.y * t) - wall.global_position.y
	_born[index] = age
	_bases[index] = Vector3(t, land, across)
	var way := _rng.randf() * TAU
	var lean := sqrt(_rng.randf()) * lean_m
	_axes[index] = Vector3(cos(way) * lean, spike_height * _rng.randf_range(0.4, 1.6), sin(way) * lean)
