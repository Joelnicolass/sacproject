class_name ChainHop
extends SpellLaunch

## A chain of jumps (Chain Lightning, Rainbow, the jumps of Dragonfire): who was already hit, and the clock of the jumps. Every jump leaves
## the last point, takes `hop_s` and lands on the next body (ChainPick: the nearest one, or the one with the lowest health) inside a radius
## that shrinks with each hit ((shrink_steps - n) / shrink_steps of the spell's range). With nobody in reach the jump goes on to a point on
## the land and the chain goes on. It does not know what a jump does (its ChainEffect) nor how a hit hurts (Health). With `hop_s` 0 it keeps
## no clock: whoever owns the flight (the dragon) calls `add_hit` and `pick_next`. Server (or solo) only; it frees itself after the last landing.
## Ref: sacengine updateChainLightning, updateRainbow (state.d:18129-18156, 18270-18293), REA FUN_00420070 / FUN_0042cc70 for the radius.

## A jump left toward `body` (null: a point on the land).
signal hopped(from: Vector3, body: Node3D, point: Vector3, index: int)
## A jump landed (hit number `index`, from 0).
signal landed(body: Node3D, point: Vector3, index: int)

@export var effect: ChainEffect
## Hits in total, the first included.
@export_range(1, 12) var hits := 7
## Seconds from a jump leaving to its landing. 0 = the owner drives the chain.
@export_range(0.0, 5.0, 0.001, "suffix:s") var hop_s := 20.0 / 60.0
## After hit n the search radius is (shrink_steps - n) / shrink_steps of the spell's effect range. 0 = it stays whole.
@export_range(0, 12) var shrink_steps := 6
## Jump to own side (Rainbow) or to whoever is not an ally (Chain Lightning, Dragonfire).
@export var allies := false
@export var order := ChainPick.Order.CLOSEST
@export_group("Start")
## The first jump leaves this far over the top of the wizard's box, and ahead of its front.
@export_range(0.0, 3.0, 0.05, "suffix:m") var origin_lift_m := 0.5
@export_range(0.0, 3.0, 0.05, "suffix:m") var origin_ahead_m := 0.75
@export_group("No body in reach")
## The point the jump falls on lies within lerp(fallback_limit_min, 1, U) of the range from the last body, drifted by `fallback_drift`.
@export_range(0.0, 1.0, 0.05) var fallback_limit_min := 0.25
@export_range(0.0, 3.0, 0.05) var fallback_drift := 1.5

var wizard: Node3D
var spell: SpellType
var slot := 0

var _hit: Array[Node3D] = []
var _current: Node3D
var _current_at := Vector3.ZERO
var _from := Vector3.ZERO
var _left := 0
var _count := 0
var _rng: RandomNumberGenerator


## The search radius after `n` hits.
static func radius_for(reach: float, n: int, steps: int) -> float:
	return reach if steps <= 0 else reach * float(maxi(0, steps - n)) / float(steps)


func _ready() -> void:
	set_physics_process(false)


func begin_cast(caster: Node3D, type: SpellType, target: Node3D, point: Vector3, _cast_ticks: int) -> void:
	wizard = caster
	spell = type
	slot = int(caster.get("owner_slot")) if caster != null else 0
	_current = target
	_current_at = point
	_rng = MatchSeed.rng(["chain", spell.tag, slot, MatchClock.now()])
	set_physics_process(false)


func release(target: Node3D) -> void:
	if target != null and is_instance_valid(target):
		_current = target
	if _current != null and is_instance_valid(_current):
		_current_at = BodyNudge.center(_current)
	else:
		_current = null
	_from = origin()
	_start_hop()


## Where the first jump leaves: ahead of the wizard's box and over its head.
func origin() -> Vector3:
	var body := wizard as WizardBody
	if body == null or not is_instance_valid(body):
		return _from
	var box := BodyNudge.box(body)
	var at := box.get_center() + body.facing_flat() * (box.size.x * 0.5 + origin_ahead_m)
	at.y = box.end.y + origin_lift_m
	return at


func hit_bodies() -> Array[Node3D]:
	return _hit


func hit_count() -> int:
	return _count


func has_hit(body: Node3D) -> bool:
	return body != null and _hit.has(body)


## Counts `body` as hit. False when the chain is full (the owner stops).
func add_hit(body: Node3D) -> bool:
	if _count >= hits:
		return false
	_count += 1
	if body != null:
		_hit.append(body)
	return true


## The body the next jump goes to after `n` hits, from `from_point`, or null.
func pick_next(from_point: Vector3, n: int) -> Node3D:
	return ChainPick.next(get_tree(), from_point, radius_for(spell.effect_range, n, shrink_steps), _hit, slot, allies, order)


func _physics_process(_delta: float) -> void:
	if _current != null and is_instance_valid(_current) and _current.is_inside_tree():
		_current_at = BodyNudge.center(_current)
	_left -= 1
	if _left <= 0:
		_land()


func _start_hop() -> void:
	hopped.emit(_from, _current, _current_at, _count)
	if effect != null:
		effect.hop(self, _from, _current, _current_at)
	_left = MatchClock.ticks_for(hop_s)
	set_physics_process(hop_s > 0.0)


func _land() -> void:
	var body := _current if _current != null and is_instance_valid(_current) else null
	landed.emit(body, _current_at, _count)
	if effect != null:
		effect.land(self, body, _current_at)
	add_hit(body)
	if _count >= hits:
		set_physics_process(false)
		queue_free()
		return
	var here := _current_at
	_current = pick_next(here, _count - 1)
	_current_at = BodyNudge.center(_current) if _current != null else ChainPick.fallback(self, here, _from, spell.effect_range, fallback_limit_min, fallback_drift, _rng)
	_from = here
	_start_hop()
