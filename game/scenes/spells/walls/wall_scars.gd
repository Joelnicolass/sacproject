class_name WallScars
extends Node

## The cracks a wall leaves in the ground as its ends advance: every `every_s` of the wall's age, while the ends can still be going out,
## it asks its ScarMark to paint at each end, somewhere across the thickness and up to `behind_m` behind the front. The Firewall leaves
## `quk1`, the Wall of Spikes `gscr`. Presentation only, on every peer (each one sees the wall grow and paints it), never at a dedicated or
## headless process (ScarMark); it does not touch the rules. Its dice are its own.

@export var wall: SpellWall
## The mark and the picture (texture, height limit) that is painted.
@export var mark: ScarMark
@export_range(0.0166, 2.0, 0.0001, "suffix:s") var every_s := 0.0666
@export_range(0.0, 10.0, 0.1, "suffix:m") var behind_m := 1.5

var _rng: RandomNumberGenerator
var _done := -1


func _ready() -> void:
	if wall == null or mark == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng = MatchSeed.rng(["wall_scars", String(wall.name)])


func _process(_delta: float) -> void:
	if wall.vanish_at >= 0 or wall.age > wall.grow_ticks:
		return
	var step := wall.age / maxi(1, MatchClock.ticks_for(every_s))
	while _done < step:
		_done += 1
		for end in [wall.left, wall.right]:
			_paint(end)


func _paint(end: float) -> void:
	if absf(end) < 0.01:
		return
	var t := end - signf(end) * _rng.randf_range(0.0, behind_m)
	var across := (
		WallRules.across(wall.direction) * (0.45 * wall.thickness_m() * _rng.randf_range(-1.0, 1.0))
	)
	var at := wall.point_at(t)
	mark.mark_at(Vector3(at.x + across.x, at.y, at.z + across.y))
