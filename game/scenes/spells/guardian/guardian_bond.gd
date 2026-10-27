@tool
class_name GuardianBond
extends Node

## The creature tied to a building (Guardian `ndrg`). A child of unit.tscn; free, it does
## nothing. Tied, the server applies what a guardian gains and keeps the bond honest each frame; every
## peer draws the beam. Take the child out and the creature cannot be made a guardian.
##
## What a guardian gains: hits ×rules.guardian_attack_factor
## takes ×guardian_spell_factor of spell damage and ×guardian_ranged_factor
## of ranged damage, melee unchanged; heals guardian_heal_per_s on top
## of its regeneration; loses its active ability, stealth and
## playing dead; does not teleport. When tied it
## leaves the selection and its orders; afterwards it can be selected and ordered again.
## It is released when it dies, changes side, is taken by a doctor, or the post closes.
## Farther than the leash (ReachFacts) from the attach
## point it gets a move order back to the return distance of the building.
## `post_path` is replicated: whoever joins late sees the bond and draws the beam.
## Ref: sacengine, none verified against Sacrifice.exe; attackDamageFactor, state.d:8884; dealRawDamage, state.d:9007-9008; state.d:14408; state.d:1414; state.d:25071; state.d:14069; canTeleport, state.d:10309: group `rooted`; state.d:10408-10410; RFC-021b; isValidGuard, state.d:15352-15355; the building gone, state.d:15362; state.d:15366-15376

## Tied to `post`.
signal bound(post: GuardPost)
## The bond ended.
signal released

## Group of bodies that cannot be moved by Teleport or Guardian (RFC-021 risk 3).
const ROOTED := &"rooted"
const SELECTION_GROUP := &"selection"
const _ORDERS := preload("res://scenes/units/unit_orders.gd")

@export var body: UnitBody
@export var health: Health
## The creature's UnitOrders (unit_orders.gd has no class_name).
@export var orders: Node
@export var ability: AbilitySlot
@export var rules: MatchRules
## The beam, drawn on the peers that have a window. Empty = no beam.
@export var tether_scene: PackedScene

## Path of the GuardPost this creature is tied to; empty = free. The server writes it, the
## synchronizer carries it.
@export var post_path := NodePath():
	set(value):
		if post_path == value:
			return
		post_path = value
		if is_node_ready():
			_apply_post()

## Server or solo: the post it is tied to.
var post: GuardPost
var _tether: GuardianTether


## The GuardianBond child of a creature, or null.
static func of(unit: Node) -> GuardianBond:
	return unit.get_node_or_null("GuardianBond") as GuardianBond if unit != null else null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_apply_post()


func _exit_tree() -> void:
	if post != null and is_instance_valid(post):
		post.unbind(self)
	post = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Asigná en `body` la unidad (UnitBody).")
	if health == null:
		warnings.append("Asigná en `health` el Health de la unidad.")
	if orders == null:
		warnings.append("Asigná en `orders` el nodo Orders de la unidad.")
	if ability == null:
		warnings.append("Asigná en `ability` el AbilitySlot de la unidad (Abilities/Ability).")
	if rules == null:
		warnings.append("Asigná en `rules` el MatchRules (factores y correa del guardián).")
	return warnings


func is_bound() -> bool:
	return not post_path.is_empty()


## Server or solo: a guardian that counts for the post (isValidGuard): alive, not taken by a doctor,
## on the post's side.
func is_valid_guard() -> bool:
	if body == null or health == null or post == null or not is_instance_valid(post):
		return false
	if body.is_dead() or health.is_dead() or body.is_taken():
		return false
	return body.owner_slot == post.owner_slot()


## Server or solo. Ties the creature to `target`. False if it is already tied, cannot be (dead, taken)
## or the post is closed.
func bind(target: GuardPost) -> bool:
	if not is_multiplayer_authority() or target == null or not target.is_open() or is_bound():
		return false
	if body == null or health == null or body.is_dead() or body.is_taken():
		return false
	post = target
	post.bind(self)
	_apply_effects(true)
	post_path = target.get_path()
	bound.emit(target)
	return true


## Server or solo. Lets it go: the effects end and the post forgets it; the beam retires on every peer.
func release() -> void:
	if not is_bound() and post == null:
		return
	if post != null and is_instance_valid(post):
		post.unbind(self)
	post = null
	_apply_effects(false)
	post_path = NodePath()
	released.emit()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or post == null or not is_multiplayer_authority():
		return
	if not is_instance_valid(post) or not post.is_open() or not is_valid_guard():
		release()
		return
	health.heal(_rules().guardian_heal_per_s * delta)
	_keep_near()


## Farther than the leash from the attach point: a move order back to the return distance of the
## building. An order that already goes there stays.
## Ref: state.d:15366-15376
func _keep_near() -> void:
	var reach := ReachFacts.of_rules(_rules())
	var attach := post.attach_position()
	var gap := body.global_position + reach.guardian_leash_from - attach
	if gap.length_squared() <= reach.guardian_leash_m * reach.guardian_leash_m:
		return
	var current := orders as _ORDERS
	if current == null:
		return
	if current.command == _ORDERS.Command.MOVE and (current.point - attach).length_squared() < reach.guardian_leash_m * reach.guardian_leash_m:
		return
	var spot := attach + reach.guardian_return_m * gap.normalized()
	spot.y = body.global_position.y
	current.give(_ORDERS.Command.MOVE, null, spot, Vector2.ZERO, 0.0)


func _apply_effects(on: bool) -> void:
	var rule := _rules()
	var factors := {
		Health.DIRECT_SPELL: rule.guardian_spell_factor,
		Health.SPLASH_SPELL: rule.guardian_spell_factor,
		Health.DIRECT_RANGED: rule.guardian_ranged_factor,
		Health.SPLASH_RANGED: rule.guardian_ranged_factor,
	}
	for kind in factors:
		if on:
			health.kind_factors[kind] = factors[kind]
		else:
			health.kind_factors.erase(kind)
	body.attack_factor = rule.guardian_attack_factor if on else 1.0
	if ability != null:
		ability.locked = on
	if on:
		body.special_forms.clear()
		if orders != null:
			(orders as _ORDERS).clear()
		body.halt()
		body.add_to_group(ROOTED)
	else:
		body.remove_from_group(ROOTED)


## Every peer: the replicated path changed. Tied, the creature leaves the local selection and the
## beam appears; free, the beam retires.
func _apply_post() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if post_path.is_empty():
		if _tether != null and is_instance_valid(_tether):
			_tether.retire()
		_tether = null
		return
	get_tree().call_group(SELECTION_GROUP, "drop", body)
	if tether_scene == null or not BodyLook.loads_meshes():
		return
	if _tether != null and is_instance_valid(_tether):
		_tether.retire()
	_tether = tether_scene.instantiate() as GuardianTether
	if _tether == null:
		return
	add_child(_tether)
	_tether.follow(body, post_path)


func _rules() -> MatchRules:
	return rules if rules != null else MatchRules.new()
