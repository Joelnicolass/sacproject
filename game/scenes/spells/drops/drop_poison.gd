@tool
class_name DropPoison
extends Node

## What a drop of plague does where its flight ends: the body it ended on takes a contagious dose of
## poison, and every creature within the spell's damage range takes a weaker one that falls off with
## distance. The dose is the spell's damage spread over `seconds`; the poisoned do not regenerate.
## It does not fly the drop (ZoneDrop) nor hurt at once (DropBlast). Server (or solo) only.

@export var drop: ZoneDrop
## Bursts played where it ends, and the one played on the body it poisons (ParticleType under
## data/fx/).
@export var bursts: Array[ParticleType] = []
@export var hit_burst: ParticleType
@export_group("Dose")
## What share of the spell's damage a second of the dose takes, and for how long: 0.1 for 10 s is
## the whole damage.
@export_range(0.0, 1.0, 0.01) var share_per_s := 0.1
@export_range(0.5, 60.0, 0.5, "suffix:s") var seconds := 10.0
## The dose of a body only splashed is this share of the direct one, falling off to nothing at the
## edge.
@export_range(0.0, 1.0, 0.01) var splash_share := 0.1
@export var infectious := true
## What the poison leaves of the body's regeneration (the SPEL's `freg`: 0 = none).
@export_range(0.0, 1.0, 0.05) var regeneration := 0.0
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _ready() -> void:
	if not Engine.is_editor_hint() and drop != null and multiplayer.is_server():
		drop.ended.connect(poison)


## The poison at `at`, on `body` (null = the ground).
func poison(body: Node3D, at: Vector3) -> void:
	var per_second := drop.damage * share_per_s
	var ticks := MatchClock.ticks_for(seconds)
	var live := body != null and is_instance_valid(body) and ProjectileTargets.is_live_body(body)
	if live:
		_dose(body, per_second, ticks)
		if hit_burst != null:
			FxBus.broadcast(hit_burst, BodyNudge.center(body))
	for hit in SplashDamage.bodies_within(
		get_tree(), at, drop.damage_range, body if live else null, groups
	):
		var near := 1.0 - SplashDamage.box_distance(hit, at) / drop.damage_range
		_dose(hit, per_second * splash_share * near, ticks)
	for type in bursts:
		FxBus.broadcast(type, at)


func _dose(body: Node3D, per_second: float, ticks: int) -> void:
	Poisoning.dose_body(
		body, per_second, ticks, Health.SPLASH_SPELL, drop.from_slot, infectious, 0, regeneration
	)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if drop != null
		else PackedStringArray(["The drop (ZoneDrop) whose end it gets is missing."])
	)
