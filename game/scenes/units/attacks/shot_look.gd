class_name ShotLook
extends Node

## How a creature's ranged shot looks and what it does in flight and on arrival: a scene of data/shots/ whose root is this node,
## handed over as a PackedScene (`look` of the ability node, or AbilityType.shot_look of a creature's attack). Flight and
## damage come from the AbilityType; no scene flies as a plain ball with no particles.
## The shot (or the weapon, or the strike) that uses it holds it as a child, so it goes when they go.
## Not: the flight itself (RangedShot), who is hit (ShotImpact), nor which look an attack has (AbilityType.shot_look).

## The shot's mesh (scenes/props/meshes/<tag>.res); empty = a ball of fallback_radius.
@export var mesh: Mesh
@export var model_scale := 1.0
## Side of the hit box in meters.
@export var hit_size := 0.7
## Random spin in turns per second around a random axis.
@export var spin_min := 0.0
@export var spin_max := 0.0
## The burst puffed along the flight on every peer, by time (FxTrail): one puff per trail_every / 60 s, whatever the frame rate.
## Empty = no trail.
@export var trail_fx: ParticleType
@export var trail_every := 1
## The trail only puffs while the shot flies at least this fast, in m/s (0 = always).
@export_range(0.0, 100.0, 0.5, "suffix:m/s") var trail_min_speed_m_s := 0.0
## The bursts broadcast where it bursts.
@export var impact_fx: Array[ParticleType] = []
## The mark it leaves on the ground where it bursts (a ScarMark scene from spells/marks/, played on every peer). Empty = none.
@export var ground_mark: PackedScene
## ShotImpact scene the server (or solo) applies where it bursts, in place of the plain direct ranged hit
## (impacts/*.tscn). Empty = the whole amount as direct ranged damage to the body it hit.
@export var impact: PackedScene
## The shot bursts on its target or on any body of the shooter's side, and flies through the rest
##. Off: its target or any body not of the shooter's side.
@export var hits_allies := false
## The shot bursts on any creature but its shooter (the Viscous oil's kcfa), whatever the side:
## neither the target nor the side filter matters. Wins over hits_allies.
@export var hits_every_side := false
## The shot only meets a body that Poisoning.can_be_poisoned; it flies through the rest.
@export var hits_only_poisonable := false
## The shot's hit carries DamageMod.ignite (fkba, cfba; fhba, the Spitfire's cone, is not a shot): on an oiled body it
## takes ×2 and lights the oil. RangedShot.mods -> ShotImpact.land and the impacts.
@export var ignites := false
## When its box touches nothing this frame, it also checks the segment it flew, so a small fast shot does not pass through a body. slba; amba and cita too.
@export var sweep := false
## At the end of its range it bursts there (impact included) instead of vanishing.
## slba; cita too (its vortex spawns where the range ends).
@export var burst_at_range_end := false
## ShotInFlight scene the server (or solo) puts on the shot; it acts on every tick of the flight. tugt: a
## ShotDropper (a droplet that falls on whoever is below); rdba: a
## GrowingWave + FreezeTouch (the Silverback's breath grows and freezes); fhba and
## ehba, the Spitfire's and the Gargoyle's waves (spitfire_wave, gargoyle_wave).
@export var in_flight: PackedScene
## Off: the shot touches nothing on its way, neither a body nor the ground, and flies its whole range (the
## Silverback's breath: its in_flight does the damage). On: it bursts on its hit (the rest of the shots).
@export var collides := true
## ShotStrike scene that replaces the flight (strikes/*.tscn): a ray at once (the Gnome's
## gnome_ray), a blow on the next tick (the Styx's styx_strike). RangedWeapon instances it on the server (or solo).
## Empty = a RangedShot flies.
@export var strike: PackedScene
## Shots per fire, one accuracy roll for all (which = −1, 0, +1).
## RangedWeapon writes volley_index −k..k and aim_distance in each packet (RangedShot.spawn_data).
@export_range(1, 9, 2) var volley := 1
## A straight shot flies range_factor · the SPEL's range (emba 2: 2·range).
@export var range_factor := 1.0
@export var fallback_color := Color(0.8, 0.7, 0.5)
@export var fallback_radius := 0.15


## The scene this look was made from (null for the plain ball).
var source: PackedScene


## A new look from `scene` (a data/shots/ scene), or a plain ball for null. The caller owns it: add it as a child.
static func make(scene: PackedScene) -> ShotLook:
	var made := scene.instantiate() as ShotLook if scene != null else null
	if made == null:
		made = ShotLook.new()
	made.source = scene
	return made


## Keeps `current` as a child of `holder` when it was made from `scene`; otherwise frees it and makes that one (a plain ball for null).
static func fit(holder: Node, current: ShotLook, scene: PackedScene) -> ShotLook:
	if current != null and current.source == scene:
		return current
	if current != null:
		current.queue_free()
	var made := make(scene)
	holder.add_child(made)
	return made
