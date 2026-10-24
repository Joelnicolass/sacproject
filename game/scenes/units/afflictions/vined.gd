class_name Vined
extends Affliction

## F159 (RFC-030 030u-c): the Dragon's Grasping Vines (eniv, passiveOnHit of grdg), sacengine graspingVines (state.d:10795-10812) and
## updateGraspingVines (17852-17876). The blow ties the body to the ground: while it lasts the body is `fixed` (cannot walk nor be moved
## from outside), does not regenerate and is ccProtected (stats.d:73-94: vined → regenerationBlocked, ccProtected, fixed). The type
## (`vined.tres`: bit 8, coexists, holds = false, cc_protects, pins, blocks_regeneration) says all of that; this node owns the clock.
##
## Each blow brings its own timer (numVines += 1, one GraspingVines effect with its own `timer`): `_ends` holds the tick every one
## runs out on, and the bit is on while any is left. The duration of one is (wizard ? 0.25 : 1000 / max health) · the SPEL's 40 s in
## float32 (Affliction.cc_ticks): a Jabberocky of 5600 hp is 429 ticks. A flier is never tied (isHitboxFlying, 10799), and a body that is
## dead or dying loses every vine at once (canPersistCC: Afflictions ends the bit when it dies).
## The body's xz velocity is 0 in steer(); the xy position of sacengine is the port's xz (the vertical follows the land by itself).
##
## Look (every peer, from the replicated bit): the VineLook child, sixteen skinned vines that grow and shrink in a second.

## Vine lifetime of a creature: creature_k / max health · the SPEL's duration (s); of a wizard: wizard_factor · duration.
@export var creature_k := 1000.0
@export var wizard_factor := 0.25
## Server: the tick each blow's vines run out on.
var _ends: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	set_physics_process(false)


## The Vined state under `node` is on (a body that is not a creature or has none: false).
static func is_vined(node: Node) -> bool:
	var vined := node.get_node_or_null("Afflictions/Vined") as Vined if node else null
	return vined != null and vined.is_on()


## F158: the on-hit passive. Every blow that connects ties the body, whatever its damage roll gave.
func inflict(spell: SpellType, _from_slot: int) -> bool:
	return grasp(spell)


## The Vinewall's grasp: its length is the usual share (wizard 0.25, creature 1000 / health) of `max_s`, the wall's remaining time, and never more
## than `max_s` (sacengine vinewallGraspingVines, state.d:20370-20383).
func lay_within(spell: SpellType, _from_slot: int, max_s: float) -> bool:
	return grasp(spell, max_s)


func lay_ticks(spell: SpellType) -> int:
	var health := _afflictions().health
	return cc_ticks(_body().is_in_group(&"wizard"), health.maximum if health else 0.0, spell.duration_s, creature_k, wizard_factor) if _body() != null else 0


## Server (or solo): sacengine graspingVines(target, spell). True when the vines took hold (a flier refuses them).
func grasp(spell: SpellType, max_s := INF) -> bool:
	var body := _body()
	var owner_node := _afflictions()
	if body == null or spell == null or not _simulates() or BodyNudge.airborne(body):
		return false
	if owner_node.health != null and owner_node.health.is_dead():
		return false
	var seconds := spell.duration_s if is_inf(max_s) else max_s
	var ticks := cc_ticks(body.is_in_group(&"wizard"), owner_node.health.maximum if owner_node.health else 0.0, seconds, creature_k, wizard_factor)
	if not is_inf(max_s):
		ticks = mini(ticks, ceili(float(MatchClock.TICKS_PER_SECOND) * max_s))
	if ticks <= 0 or not owner_node.admit(self):
		return false
	var now := MatchClock.now()
	_ends.append(now + ticks)
	owner_node.mark(self, true)
	set_physics_process(true)
	if DebugLog.on(&"vines"):
		print("enredado %s durante %d (n %d) (cuadro %d)" % [str(body.name), ticks, _ends.size(), now])
	return true


## Server, every tick while it is on: the body does not walk.
func steer(velocity: Vector3, _delta: float) -> Vector3:
	velocity.x = 0.0
	velocity.z = 0.0
	return velocity


## updateGraspingVines: `--timer <= 0` ends one blow's vines; the bit goes when the last one does.
func _physics_process(_delta: float) -> void:
	var now := MatchClock.now()
	var left := PackedInt32Array()
	for end in _ends:
		if end > now:
			left.append(end)
	if left.size() == _ends.size():
		return
	_ends = left
	if _ends.is_empty():
		_afflictions().mark(self, false)
		set_physics_process(false)
	_say_end()


func _say_end() -> void:
	if DebugLog.on(&"vines"):
		print("enredado fin %s (n %d) (cuadro %d)" % [str(_body().name), _ends.size(), MatchClock.now()])


## The bit changed (every peer). On the server a bit turned off from outside (the body died) clears the clocks; VineLook draws the rest.
func _shown(on: bool) -> void:
	if not on and _simulates() and not _ends.is_empty():
		_ends = PackedInt32Array()
		set_physics_process(false)
		_say_end()
