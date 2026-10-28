class_name FastRevive
extends Node

## The fast revival of a corpse by the Dragon's breath:
## the corpse must be dead and its soul NORMAL or EMERGING; the soul turns REVIVING and the body gets its full health. The
## creature then rises and turns for half the revive time = 150 ticks: while timer < 75 it climbs the revive height/75 per
## tick (74 ticks · 2/75 = 1.97 m), it turns 2π in all, and at timer 150 its soul is removed and it idles.
## Child of the body, server (or solo) only; the body is REVIVING (Captive: out of the group «unit», without collision, nobody's
## target) and UnitBody.physics skips a taken body, so this node writes its height and its facing. begin() before add_child.
## Time is MatchClock's: the height and the angle are derived from the ticks since begin(), so the order of the nodes in a tick
## changes nothing.
##
## The creature goes back to the ground by gravity; it is not added to
## the selection again; the corpse stands up with Corpse.stand_up (0.9 s), not the revive clip.



## How long the revival lasts.
@export_range(0.0166, 30.0, 0.0001, "suffix:s") var revive_s := 2.5
## It climbs while the timer is under this.
@export_range(0.0166, 30.0, 0.0001, "suffix:s") var rise_s := 1.25
## Meters it climbs in rise_s.
@export var rise_height := 2.0
## Turns it makes in revive_s (fast: 2π).
@export var turns := 1.0
## Fraction of its maximum health it comes back with (all of it).
@export_range(0.0, 1.0) var health_fraction := 1.0

## revive_s and rise_s in ticks (what the timer counts).
var revive_ticks: int:
	get: return MatchClock.ticks_for(revive_s)
var rise_ticks: int:
	get: return MatchClock.ticks_for(rise_s)

var _body: UnitBody
var _soul: Soul
var _begin := 0
var _start := Vector3.ZERO
var _facing := 0.0
var _who := "?"


## Before the node enters the tree. False = it cannot be revived (not dead, soul gone or already taken): nothing changed.
func begin(corpse: UnitBody, soul: Soul) -> bool:
	if corpse == null or soul == null or not is_instance_valid(corpse) or not is_instance_valid(soul) or not corpse.is_dead():
		return false
	if not (soul.state == Soul.State.NORMAL or soul.state == Soul.State.EMERGING):
		return false
	var captive := Captive.of(corpse)
	if captive == null or not captive.revive(0.0, health_fraction):
		return false
	soul.state = Soul.State.REVIVING
	_body = corpse
	_soul = soul
	_begin = MatchClock.now()
	_start = corpse.global_position
	_facing = corpse.rotation.y
	_who = AbilityEffect.who(corpse)
	name = "FastRevive"
	_say("revive %s start health %d (tick %d)" % [_who, roundi(_health()), _begin])
	return true


func _ready() -> void:
	if not is_multiplayer_authority():
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if _body == null or not is_instance_valid(_body):
		queue_free()
		return
	if not _body.is_reviving():
		queue_free()
		return
	var timer := MatchClock.now() - _begin
	if timer <= 0:
		return
	if timer >= revive_ticks:
		_finish()
		return
	# timer 1..rise_ticks−1 climb rise_height / rise_ticks each: the sum is 74 · 2/75 = 1.9733 m and it stays there.
	var rise := rise_height * float(mini(timer, rise_ticks - 1)) / float(rise_ticks)
	_body.global_position = Vector3(_start.x, _start.y + rise, _start.z)
	_body.rotation.y = wrapf(_facing + TAU * turns * float(timer) / float(revive_ticks), -PI, PI)
	if timer == rise_ticks - 1:
		_say("revive %s rises %.4f m (tick %d)" % [_who, rise, MatchClock.now()])


## timer ≥ the revive time: the soul is removed and the creature idles (Captive.finish_revive: REVIVING → IDLE).
func _finish() -> void:
	_body.rotation.y = _facing
	if _soul != null and is_instance_valid(_soul):
		_soul.queue_free()
	var captive := Captive.of(_body)
	if captive == null or not captive.finish_revive():
		push_warning("FastRevive: %s could not finish the revival (no Captive, or it was not REVIVING)." % _who)
	_say("revive %s end idle health %d (tick %d)" % [_who, roundi(_health()), MatchClock.now()])
	queue_free()


func _health() -> float:
	var health := _body.get_node_or_null("Health") as Health if _body != null else null
	return health.current if health != null else 0.0


func _say(text: String) -> void:
	if DebugLog.on(&"revive"):
		print(text)
