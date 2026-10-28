class_name FireShield
extends UnitPassive

## The Phoenix's Shield (rifl): every frame, it burns every non-allied body that touches the
## Phoenix, costing its mana per burn. A body that can shield (not dying, dead, reviving or a ghost)
## and holds the mana the SPEL asks (rifl: 0) takes every moving body whose box meets its own box
## scaled ×1.5 from the center (the Phoenix itself apart). A body that is not an ally of the
## Phoenix's side burns: fireform.amount / 60 as a direct spell hit that skips the Life Shield /
## Rockform / petrified factors (Health.damage_typed, pierce_shield) plus three fire particles. If
## it burned someone it drains the mana cost (ManaPool.drain; 0 for rifl) and puffs the shield
## particles. Buildings are not touched. A node of the Phoenix's `phoenix_passives.tscn`: only a
## creature that has it burns. Server (or solo) only. The particles are the reserve look (`fire_fx`
## at the burned body's `fire_socket` every `fire_every_s`).

const GROUPS: Array[StringName] = [UnitBody.GROUP, WizardBody.GROUP]

## The passive (data/catalog/abilities/phoenix_fire_shield.tres): its numbers give the mana cost.
@export var passive: AbilityType
## The fire it ignites with (data/catalog/spells/fireform.tres, fireform): the spell's amount, per
## second.
@export var fire: SpellType
## Scale of the body's box about its center.
@export var box_scale := 1.5
@export_group("Look")
## The fire played on a burned body every `fire_every_s` it burns (reserve look). Empty = none.
@export var fire_fx: ParticleType = preload("res://data/fx/fire.tres")
@export_range(0.0, 2.0, 0.0001, "suffix:s") var fire_every_s := 0.0833
## Where on the burned body the fire comes out.
@export var fire_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

## The Phoenix's health and mana (set by attach).
var health: Health
var mana: ManaPool

var _burn_ticks := {}
var _allies_seen := {}


func attach(mount: PassiveMount) -> void:
	super(mount)
	health = mount.health
	mana = mount.mana


func _ready() -> void:
	set_physics_process(is_multiplayer_authority())


func _physics_process(_delta: float) -> void:
	if not _can_shield():
		return
	var cost := _mana_cost()
	if cost > 0.0 and (mana == null or mana.current < cost):
		return
	if fire == null:
		return
	var per_tick := float(fire.damage) / MatchClock.TICKS_PER_SECOND_F
	var mine := _scaled_box()
	var burned := false
	for group in GROUPS:
		for other in get_tree().get_nodes_in_group(group):
			var target := other as Node3D
			if target == null or target == body or not _burnable(target):
				continue
			if not _meets(mine, target):
				continue
			if _is_ally(target):
				_log_ally(target)
				continue
			burned = true
			_burn(target, per_tick, mine)
	if burned and cost > 0.0 and mana != null:
		mana.drain(cost)


func _burn(target: Node3D, per_tick: float, mine: Array) -> void:
	var victim := target.get_node_or_null("Health") as Health
	if victim == null:
		return
	var taken := victim.damage_typed(per_tick, Health.DIRECT_SPELL, _slot(body), false, true)
	var key := target.get_instance_id()
	var count := int(_burn_ticks.get(key, 0))
	_burn_ticks[key] = count + 1
	var every := MatchClock.ticks_for(fire_every_s)
	if fire_fx != null and every > 0 and count % every == 0:
		FxBus.broadcast(fire_fx, BodyFacts.point(target, fire_socket))
	if DebugLog.on(&"shield") and taken > 0.0:
		var box := BodyBox.box_of(target)
		var center: Vector3 = mine[0]
		var at := target.global_position
		print(
			(
				# gdlint: ignore=max-line-length
				"shield %s burns %s %.4f health %.4f (tick %d) mana %.3f box (%.3f, %.3f, %.3f) ± (%.3f, %.3f, %.3f) other (%.3f, %.3f, %.3f) ± (%.3f, %.3f)"
				% [
					body.name,
					target.name,
					taken,
					victim.current,
					MatchClock.now(),
					mana.current if mana != null else -1.0,
					center.x,
					center.y,
					center.z,
					mine[1],
					mine[2],
					mine[1],
					at.x,
					at.y,
					at.z,
					box.x,
					box.y
				]
			)
		)


func _log_ally(target: Node3D) -> void:
	if DebugLog.on(&"shield") and not _allies_seen.has(target.get_instance_id()):
		_allies_seen[target.get_instance_id()] = true
		print(
			(
				"shield %s touches %s ally, no burn (tick %d)"
				% [body.name, target.name, MatchClock.now()]
			)
		)


## (center, half width, half height) of the Phoenix's box, scaled about the center.
func _scaled_box() -> Array:
	var box := BodyBox.box_of(body)
	var at := body.global_position
	return [Vector3(at.x, at.y + box.y * 0.5, at.z), box.x * box_scale, box.y * 0.5 * box_scale]


## Whether the target's box (feet at its position, its height up) meets the scaled one; touching is
## not meeting.
func _meets(mine: Array, target: Node3D) -> bool:
	var box := BodyBox.box_of(target)
	var center: Vector3 = mine[0]
	var half: float = mine[1] + box.x
	var at := target.global_position
	if absf(at.x - center.x) >= half or absf(at.z - center.z) >= half:
		return false
	var middle := at.y + box.y * 0.5
	return absf(middle - center.y) < float(mine[2]) + box.y * 0.5


func _is_ally(target: Node) -> bool:
	return SideRelations.stance(_slot(body), _slot(target)) == SideRelations.Stance.ALLY


func _slot(node: Node) -> int:
	return int(node.get("owner_slot")) if node != null and "owner_slot" in node else 0


func _mana_cost() -> float:
	return float(passive.mana_cost) if passive != null else 0.0


## Stunned, cowering, casting, Rockform, firewalk and stealth keep the shield; dying, dead,
## summoning, reviving and taken by a Doctor do not.
func _can_shield() -> bool:
	if health != null and health.is_dead():
		return false
	return _present(body)


## A moving body the shield can burn: any creature or wizard that is not dead (stealth and firewalk
## included).
func _burnable(target: Node3D) -> bool:
	if not Attackable.is_body(target) or target.is_in_group(MapBuilding.STRUCTURE_GROUP):
		return false
	var life := target.get_node_or_null("Health") as Health
	return life != null and not life.is_dead() and _present(target)


func _present(node: Node) -> bool:
	if not "mode" in node:
		return true
	var mode: int = node.get("mode")
	if (
		mode == UnitBody.Mode.DEAD
		or mode == UnitBody.Mode.SUMMONING
		or mode == UnitBody.Mode.REVIVING
	):
		return false
	return not (node is UnitBody and (node as UnitBody).is_taken())
