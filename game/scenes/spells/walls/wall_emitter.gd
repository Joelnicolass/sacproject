class_name WallEmitter
extends Node3D

## Sprites that rise from a wall: from along all of it (the Firewall's tongues of flame) or only from one of its ends while that end is
## still growing (the flames, dust and sparks of the advancing front). It moves its SpriteEmitter child over the wall every frame and sets
## how many it emits; what a sprite looks like is the child's ParticleType. Presentation only, on every peer; it does not hurt anybody.

enum Where { ALONG, LEFT_END, RIGHT_END }

@export var wall: SpellWall
@export var emitter: SpriteEmitter
@export var where := Where.ALONG
## Particles a second for every metre of wall (ALONG), or in all (an end).
@export_range(0.0, 20.0, 0.05) var rate := 1.0
## ALONG: the box of the emission goes from this fraction of the wall's height to that one.
@export var heights := Vector2(0.25, 0.75)
## An end: the front is this many metres wide, along the wall and across it (the sprites spread over the thickness).
@export_range(0.0, 10.0, 0.1, "suffix:m") var front_m := 1.5


func _ready() -> void:
	if wall == null or emitter == null or DisplayServer.get_name() == "headless":
		set_process(false)


func _process(_delta: float) -> void:
	var live := _live()
	emitter.set_active(live)
	if not live:
		return
	var across := 0.45 * wall.thickness_m()
	var low := heights.x * wall.top()
	var high := heights.y * wall.top()
	var box := Vector3(0.5 * (wall.right - wall.left), 0.5 * (high - low), across)
	var at := Vector3(0.5 * (wall.left + wall.right), 0.5 * (high + low), 0.0)
	if where != Where.ALONG:
		var end := wall.left if where == Where.LEFT_END else wall.right
		box = Vector3(0.5 * front_m, 0.0, across)
		at = Vector3(end, 0.0, 0.0)
	emitter.position = at + Vector3(0.0, wall.ground_y(wall.center.x + wall.direction.x * at.x, wall.center.z + wall.direction.y * at.x) - wall.center.y, 0.0)
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = box
	emitter.set_rate(rate * (wall.right - wall.left) if where == Where.ALONG else rate)


## It runs while there is wall to rise from, or while the ends can still be going out.
func _live() -> bool:
	if where == Where.ALONG:
		return wall.top() > 0.0 and wall.right > wall.left
	return wall.vanish_at < 0 and wall.age < wall.grow_ticks + 30 and wall.right > wall.left
