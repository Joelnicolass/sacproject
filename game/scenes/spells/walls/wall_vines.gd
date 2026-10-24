class_name WallVines
extends MultiMeshInstance3D

## The vines of a Vinewall: `count` of them are born one after another while the wall's ends grow, each near an end and somewhere across the
## thickness, and rise to the height of the wall swaying and twisting until the wall sinks and they shrink back. One tube mesh drawn
## `count` times; the shader (wall_vine.gdshader) bends each by its own phase and growth, so no vine needs a skeleton. Presentation only,
## on every peer, from the wall's age and ends; it does not tie anybody (WallTouch).
## Ref: sacengine Vinewall, makeVinewallVine (state.d:3813-3873, 20336-20368, 20412-20464; renderer.d:2232-2259).

@export var wall: SpellWall
@export_range(1, 400) var count := 180
## Scale of a vine (its root is 0.1 m of radius times this).
@export_range(0.5, 10.0, 0.05) var vine_scale := 4.5
@export_range(0.0, 10.0, 0.1, "suffix:m") var near_end_m := 1.5

var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if wall == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	MatchSeed.seed_rng(_rng, ["wall_vines", String(wall.name)])
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_custom_data(i, Color(1000000.0, 0.0, 0.0, 0.0))
	custom_aabb = AABB(Vector3(-wall.reach_m() - 5.0, -5.0, -10.0), Vector3(2.0 * wall.reach_m() + 10.0, 20.0, 20.0))
	var shader := material_override as ShaderMaterial
	shader.set_shader_parameter(&"height_m", wall.height_m())
	shader.set_shader_parameter(&"vanish_len_s", wall.vanish_s)


func _process(_delta: float) -> void:
	while _next < count and wall.vanish_at < 0 and wall.age * count >= wall.grow_ticks * _next:
		_born_at(_next, float(ceili(float(wall.grow_ticks * _next) / float(count))) / MatchClock.TICKS_PER_SECOND_F)
		_next += 1
	var shader := material_override as ShaderMaterial
	shader.set_shader_parameter(&"age_s", float(wall.age) / MatchClock.TICKS_PER_SECOND_F)
	shader.set_shader_parameter(&"vanish_at_s", float(wall.vanish_at) / MatchClock.TICKS_PER_SECOND_F if wall.vanish_at >= 0 else 1000000.0)


## The vine `index` is born at second `born_s`, near one of the ends.
func _born_at(index: int, born_s: float) -> void:
	var at_left := _rng.randi_range(0, 1) == 1
	var t := _rng.randf_range(wall.left, minf(wall.left + near_end_m, wall.right)) if at_left else _rng.randf_range(maxf(wall.right - near_end_m, wall.left), wall.right)
	var across := 0.5 * wall.thickness_m() * _rng.randf_range(-1.0, 1.0)
	var land := wall.ground_y(wall.center.x + wall.direction.x * t, wall.center.z + wall.direction.y * t) - wall.global_position.y
	multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(t, land, across)))
	multimesh.set_instance_custom_data(index, Color(born_s, _rng.randf_range(0.9, 1.1) * vine_scale, _rng.randf() * TAU, 0.0))
