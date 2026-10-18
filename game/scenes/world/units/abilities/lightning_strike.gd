class_name LightningStrike
extends Node3D

## F130 (RFC-030 030s-a): one bolt of sacengine's `lightning` (state.d:10474-10491, Lightning 2831-2840, updateLightning
## 16366-16386). The one owner of "a bolt flies from here to there and hurts what it meets": Call lightning (gsba) and each
## discharge of the Lightning Charge (gcil) put one of these in the shot container (the node the shot spawner spawns into).
## Server (or solo) only: a client never gets this node (LightningStrike.launch adds it on the server); the look reaches every peer
## through FxBus.broadcast_beam("lightning"). Priority −1: it hurts before the bodies move, like Protector and HaloOfEarth.
##
## - It is born in the tick of the order. With `retarget` (updateTargets, 10475-10484) the segment from the start to the end's
##   center is cut at the first live body it crosses, the shooter left out: that body is the new end (it "bounces"). The charge's
##   discharges do not (updateTargets = false: the end was picked by the charge).
## - `travel_ticks` ticks later (Lightning.travelDelay 12; the node counts from the tick after it was born) the end's center is
##   read again (the bolt follows its target) and, if the end is a valid body, it takes the SPEL's amount as direct spell damage
##   with DamageMod.lightning (dealSpellDamage, 16380-16383). A ground end (a discharge into the land) hurts nothing.
## - The damage goes through Health.damage_typed: the side factor (friendly fire off: an ally takes nothing; on: ally_damage_factor,
##   28892-28899), the resistance (a Trogg's is 0) and the Lightning Charge's passive of the body that takes it are all Health's.
##
## Divergences (declared): buildings do not stop the ray (only creatures and wizards); the bolt does not keep its 64 frames of
## life (the look has its own): the node is freed after it strikes; the scar and the sound are not here.


const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")

## Ticks from the order to the damage (Lightning.travelDelay).
@export var travel_ticks := 12
## updateTargets: the first live body on the way becomes the end.
@export var retarget := true
## FxBus BeamType (data/fx/beams/<name>.tres).
@export var beam_type := "lightning"
## FxBus burst where the bolt hurts a body (sparkAnimation, 16376; reserve look).
@export var hit_fx := "styx_spark"

## The body that shoots (the Storm Giant): out of the retarget ray, and the "attacker" of the hit.
var shooter: Node3D
## SPEL tag for the log (gsba / gcil).
var label := ""
var start := Vector3.ZERO
## The end: a body (follows it) or, with none, a point on the land.
var end_body: Node3D
var end_point := Vector3.ZERO
var amount := 0.0

var _slot := 0
var _who := "?"
var _born := 0
var _age := 0
var _ended := false


## The bolt of `scene` in the shot container, or null (and a warning) when there is none. `from` is any node of the tree.
## `with_retarget` overrides the scene's knob (the charge's discharges say false).
static func launch(scene: PackedScene, from: Node, shooting: Node3D, from_point: Vector3, target: Node3D, ground_point: Vector3,
		damage: float, tag: String, with_retarget := true) -> LightningStrike:
	if scene == null or from == null or not from.is_inside_tree():
		return null
	var spawner := from.get_tree().get_first_node_in_group(&"shot_spawner")
	var container := spawner.get_node_or_null(spawner.get("spawn_path")) if spawner != null else null
	if container == null:
		push_warning("LightningStrike: no hay contenedor de disparos (grupo shot_spawner).")
		return null
	var bolt := scene.instantiate() as LightningStrike
	if bolt == null:
		push_warning("LightningStrike: la escena no es un LightningStrike.")
		return null
	bolt.retarget = with_retarget
	bolt.setup(shooting, from_point, target, ground_point, damage, tag)
	container.add_child(bolt, true)
	return bolt


## isValidTarget: alive and on the field (and targetable). The one answer for the retarget ray, the damage and the charge's picks.
static func is_valid_target(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not _ROCK.is_live_body(body):
		return false
	var unit := body as UnitBody
	return unit == null or not (unit.is_summoning() or unit.is_taken())


## Before the node enters the tree.
func setup(shooting: Node3D, from_point: Vector3, target: Node3D, ground_point: Vector3, damage: float, tag: String) -> void:
	shooter = shooting
	start = from_point
	end_body = target
	end_point = ground_point
	amount = damage
	label = tag
	_born = MatchClock.now()
	_who = AbilityEffect.who(shooting)
	_slot = int(shooting.get("owner_slot")) if shooting != null and "owner_slot" in shooting else 0
	name = "Bolt%s%s_%d" % [tag, _who, _born]


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	var first := end_body
	_follow()
	if retarget:
		_retarget()
	_say("rayo %s %s nace de %s a %s en %s (tick %d)" % [label, _who, _v(start), _name_of(end_body), _v(end_point), _born])
	if end_body != first:
		_say("rayo %s %s rebota en %s en vez de %s (tick %d)" % [label, _who, _name_of(end_body), _name_of(first), _born])
	FxBus.broadcast_beam(beam_type, start, end_point, end_body if end_body != null and is_instance_valid(end_body) else null)


func _physics_process(_delta: float) -> void:
	if _ended or MatchClock.now() <= _born:
		return
	_age += 1
	_follow()
	if _age >= maxi(1, travel_ticks):
		_strike()
		_ended = true
		set_physics_process(false)
		queue_free()


## lightning.end.position = lightning.end.center(state): the end keeps to its body.
func _follow() -> void:
	if end_body != null and is_instance_valid(end_body) and end_body.is_inside_tree():
		end_point = BodyNudge.center(end_body)


## updateTargets: the first valid body (not the shooter) the segment start → end meets becomes the end.
func _retarget() -> void:
	var best: Node3D = null
	var best_d := INF
	var seen := {}
	for group in [&"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body == shooter or seen.has(body) or not is_valid_target(body):
				continue
			seen[body] = true
			var hit: Variant = BodyNudge.box(body).intersects_segment(start, end_point)
			if hit == null:
				continue
			var d := start.distance_squared_to(hit as Vector3)
			if d < best_d or (d == best_d and best != null and str(body.name) < str(best.name)):
				best = body
				best_d = d
	if best != null:
		end_body = best
		end_point = BodyNudge.center(best)


## Frame travelDelay: the SPEL's amount as direct spell damage with DamageMod.lightning to a valid end.
func _strike() -> void:
	if end_body == null:
		_say("rayo %s %s llega al suelo en %s (tick %d)" % [label, _who, _v(end_point), MatchClock.now()])
		return
	if not is_valid_target(end_body):
		_say("rayo %s %s llega a %s: ya no es blanco (tick %d)" % [label, _who, _name_of(end_body), MatchClock.now()])
		return
	var health := end_body.get_node_or_null("Health") as Health
	if health == null:
		return
	if not hit_fx.is_empty():
		FxBus.broadcast(hit_fx, end_point)
	var taken := health.damage_typed(amount, Health.DIRECT_SPELL, _slot, false, false, Health.LIGHTNING)
	_say("rayo %s %s dano %s %.2f vida %.2f (tick %d)" % [label, _who, _name_of(end_body), taken, health.current, MatchClock.now()])


func _name_of(body: Node) -> String:
	return str(body.name) if body != null and is_instance_valid(body) else "suelo"


func _say(text: String) -> void:
	if DebugLog.on(&"bolt"):
		print(text)


static func _v(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]
