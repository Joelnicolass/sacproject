class_name WallLightFollow
extends Node

## Keeps the one light of a wall (an ActorLight, the spell's colour) where it is seen: a wall is up to 110 m long and a light has a short
## range, so it stands at the point of the wall closest to the listener (or, for the Fence, at the post closest to him), half way up,
## lit while the wall stands and dim when it sinks. The budget decides whether it shows (ActorLightBudget). Presentation only, on every
## peer; it does not draw the wall (the look) nor hurt anybody.

@export var wall: SpellWall
@export var light: ActorLight
## The Fence: the light goes to the post closest to the listener instead of the wall.
@export var posts: FencePosts
## Seconds the light takes to come on or go out.
@export_range(0.0, 5.0, 0.1, "suffix:s") var fade_s := 0.5

var _on := false


func _ready() -> void:
	if wall == null or light == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	light.set_lit(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(light):
		set_process(false)
		return
	var wanted := wall.top() > 0.0 if posts == null else not posts.posts.is_empty() and wall.vanish_at < 0
	if wanted != _on:
		_on = wanted
		light.set_lit(wanted, fade_s)
	if not wanted:
		return
	var ear := SoundBus.listener_position()
	if posts != null:
		light.global_position = _nearest_post(ear)
		return
	var along := clampf(WallRules.along(ear if ear != Vector3.INF else wall.center, wall.center, wall.direction), wall.left, wall.right)
	var at := wall.point_at(along)
	at.y += 0.5 * wall.top()
	light.global_position = at


func _nearest_post(ear: Vector3) -> Vector3:
	var best := wall.center
	var best_gap := INF
	for post in posts.posts:
		var at := posts.position_of(post)
		var gap := at.distance_to(ear) if ear != Vector3.INF else 0.0
		if gap < best_gap:
			best = at
			best_gap = gap
	return best
