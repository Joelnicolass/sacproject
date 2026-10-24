@tool
class_name CarrierPulse
extends Node3D

## What a SpellCarrier does to the bodies it passes near, once its casting time is over: every creature and wizard whose box is inside
## `Reach` is stunned, and with `damage_foes` the foes of the wizard also take the spell's damage and a bolt, once each per trip.
## Soul Mole stuns everybody but its wizard and hurts nobody; Soul Wind stuns and hurts only the foes, once. It does not move, does not
## take the soul (SoulFetch) and does not draw the carrier. Server (or solo) only.
## Ref: sacengine updateSoulMole, updateSoulWind (state.d:18030-18044, 18999-19018).

enum Affects { ALL_BUT_WIZARD, FOES }

@export var carrier: SpellCarrier
## The sphere of the effect, in the carrier's frame; its radius is how far from the carrier a body feels it.
@export var reach: CollisionShape3D
@export var affects := Affects.ALL_BUT_WIZARD
## The stun's own cooldown for the body, in ticks (8 s).
@export_range(0, 3600) var stun_ticks := 480
## The foes also take the spell's damage (direct spell) the first time they are reached.
@export var damage_foes := false
## Where the bolt starts (Soul Wind: a metre over the funnel's base). Empty = no bolt.
@export var bolt_origin: Marker3D
## The bolt from `bolt_origin` to the body.
@export var bolt: BeamType
@export var stunned_path := NodePath("Afflictions/Stunned")
@export var groups: Array[StringName] = [&"wizard", &"unit"]

var _hit := {}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if carrier == null:
		warnings.append("Falta el SpellCarrier.")
	if reach == null or not reach.shape is SphereShape3D:
		warnings.append("Falta `reach` con una forma esférica.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint() or not multiplayer.is_server():
		set_physics_process(false)


func radius_m() -> float:
	return (reach.shape as SphereShape3D).radius if reach != null and reach.shape is SphereShape3D else 0.0


func _physics_process(_delta: float) -> void:
	if carrier == null or not carrier.armed or reach == null:
		return
	var wizard := carrier.wizard()
	for body in SplashDamage.bodies_within(get_tree(), carrier.global_position, radius_m(), null, groups):
		if body == wizard:
			continue
		if affects == Affects.FOES and _is_friend(wizard, body):
			continue
		if damage_foes and _hit.has(body.get_instance_id()):
			continue
		_hit[body.get_instance_id()] = true
		_reach(body)


func _reach(body: Node3D) -> void:
	var stunned := body.get_node_or_null(stunned_path) as Stunned
	if stunned != null:
		stunned.stun_with_cooldown(stun_ticks)
	if not damage_foes:
		return
	if bolt != null and bolt_origin != null:
		FxBus.broadcast_beam(FxBus.name_of(bolt), bolt_origin.global_position, BodyNudge.center(body), body)
	SplashDamage.hurt(body, carrier.damage, carrier.from_slot, Health.DIRECT_SPELL)


static func _is_friend(wizard: Node3D, body: Node3D) -> bool:
	if wizard == null:
		return false
	return AimedAction.is_ally(wizard, body) or SideRelations.stance(int(wizard.get("owner_slot")), int(body.get("owner_slot"))) == SideRelations.Stance.ALLY
