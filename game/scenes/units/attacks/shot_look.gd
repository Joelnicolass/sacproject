class_name ShotLook
extends Node

## How a creature's ranged shot looks and what it does in flight and on arrival: the scene res://data/shots/<ability tag>.tscn, whose
## root is this node. Flight and damage come from the AbilityType; a tag without a scene flies as a plain ball with no particles.
## The shot (or the weapon, or the strike) that uses it holds it as a child, so it goes when they go.
## Not: the flight itself (RangedShot) nor who is hit (ShotImpact).

const LOOKS_DIR := "res://data/shots/"
## The scene of each tag looked up so far (null = it has none): the lookup runs once per tag, not once per shot.
static var _scenes: Dictionary = {}

## The shot's mesh (scenes/props/meshes/<tag>.res); empty = a ball of fallback_radius.
@export var mesh: Mesh
@export var model_scale := 1.0
## Side of the hit box in meters.
@export var hit_size := 0.7
## Random spin in turns per second around a random axis.
@export var spin_min := 0.0
@export var spin_max := 0.0
## FxBus type played along the flight on every peer, by time (FxTrail): one puff per
## trail_every / 60 s, whatever the frame rate.
@export var trail_fx := ""
@export var trail_every := 1
## The trail only puffs while the shot flies at least this fast, in m/s (0 = always).
@export_range(0.0, 100.0, 0.5, "suffix:m/s") var trail_min_speed_m_s := 0.0
## FxBus types broadcast where it bursts.
@export var impact_fx: PackedStringArray = PackedStringArray()
## 061k-5: the mark it leaves on the ground where it bursts (a ScarMark scene from spells/marks/, played on every peer). Empty = none.
@export var ground_mark: PackedScene
## F119: ShotImpact scene the server (or solo) applies where it bursts, in place of the plain direct ranged hit
## (impacts/*.tscn). Empty = the whole amount as direct ranged damage to the body it hit.
@export var impact: PackedScene
## F136: the shot bursts on its target or on any body of the shooter's side, and flies through the rest
## (scarabProjectileCollisionTarget, state.d:23637-23642). Off: its target or any body not of the shooter's side.
@export var hits_allies := false
## F155: the shot bursts on any creature but its shooter (the Viscous oil's kcfa, state.d:25580-25586), whatever the side:
## neither the target nor the side filter matters. Wins over hits_allies. Also read by 030s-b.
@export var hits_every_side := false
## F156: the shot only meets a body that Poisoning.can_be_poisoned (blightMiteCollisionTarget, state.d:25262-25269); it flies through the rest.
@export var hits_only_poisonable := false
## F155: the shot's hit carries DamageMod.ignite (fkba, cfba: state.d:23247, 24521; fhba, the Spitfire's cone, is not a shot): on an oiled body it
## takes ×2 and lights the oil. RangedShot.mods -> ShotImpact.land and the impacts.
@export var ignites := false
## F136: when its box touches nothing this frame, it also checks the segment it flew (lineOfSight in
## updateScarabProjectile, state.d:23655-23664), so a small fast shot does not pass through a body. slba; F121: amba and cita too (lineOfSightWithoutSide, 23863, 23992).
@export var sweep := false
## F136: at the end of its range it bursts there (impact included) instead of vanishing (updateScarabProjectile,
## state.d:23667-23670). slba; F121: cita too (its vortex spawns where the range ends, state.d:23866).
@export var burst_at_range_end := false
## F148/F149: ShotInFlight scene the server (or solo) puts on the shot; it acts on every tick of the flight. tugt: a
## ShotDropper (a droplet that falls on whoever is below, animateAbominationProjectile, state.d:24441-24452); rdba: a
## GrowingWave + FreezeTouch (the Silverback's breath grows and freezes, updateSilverbackProjectile, 24758-24831); F162: fhba and
## ehba, the Spitfire's and the Gargoyle's waves (spitfire_wave, gargoyle_wave).
@export var in_flight: PackedScene
## F149: off, the shot touches nothing on its way, neither a body nor the ground, and flies its whole range (the
## Silverback's breath: its in_flight does the damage). On: it bursts on its hit (the rest of the shots).
@export var collides := true
## F124 (RFC-030 030m): ShotStrike scene that replaces the flight (strikes/*.tscn): a ray at once (the Gnome's
## gnome_ray), a blow on the next tick (the Styx's styx_strike). RangedWeapon instances it on the server (or solo).
## Empty = a RangedShot flies.
@export var strike: PackedScene
## F125 (RFC-030 030n-a): shots per fire, one accuracy roll for all (boulderdashShoot fires which = −1, 0, +1,
## state.d:11806-11808). RangedWeapon writes volley_index −k..k and aim_distance in each packet (RangedShot.spawn_data).
@export_range(1, 9, 2) var volley := 1
## F125: a straight shot flies range_factor · the SPEL's range (emba 2: remainingDistance = 2·range, state.d:11799).
@export var range_factor := 1.0
@export var fallback_color := Color(0.8, 0.7, 0.5)
@export var fallback_radius := 0.15


## The ability tag this look was made for ("" for the plain ball).
var tag := ""


## A new look of the ability `tag` (res://data/shots/<tag>.tscn), or a plain ball. The caller owns it: add it as a child. The one
## lookup for RangedShot, RangedWeapon and the abilities that throw their own shots.
static func make(tag_name: String) -> ShotLook:
	if not _scenes.has(tag_name):
		var path := LOOKS_DIR + tag_name + ".tscn"
		_scenes[tag_name] = load(path) as PackedScene if not tag_name.is_empty() and ResourceLoader.exists(path) else null
	var scene: PackedScene = _scenes[tag_name]
	var made := scene.instantiate() as ShotLook if scene != null else null
	if made == null:
		made = ShotLook.new()
	made.tag = tag_name
	return made


## Keeps `current` as a child of `holder` when it is the look of `tag_name`; otherwise frees it and makes the right one ("" = none).
static func fit(holder: Node, current: ShotLook, tag_name: String) -> ShotLook:
	if current != null and current.tag == tag_name:
		return current
	if current != null:
		current.queue_free()
	if tag_name.is_empty():
		return null
	var made := make(tag_name)
	holder.add_child(made)
	return made
