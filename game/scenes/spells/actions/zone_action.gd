@tool
class_name ZoneAction
extends SpellAction

## A spell that raises a zone on the ground (Explosion, Frozen Ground, Demonic Rift): the click names the ground, the zone is born when the
## cast starts (it is drawn while the wizard casts), the cast's end releases it and an interrupted cast cancels it. One script for all of
## them; the zone's scene says what happens there. It does not act on bodies (the zone's pulses do) nor time the zone (GroundZone does).
## Ref: sacengine castExplosion, castFrozenGround, castDemonicRift (state.d:9986-10013, 10960-11116).

enum Anchor { CLICK, WIZARD }

## The kind of the zone scene in SpellSpawner.
@export var kind := ""
## Where the zone stands: on the click, or under the wizard (a rift opens at his feet and looks around the click).
@export var anchor := Anchor.CLICK
## Extra points scattered around the click inside the spell's effect range (Explosion: 4).
@export_range(0, 8) var scatter := 0
## Seconds between the cast's end and the moment the zone acts (Frozen Ground's snowball flies 2 s). 0 = at once.
@export_range(0.0, 10.0, 0.01, "suffix:s") var arm_s := 0.0
## `arm_s` counts from the start of the cast instead (Explosion goes off 3.8 s after it begins).
@export var arm_from_start := false

var _zone: GroundZone


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if kind.is_empty():
		warnings.append("Falta `kind`: la clase de zona del SpellSpawner.")
	return warnings


## Funds first (cooldown, mana), then the range: the order every spell of the book answers in. The click only needs to be a point.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = picked.global_position if picked != null else point
	aim.target = wizard
	aim.status = standing_status(funds, wizard, spell, aim.point)
	return aim


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	var spawner := get_tree().get_first_node_in_group(SpellSpawner.GROUP) as SpellSpawner
	if spawner == null:
		return
	_zone = spawner.spawn_projectile(kind, _data(wizard, spell, aim.point, frames)) as GroundZone


func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	if _zone != null and is_instance_valid(_zone):
		_zone.release()
	_zone = null
	return ""


func cancel() -> void:
	if _zone != null and is_instance_valid(_zone):
		_zone.cancel()
	_zone = null


## What the zone's `setup` reads: where it stands, its points, who cast it and how long the cast and the wait are.
func _data(wizard: WizardBody, spell: SpellType, click: Vector3, frames: int) -> Dictionary:
	var points := PackedVector3Array()
	points.append(_ground(wizard.global_position) if anchor == Anchor.WIZARD else click)
	var rng := MatchSeed.rng(["zone", spell.tag, String(wizard.name), MatchClock.now()])
	for i in scatter:
		points.append(_ground(click + ZoneRules.disk_point(rng, spell.effect_range)))
	var wait := MatchClock.ticks_for(arm_s)
	return {
		"x": points[0].x, "y": points[0].y, "z": points[0].z, "points": points, "aim": click,
		"slot": wizard.owner_slot, "caster": str(wizard.get_path()), "cast_ticks": frames,
		"arm_ticks": maxi(0, wait - frames) if arm_from_start else wait,
	}


## `at` with the height of the land under it (the click's own height when there is no land to ask).
func _ground(at: Vector3) -> Vector3:
	var shape := TerrainShape.of(self)
	var land := shape.height_at(at.x, at.z) if shape != null else NAN
	return Vector3(at.x, at.y if is_nan(land) else land, at.z)
