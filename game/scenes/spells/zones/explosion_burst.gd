class_name ExplosionBurst
extends Node3D

## The look of one blast, played on every peer by FxBus.broadcast_scene at each point of an Explosion: two spheres of fire that swell (a big one
## and a small one), and the rocks it throws. The sprites of the blast (xplo, exp2, ash, smoke) are bursts the zone plays beside it; the sound
## is the one of this scene's file name in the sound table. Presentation only; it frees itself. It does not hurt anyone (ZoneBlast).
## Ref: sacengine explosionAnimation and animateDebris (state.d:27625-27642).

## The spheres, scaled from nothing: each is a unit-diameter sphere.
@export var big: MeshInstance3D
@export var small: MeshInstance3D
## The burn it leaves on the ground (061k-5), painted when the blast starts.
@export var scar: ScarMark
## The rock that flies off, and how many.
@export var piece: PackedScene
@export_range(0, 64) var pieces := 15
@export_group("Spheres")
@export_range(1.0, 60.0, 0.5, "suffix:m") var big_radius_m := 30.0
@export_range(1.0, 100.0, 0.5, "suffix:m/s") var big_speed := 40.0
@export_range(1.0, 60.0, 0.5, "suffix:m") var small_radius_m := 5.0
@export_range(1.0, 100.0, 0.5, "suffix:m/s") var small_speed := 10.0
## The spheres are wider than tall by this, as the original's (1.1, 1.1, 0.9).
@export var squash := Vector3(1.1, 0.9, 1.1)
## The last share of a sphere's growth in which it fades out.
@export_range(0.0, 1.0, 0.05) var fade_share := 0.3
@export_group("Rocks")
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var throw_speed := 20.0
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var throw_jitter := 5.0
## Spin of a rock, in turns per second.
@export var spin_turns := Vector2(0.5, 2.0)


func play(_params: Dictionary) -> void:
	if scar != null:
		scar.mark()
	_swell(big, big_radius_m / big_speed, big_radius_m)
	_swell(small, small_radius_m / small_speed, small_radius_m)
	_throw()
	get_tree().create_timer(4.0).timeout.connect(queue_free)


func _swell(sphere: MeshInstance3D, seconds: float, radius: float) -> void:
	if sphere == null:
		return
	sphere.scale = Vector3.ONE * 0.01
	sphere.set_instance_shader_parameter(&"fade", 1.0)  # the tween needs a start value
	var tween := create_tween().set_parallel()
	tween.tween_property(sphere, "scale", squash * radius * 2.0, seconds)
	tween.tween_property(sphere, "instance_shader_parameters/fade", 0.0, seconds * fade_share).set_delay(seconds * (1.0 - fade_share))
	tween.chain().tween_callback(sphere.hide)


func _throw() -> void:
	if piece == null:
		return
	var rng := MatchSeed.rng(["explosion_burst", global_position])
	for i in pieces:
		var angle := rng.randf_range(-PI, PI)
		var direction := Vector3(cos(angle), rng.randf_range(0.5, 2.0), sin(angle)).normalized()
		var rock := piece.instantiate() as DebrisPiece
		add_child(rock)
		rock.launch(direction * (throw_speed + rng.randf_range(-throw_jitter, throw_jitter)), _axis(rng), TAU * rng.randf_range(spin_turns.x, spin_turns.y))


func _axis(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if big != null and small != null else PackedStringArray(["Faltan las dos esferas (big y small)."])
