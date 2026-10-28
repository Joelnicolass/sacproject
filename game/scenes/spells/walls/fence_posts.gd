@tool
class_name FencePosts
extends Node3D

## The posts of a Fence: two are born every 32 ticks while its ends grow (the first at tick 16), one at each end, up to twelve. Each
## floats between `low_m` and `high_m` over the land with a swing of `swing_s`, grows in half a second and shrinks away when the wall sinks.
## The server decides when a post is born; `posts` (metres along the wall and the tick of birth, sorted by metre) is replicated, and every
## peer derives a post's height and size from it and the wall's age. It draws each as a violet bubble with a ring of sparks over it. It does
## not hurt anybody (FenceZap).

## A post was born (server only): `at` is its place. FenceZap throws its first bolts.
signal post_born(at: Vector3)

@export var wall: SpellWall
@export_range(1, 24) var max_posts := 12
## Time between two births (one pair per period), and when in the period the pair is born.
@export_range(0.0333, 4.0, 0.0001, "suffix:s") var period_s := 0.5333
@export_range(0.0, 4.0, 0.0001, "suffix:s") var birth_s := 0.2666
@export_range(0.5, 10.0, 0.1, "suffix:m") var low_m := 2.5
@export_range(0.5, 10.0, 0.1, "suffix:m") var high_m := 5.5
@export_range(0.5, 20.0, 0.1, "suffix:s") var swing_s := 3.6
@export_range(0.05, 5.0, 0.05, "suffix:s") var grow_s := 0.5
@export_range(0.05, 5.0, 0.05, "suffix:s") var shrink_s := 1.0
## Width of the sprite in metres and the bubbles' and sparks' multi meshes.
@export_range(0.5, 10.0, 0.1, "suffix:m") var sprite_m := 3.0
@export var bubbles: MultiMeshInstance3D
@export var sparks: MultiMeshInstance3D

## Replicated: (metres along the wall, tick of birth) of every post, by metre.
var posts := PackedVector2Array()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if wall != null else PackedStringArray(["The SpellWall is missing."])


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		return
	if not multiplayer.is_server():
		set_physics_process(false)
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _physics_process(_delta: float) -> void:
	var birth_tick := MatchClock.ticks_for(birth_s)
	if (
		wall.vanish_at >= 0
		or wall.age < birth_tick
		or (wall.age - birth_tick) % maxi(1, MatchClock.ticks_for(period_s)) != 0
	):
		return
	for side in [-1.0, 1.0]:
		if posts.size() >= max_posts or (wall.left_stopped if side < 0.0 else wall.right_stopped):
			continue
		_add(Vector2(wall.left if side < 0.0 else wall.right, float(wall.age)))


func _add(post: Vector2) -> void:
	var sorted := Array(posts)
	sorted.append(post)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	posts = PackedVector2Array(sorted)
	post_born.emit(position_of(post))


## 0 to 1: how grown the post is now (it grows after its birth and shrinks once the wall sinks).
func scale_of(post: Vector2) -> float:
	var live := wall.age if wall.vanish_at < 0 else wall.vanish_at
	var grown := clampf(float(live - int(post.y)) / float(MatchClock.ticks_for(grow_s)), 0.0, 1.0)
	if wall.vanish_at < 0:
		return grown
	return maxf(
		0.0, grown - float(wall.age - wall.vanish_at) / float(MatchClock.ticks_for(shrink_s))
	)


## Where the post floats now.
func position_of(post: Vector2) -> Vector3:
	var swing := (
		0.5
		* (
			1.0
			- cos(TAU * float(wall.age - int(post.y)) / (swing_s * MatchClock.TICKS_PER_SECOND_F))
		)
	)
	var at := wall.point_at(post.x)
	at.y += swing * low_m + (1.0 - swing) * high_m
	return at


func _process(_delta: float) -> void:
	if bubbles == null or sparks == null or posts.is_empty():
		return
	for layer in [bubbles, sparks]:
		layer.multimesh.visible_instance_count = posts.size()
	for i in posts.size():
		var scale_now := scale_of(posts[i]) * sprite_m
		var placed := Transform3D(Basis.from_scale(Vector3.ONE * scale_now), position_of(posts[i]))
		bubbles.multimesh.set_instance_transform(i, placed)
		sparks.multimesh.set_instance_transform(i, placed)
