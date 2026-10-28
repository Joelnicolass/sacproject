class_name CastBolts
extends FxScene

## The little bolts that climb around a wizard while he casts Chain Lightning: at each tick, half the time, a short bolt is born at a
## random point of his box (a bit larger than it) and rises a few metres. FxBus plays it on this peer only; the scene frees itself when
## the casting ends. It is a presentation that LaunchAction hands to FxBus.broadcast_scene (`play`); it hurts nothing and the cast does
## not wait for it.

## The little bolt (a BeamType under data/fx/beams/).
@export var beam: BeamType
## Chance per tick of a new bolt.
@export_range(0.0, 1.0, 0.05) var chance := 0.5
## The box of the wizard grows by this before a point is picked in it.
@export_range(1.0, 3.0, 0.05) var box_scale := 1.5
## A bolt rises between these metres.
@export_range(0.0, 10.0, 0.05, "suffix:m") var rise_min_m := 1.5
@export_range(0.0, 10.0, 0.05, "suffix:m") var rise_max_m := 3.25

var _wizard: Node3D
var _ticks := 0
var _rng := RandomNumberGenerator.new()


## FxBus.broadcast_scene: `ticks` the casting lasts and the `wizard` path.
func play(params: Dictionary) -> void:
	_ticks = maxi(1, int(params.get("ticks", 1)))
	_wizard = get_tree().root.get_node_or_null(NodePath(str(params.get("wizard", "")))) as Node3D
	MatchSeed.seed_rng(_rng, ["cast_bolts", str(params.get("wizard", "")), MatchClock.now()])
	set_physics_process(_wizard != null and beam != null)
	if _wizard == null or beam == null:
		queue_free()


func _physics_process(_delta: float) -> void:
	_ticks -= 1
	if _wizard == null or not is_instance_valid(_wizard) or _ticks < 0:
		queue_free()
		return
	if _rng.randf() >= chance:
		return
	var box := BodyNudge.box(_wizard)
	var size := box.size * box_scale
	var low := box.get_center() - size * 0.5
	var start := low + Vector3(_rng.randf() * size.x, _rng.randf() * size.y, _rng.randf() * size.z)
	FxBus.play_beam(beam, start, start + Vector3(0.0, _rng.randf_range(rise_min_m, rise_max_m), 0.0))
