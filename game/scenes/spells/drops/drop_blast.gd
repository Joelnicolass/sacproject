@tool
class_name DropBlast
extends Node

## What a drop does where its flight ends: the spell's damage to the body it ended on, the same damage falling off with distance to every
## body within the spell's damage range, and (by knob) a fire of a moment on all of them and a stun on those it only splashed. It plays the
## bursts of the place, whose sounds, shakes and lights are the ones of each burst's name. It does not fly the drop (ZoneDrop) nor poison
## (DropPoison). Server (or solo) only.
## Ref: sacengine rainFrogExplosion, rainOfFireDropExplosion, bombardmentDropExplosion (state.d:19405-19427, 21142-21154, 21344-21379).

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

@export var drop: ZoneDrop
## FxBus bursts played where it ends (ParticleType under data/fx/).
@export var bursts: Array[ParticleType] = []
## Marks it leaves on the ground where it ends (ScarMark scenes: a burn, a crack), painted on every peer.
@export var ground_marks: Array[PackedScene] = []
@export_group("Fire")
@export var ignites := false
## The fire a reached body keeps (no damage of its own: the damage is the blast's) and the sprite it puffs.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var burn_s := 1.0
@export var burn_look: ParticleType
@export_group("Stun")
## Bodies the blast only splashed (not the one it ended on) are stunned for this long (0 = no stun).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var stun_s := 0.0
@export var stunned_path := NodePath("Afflictions/Stunned")


func _ready() -> void:
	if not Engine.is_editor_hint() and drop != null and multiplayer.is_server():
		drop.ended.connect(blast)


## The blast at `at`, on `body` (null = the ground).
func blast(body: Node3D, at: Vector3) -> void:
	var live := body != null and is_instance_valid(body) and _ROCK.is_live_body(body)
	var mods := Health.IGNITE if ignites else 0
	var slot := drop.from_slot
	if live:
		SplashDamage.hurt(body, drop.damage, slot, Health.SPLASH_SPELL, mods)
	SplashDamage.deal(get_tree(), at, drop.damage, drop.damage_range, body if live else null, slot, Health.SPLASH_SPELL, mods)
	for hit in SplashDamage.bodies_within(get_tree(), at, drop.damage_range):
		if ignites:
			Burning.ignite(hit, 0.0, MatchClock.ticks_for(burn_s), Health.DIRECT_SPELL, slot, 0.0, false, burn_look)
		var stunned := hit.get_node_or_null(stunned_path) as Stunned if stun_s > 0.0 and hit != body else null
		if stunned != null:
			stunned.stun_with_cooldown(MatchClock.ticks_for(stun_s))
	for type in bursts:
		FxBus.broadcast(type, at)
	for mark in ground_marks:
		ScarMark.broadcast(mark, at)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if drop != null else PackedStringArray(["Falta la gota (ZoneDrop) cuyo final recibe."])
