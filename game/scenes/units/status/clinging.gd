class_name Clinging
extends Node3D

## F129 (RFC-030 030r-a): the things stuck to a body that slow it down (sacengine effects.numStickyBombs / numBlightMites,
## stats.d:122): the Ikarus's Sticky bombs (×0.75 each, 10 s) and the Bilemites (×0.8 each). The one owner of how many
## there are and when each lets go. stick() adds one piece of a kind for a number of MatchClock ticks; each piece lets go at
## its own tick (sacengine updateStickyBomb: `++infectionTime <= updateFPS·duration` keeps it, so it is gone at duration·60 + 1
## updates after it stuck); every piece of every body lets go at once when the body can no longer be poisoned
## (canBeStickyBombed = canBePoisoned, state.d:186): it dies, is being summoned…
## The slowdown is not written here: for each kind Clinging gives PaceFactors the factor `factor ^ count` under its own source
## (&"cling_sticky", &"cling_mites"), and PaceFactors writes speed_factor. It is derived from the lists on every change, so a
## piece that lets go in the same tick as another one is the same as the two one after the other.
## `shown` is replicated (the unit's MultiplayerSynchronizer, "Clinging:shown"): x = bombs, y = mites, z = frogs. Every peer draws that
## many of the look scenes at fixed places on the body (declared: sacengine keeps where each one hit).
## Server (or solo) only for stick(); the look runs on every peer.

const STICKY := &"sticky"
const MITES := &"mites"
## A frog of Rain of Frogs (×0.6 each): the frog is its own look, a node that rides the body (ZoneDrop attached to it).
const FROGS := &"frogs"
const KINDS: Array[StringName] = [STICKY, MITES, FROGS]
## The PaceFactors source of each kind.
const SOURCES := {STICKY: &"cling_sticky", MITES: &"cling_mites", FROGS: &"cling_frogs"}


## The body they stick to (its box places the look, its name goes in the log). Empty = the parent.
@export var body: Node3D
## Whether the body can still be stuck to (canBePoisoned). Empty = nothing ends them but their time.
@export var poisoning: Poisoning
## Who writes speed_factor. Empty = the pieces do not slow the body.
@export var pace: PaceFactors
@export_group("Look")
@export var bomb_look: PackedScene
@export var mite_look: PackedScene
## No more than this many looks of each kind are drawn.
@export var max_looks := 12
## Where the pieces sit: a ring at this fraction of the body's reach, climbing over this fraction of its height.
@export var ring_reach := 0.8
@export var min_height := 0.45
@export var height_step := 0.1

## Replicated. x = Sticky bombs, y = Blight mites, z = frogs. The setter is the one place that draws.
@export var shown := Vector3i.ZERO:
	set(value):
		if value == shown:
			return
		shown = value
		if is_node_ready():
			_draw_looks()

## kind -> Array[int] of the MatchClock ticks at which each piece lets go.
var _ends: Dictionary = {}
## kind -> the factor of one piece.
var _factors: Dictionary = {}
var _looks: Dictionary = {}


## The Clinging of `node`, or null (a body without one cannot be stuck to).
static func of(node: Node) -> Clinging:
	return (node.get_node_or_null("Clinging") as Clinging) if node else null


func _ready() -> void:
	set_physics_process(false)
	if body == null:
		body = get_parent() as Node3D
	_draw_looks()


## Server (or solo). One more piece of `kind` that lets go `ticks` after now, each slowing the body ×`factor`. False when it
## is not the server or the arguments mean nothing.
func stick(kind: StringName, ticks: int, factor: float) -> bool:
	if not is_multiplayer_authority() or ticks <= 0 or not KINDS.has(kind):
		return false
	var ends: Array = _ends.get(kind, [])
	ends.append(MatchClock.now() + ticks)
	_ends[kind] = ends
	_factors[kind] = factor
	_refresh()
	set_physics_process(true)
	if DebugLog.on(&"cling"):
		print("pegado %s %s n=%d factor ×%.4f hasta %d (tick %d)" % [_who(), kind, ends.size(), pow(factor, ends.size()), ends.max(), MatchClock.now()])
	return true


## How many pieces of `kind` are on (the server's lists; on a client what it was told).
func count_of(kind: StringName) -> int:
	if not is_multiplayer_authority():
		return shown.x if kind == STICKY else (shown.y if kind == MITES else (shown.z if kind == FROGS else 0))
	return (_ends.get(kind, []) as Array).size()


func is_clinging() -> bool:
	return count_of(STICKY) + count_of(MITES) + count_of(FROGS) > 0


## Server (or solo): every piece lets go now.
func clear(reason := "fin") -> void:
	if _ends.is_empty():
		return
	if DebugLog.on(&"cling"):
		print("suelto todo %s por %s (tick %d)" % [_who(), reason, MatchClock.now()])
	_ends.clear()
	_refresh()
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if poisoning != null and not poisoning.can_be_poisoned():
		clear("no puede ser pegado")
		return
	var now := MatchClock.now()
	var changed := false
	for kind: StringName in KINDS:
		var ends: Array = _ends.get(kind, [])
		var kept: Array = ends.filter(func(end: int) -> bool: return end > now)
		if kept.size() == ends.size():
			continue
		changed = true
		if DebugLog.on(&"cling"):
			print("suelto %s %s n=%d->%d (tick %d)" % [_who(), kind, ends.size(), kept.size(), now])
		_ends[kind] = kept
	if changed:
		_refresh()
	if _total() == 0:
		set_physics_process(false)
	elif DebugLog.on(&"cling") and body != null:
		var at := body.global_position
		var pace_now := float(body.get("speed_factor")) if "speed_factor" in body else 1.0
		print("marcha %s ×%.4f (%.4f, %.4f, %.4f) (tick %d)" % [_who(), pace_now, at.x, at.y, at.z, now])


func _total() -> int:
	var total := 0
	for kind: StringName in KINDS:
		total += (_ends.get(kind, []) as Array).size()
	return total


## Derives the factors and the replicated count from the lists. Idempotent.
func _refresh() -> void:
	for kind: StringName in KINDS:
		if pace != null:
			var count := (_ends.get(kind, []) as Array).size()
			pace.set_factor(SOURCES[kind], pow(float(_factors.get(kind, 1.0)), count) if count > 0 else 1.0)
	shown = Vector3i((_ends.get(STICKY, []) as Array).size(), (_ends.get(MITES, []) as Array).size(), (_ends.get(FROGS, []) as Array).size())


## Every peer: as many looks of each kind as `shown` says (up to max_looks), at fixed places.
func _draw_looks() -> void:
	_fit(STICKY, bomb_look, shown.x)
	_fit(MITES, mite_look, shown.y)


func _fit(kind: StringName, scene: PackedScene, count: int) -> void:
	var list: Array = _looks.get(kind, [])
	var wanted := mini(count, max_looks) if scene != null else 0
	while list.size() > wanted:
		(list.pop_back() as Node).queue_free()
	while list.size() < wanted:
		var node := scene.instantiate() as Node3D
		if node == null:
			break
		add_child(node)
		node.position = _place(KINDS.find(kind), list.size())
		list.append(node)
	_looks[kind] = list


## A fixed place on the body for the piece number `index` of a kind (the golden angle around it, climbing).
func _place(kind_index: int, index: int) -> Vector3:
	var reach := 0.35
	var height := 1.8
	if body is UnitBody:
		var profile := (body as UnitBody).melee_profile()
		reach = float(profile.get("reach", reach))
		height = float(profile.get("height", height))
	var angle := (float(index) + 0.5 * float(kind_index)) * 2.39996323
	return Vector3(cos(angle), 0.0, sin(angle)) * reach * ring_reach + Vector3.UP * height * (min_height + height_step * float(index % 5))


func _who() -> String:
	return str(body.name) if body else "?"
