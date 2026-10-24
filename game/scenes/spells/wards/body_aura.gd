@tool
class_name BodyAura
extends Node3D

## What a body does to the bodies around it while its Ward is on: burns them, stings them and heals the owner with the sting,
## pushes them away (Fireform, Protective Swarm, Air Shield) or heals them (Healing Aura). It does not protect the owner (Ward) nor start
## itself: it runs only while `ward` is on, and only on the server (or solo).
## Reach is a sphere drawn in the editor: its radius is the distance, measured between the two boxes (BOX_GAP) or from the
## owner's centre to the other body's centre (CENTER). Only bodies that move are touched (wizards and creatures), as the Phoenix.
## Damage type: the SPEL of Fireform and Protective Swarm says «direct spell» (type byte 1 at record offset 64), pierce or not.
## Ref: sacengine updateFireform, updateProtectiveSwarm, updateAirShield + pushAll (state.d:8614-8633, 17263-17295, 17376-17420, 17458-17525).

## The aura hurt `victim` this tick. Server (or solo) only; AuraImpact turns it into the mark and the sound on every peer.
signal stung(victim: Node3D)

enum Affects { ENEMIES, NOT_OWN, ALLIES, OWN_SIDE }
enum Measure { BOX_GAP, CENTER }

@export var ward: Ward
## Sphere shape: its radius is the reach in metres.
@export var reach: CollisionShape3D
@export var affects := Affects.ENEMIES
@export var measure := Measure.BOX_GAP
@export_group("Damage")
@export var damage_per_s := 0.0
@export var damage_kind: StringName = Health.DIRECT_SPELL
## The hit skips the victim's shields (Fireform).
@export var pierce_shield := false
## DamageMod bits of the hit (Health.IGNITE lights oil).
@export var mods := 0
## The owner heals this fraction of what the sting took (Protective Swarm 0.5).
@export_range(0.0, 1.0, 0.05) var heal_owner_fraction := 0.0
@export_group("Heal")
## Health a second it gives to every body it reaches that can be healed (Healing Aura 60). The heal keeps running `heal_hold_s` after
## the body leaves, and every tick in reach renews it (it does not add up).
@export var heal_per_s := 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var heal_hold_s := 4.267
## The owner is healed too (the creature that carries the aura).
@export var include_owner := false
@export_group("Push")
## Metres per second at the inner radius; it falls to 0 at the reach. 0 = no push.
@export var push_force := 0.0


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint() or ward == null or not ward.has_authority():
		return
	ward.shown_changed.connect(func(on: bool) -> void: set_physics_process(on))
	set_physics_process(ward.shown)


func reach_m() -> float:
	var sphere := reach.shape as SphereShape3D if reach != null else null
	return sphere.radius if sphere != null else 0.0


func _physics_process(delta: float) -> void:
	var body := ward.body
	if not ward.is_on() or body == null:
		return
	var mine := BodyNudge.box(body)
	var radius := reach_m()
	var taken := 0.0
	for other in BodyNudge.bodies_in(get_tree(), mine.grow(radius)):
		if other == body or not _affected(body, other) or not _near(body, mine, other, radius):
			continue
		taken += _sting(body, other, delta)
		_push(body, other, mine, radius, delta)
		_mend(other)
	if include_owner:
		_mend(body)
	if taken > 0.0 and heal_owner_fraction > 0.0 and ward.health != null:
		ward.health.heal(taken * heal_owner_fraction)


func _near(body: Node3D, mine: AABB, other: Node3D, radius: float) -> bool:
	if measure == Measure.CENTER:
		return BodyNudge.center(body).distance_to(BodyNudge.center(other)) < radius
	return box_gap(mine, BodyNudge.box(other)) <= radius


## Shortest distance between two boxes (0 when they touch or overlap).
static func box_gap(a: AABB, b: AABB) -> float:
	var gap := Vector3(
		maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
		maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y)),
		maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z)))
	return gap.length()


func _affected(body: Node3D, other: Node3D) -> bool:
	var stance := SideRelations.stance(_slot(body), _slot(other))
	match affects:
		Affects.ENEMIES:
			return stance != SideRelations.Stance.ALLY
		Affects.ALLIES:
			return stance == SideRelations.Stance.ALLY
		Affects.OWN_SIDE:
			return _slot(other) == _slot(body)
	return _slot(other) != _slot(body)


func _sting(body: Node3D, other: Node3D, delta: float) -> float:
	if damage_per_s <= 0.0:
		return 0.0
	var victim := other.get_node_or_null("Health") as Health
	var took := victim.damage_typed(damage_per_s * delta, damage_kind, _slot(body), false, pierce_shield, mods) if victim else 0.0
	if took > 0.0:
		stung.emit(other)
	return took


## sacengine pushAll: away from the owner's centre, full strength inside the owner's own radius, none at the reach.
func _push(body: Node3D, other: Node3D, mine: AABB, radius: float, delta: float) -> void:
	if push_force <= 0.0:
		return
	var away := BodyNudge.center(other) - BodyNudge.center(body)
	away.y = 0.0
	var distance := away.length()
	var inner := 0.5 * Vector2(mine.size.x, mine.size.z).length()
	if distance <= 0.0 or distance >= radius:
		return
	var strength := clampf(1.0 - (distance - inner) / (radius - inner), 0.0, 1.0) * push_force
	BodyNudge.slide(other, away / distance * strength * delta)


## Renews the heal of `other` (HealEffect keeps the better rate and the longer time; a body that cannot be healed is left alone).
func _mend(other: Node3D) -> void:
	if heal_per_s > 0.0 and HealEffect.can_heal(other):
		(HealEffect.on(other) as HealEffect).renew(heal_per_s / MatchClock.TICKS_PER_SECOND_F, MatchClock.ticks_for(heal_hold_s))


func _slot(node: Node) -> int:
	return int(node.get("owner_slot")) if node != null and "owner_slot" in node else 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ward == null:
		warnings.append("Falta el Ward: el aura no sabe cuándo correr.")
	if reach == null or not reach.shape is SphereShape3D:
		warnings.append("Reach necesita un CollisionShape3D con una esfera: su radio es el alcance.")
	return warnings
