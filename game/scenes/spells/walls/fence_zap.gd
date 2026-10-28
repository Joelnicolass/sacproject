@tool
class_name FenceZap
extends Node

## The lightning of a Fence: the posts hold a charge that leaks as bolts. A post strikes every creature or wizard (not the caster) within
## `strike_range_m` with chance `strike_per_s` a second, for the spell's damage as lightning; neighbours arc to each other when one holds
## more charge than the other (waiting 1 to 2 s between arcs); and a post sometimes discharges to the ground 5 to 15 m away. Charge moves
## with every bolt and the posts share what is left. A new post throws three to five bolts at itself from 10 m. It does not make or place the
## posts (FencePosts) and the bolt is drawn by FxBus. Server (or solo) only; its dice are the match's, seeded by the wall.

@export var wall: SpellWall
@export var posts: FencePosts
@export var bolt: BeamType
@export var strike_range_m := 10.0
@export_range(0.0, 3.0, 0.05) var strike_per_s := 0.9
## Chance per second of an arc between neighbours and of a discharge to the ground, per post, at no charge (shared out among the other posts).
@export_range(0.0, 3.0, 0.05) var arc_per_s := 0.3
@export_range(0.0, 3.0, 0.05) var discharge_per_s := 0.3
@export var ground_reach_m := Vector2(5.0, 15.0)
@export var birth_bolts := Vector2i(3, 5)
@export var birth_reach_m := 10.0

var _rng := RandomNumberGenerator.new()
## Per post (its `posts` entry): charge, ticks until it may arc left and right.
var _charge := {}
var _left := {}
var _right := {}


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if wall != null and posts != null and bolt != null
		else PackedStringArray(["The wall, posts and bolt are missing."])
	)


func _ready() -> void:
	if Engine.is_editor_hint() or not multiplayer.is_server():
		set_physics_process(false)
		return
	MatchSeed.seed_rng(_rng, ["fence", String(wall.name)])
	posts.post_born.connect(_on_post_born)


func _physics_process(_delta: float) -> void:
	if wall.vanish_at >= 0 or posts.posts.is_empty():
		return
	var list := posts.posts
	var n := list.size()
	var rate := 1.0 / (float(posts.max_posts - 1) * MatchClock.TICKS_PER_SECOND_F)
	var excess := 0.0
	for i in n:
		var key := list[i]
		var charge: float = _charge.get(key, 0.0)
		if i > 0:
			_left[key] = int(_left.get(key, 0)) - 1
			if int(_left[key]) <= 0:
				_left[key] = 0
				if _rng.randf() < arc_per_s * rate + charge - float(_charge.get(list[i - 1], 0.0)):
					_arc(key, list[i - 1])
		if i + 1 < n:
			_right[key] = int(_right.get(key, 0)) - 1
			if int(_right[key]) <= 0:
				_right[key] = 0
				if _rng.randf() < arc_per_s * rate + charge - float(_charge.get(list[i + 1], 0.0)):
					_arc(key, list[i + 1])
		if _rng.randf() < discharge_per_s * rate + 0.1 * absf(charge):
			excess += _discharge(key, list, charge)
		if posts.scale_of(key) >= 1.0:
			excess += _strike(key)
	var damp := pow(0.5, 1.0 / MatchClock.TICKS_PER_SECOND_F)
	for key in list:
		var charge: float = _charge.get(key, 0.0)
		excess += charge * (1.0 - damp)
		_charge[key] = charge * damp
	excess /= float(n)
	for key in list:
		_charge[key] = float(_charge[key]) + excess


## A bolt from post `from` to its neighbour `to`: some charge moves over and both wait 1 to 2 s before the next arc on the sides that met.
func _arc(from: Vector2, to: Vector2) -> void:
	_zap(posts.position_of(from), posts.position_of(to), null)
	var moved := _rng.randf_range(0.01, 0.02)
	_charge[from] = float(_charge.get(from, 0.0)) - moved
	_charge[to] = float(_charge.get(to, 0.0)) + moved
	var wait := MatchClock.TICKS_PER_SECOND
	var going_left := to.x < from.x
	(_left if going_left else _right)[from] = _rng.randi_range(wait, 2 * wait)
	(_right if going_left else _left)[to] = _rng.randi_range(wait, 2 * wait)


## The post lets its charge go: half to a post at random, half to the air; a bolt to the ground. Returns what goes to the air.
func _discharge(key: Vector2, list: PackedVector2Array, charge: float) -> float:
	_charge[key] = 0.0
	var spilt := 0.0
	if _rng.randi_range(0, 1) == 1:
		var other := list[_rng.randi_range(0, list.size() - 1)]
		_charge[other] = float(_charge.get(other, 0.0)) + charge
	else:
		spilt = charge
	var around := (
		Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
		* _rng.randf_range(ground_reach_m.x, ground_reach_m.y)
	)
	var from := posts.position_of(key)
	var end := from + around
	end.y = wall.ground_y(end.x, end.z)
	_zap(from, end, null)
	return spilt


## Strikes the bodies near a post (not the caster, who only sees the bolt); returns the charge they took.
func _strike(key: Vector2) -> float:
	var at := posts.position_of(key)
	var taken := 0.0
	for body in SplashDamage.bodies_within(
		get_tree(), at, strike_range_m, null, [&"wizard", &"unit"]
	):
		if _rng.randf() >= strike_per_s / MatchClock.TICKS_PER_SECOND_F:
			continue
		var is_caster := body == wall.wizard()
		_zap(at, BodyNudge.center(body), null if is_caster else body)
		if not is_caster:
			SplashDamage.hurt(
				body,
				float(wall.spell.damage),
				wall.from_slot,
				Health.DIRECT_SPELL,
				Health.LIGHTNING
			)
		var moved := _rng.randf_range(0.01, 0.02)
		_charge[key] = float(_charge.get(key, 0.0)) - moved
		taken += moved
	return taken


func _on_post_born(at: Vector3) -> void:
	for _bolt in _rng.randi_range(birth_bolts.x, birth_bolts.y):
		var way := (
			Vector3(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0)
			)
			. normalized()
		)
		way.y = way.y * 0.75 + 0.25
		var start := at + way * birth_reach_m
		start.y = maxf(start.y, wall.ground_y(start.x, start.z))
		_zap(start, at, null)


func _zap(from: Vector3, to: Vector3, follow: Node3D) -> void:
	FxBus.broadcast_beam(bolt, from, to, follow)
