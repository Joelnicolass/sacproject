@tool
class_name ZoneAction
extends SpellAction

## A spell that raises a zone on the ground (Explosion, Frozen Ground, Demonic Rift, and the clouds: Rain of Frogs, Rain of Fire, Plague,
## Cloudkill, Bombardment): the click names the ground, the zone is born when the cast starts (it is drawn while the wizard casts), the
## cast's end releases it and an interrupted cast cancels it. One script for all of them; the zone's scene says what happens there. It
## does not act on bodies (the zone's children do) nor time the zone (GroundZone does).

enum Anchor { CLICK, WIZARD }

## The kind of the zone scene in SpellSpawner.zones (match.tscn).
@export var kind := ""
## Where the zone stands: on the click, or under the wizard (a rift opens at his feet and looks around the click).
@export var anchor := Anchor.CLICK
## Extra points scattered around the click inside the spell's effect range (Explosion: 4).
@export_range(0, 8) var scatter := 0
## Seconds between the cast's end and the moment the zone acts (Frozen Ground's snowball flies 2 s). 0 = at once.
@export_range(0.0, 10.0, 0.01, "suffix:s") var arm_s := 0.0
## `arm_s` counts from the start of the cast instead (Explosion goes off 3.8 s after it begins).
@export var arm_from_start := false
## More than 0: the zone stands on the nearest point of a grid of this many metres (a volcano is fixed to the ground's 10 m lattice).
@export_range(0.0, 20.0, 0.5, "suffix:m") var snap_m := 0.0
@export_group("Ring of roots")
## More than 0: the zone stands on the click and its points are this many roots around it, one per equal slice of a turn (Meanstalks: 4).
@export_range(0, 12) var ring_count := 0
@export_range(0.0, 100.0, 0.1, "suffix:m") var ring_inner_m := 9.0
@export_range(0.0, 100.0, 0.1, "suffix:m") var ring_outer_m := 21.6
## Each root may stray this far from the middle of its slice.
@export_range(0.0, 180.0, 0.5, "suffix:°") var ring_jitter_deg := 22.5
## A root that falls off the land is tried again this many times at random inside this radius (the original: 32 tries within 18 m).
@export_range(0, 64) var ring_retries := 32
@export_range(0.0, 100.0, 0.1, "suffix:m") var ring_retry_m := 18.0
@export_group("Look")
## Played on every peer while the wizard casts (FxBus.broadcast_scene; its root answers play(params): `ticks` and `wizard`). Optional.
@export var cast_scene: PackedScene
## A creature or wizard the click names is the zone's target: the zone follows it (Cloudkill's cloud chases it).
@export var follows_target := false

var _zone: GroundZone


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if kind.is_empty():
		warnings.append("`kind` is missing: the SpellSpawner's kind of zone.")
	return warnings


## Funds first (cooldown, mana), then the range: the order every spell of the book answers in. The click only needs to be a point.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = picked.global_position if picked != null else point
	aim.target = wizard
	if follows_target and picked != null and ProjectileTargets.is_live_body(picked):
		aim.data["follow"] = str(picked.get_path())
	aim.status = standing_status(funds, wizard, spell, aim.point)
	return aim


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	var spawner := get_tree().get_first_node_in_group(SpellSpawner.GROUP) as SpellSpawner
	if spawner == null:
		return
	var data := _data(wizard, spell, aim.point, frames)
	data["follow"] = aim.data.get("follow", "")
	_zone = spawner.spawn_zone(kind, data) as GroundZone
	if cast_scene != null:
		FxBus.broadcast_scene(cast_scene, wizard.global_position, {"ticks": frames, "wizard": str(wizard.get_path())})


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
	var rng := MatchSeed.rng(["zone", spell.tag, String(wizard.name), MatchClock.now()])
	var origin := _ground(wizard.global_position) if anchor == Anchor.WIZARD else click
	if snap_m > 0.0:
		origin = _ground(Vector3(floorf((origin.x + snap_m * 0.5) / snap_m), origin.y, floorf((origin.z + snap_m * 0.5) / snap_m)) * Vector3(snap_m, 1.0, snap_m))
	if ring_count > 0:
		points = _roots(rng, click)
		origin = _ground(click)
	else:
		points.append(origin)
	for i in scatter:
		points.append(_ground(click + ZoneRules.disk_point(rng, spell.effect_range_m)))
	var wait := MatchClock.ticks_for(arm_s)
	return {
		"x": origin.x, "y": origin.y, "z": origin.z, "points": points, "aim": click,
		"slot": wizard.owner_slot, "caster": str(wizard.get_path()), "cast_ticks": frames,
		"arm_ticks": maxi(0, wait - frames) if arm_from_start else wait,
	}


## The roots of a ring on the ground: a root off the land is drawn again around where it fell (the zone keeps the last one when none fits).
func _roots(rng: RandomNumberGenerator, click: Vector3) -> PackedVector3Array:
	var roots := ZoneRules.ring_points(rng, click, ring_count, ring_inner_m, ring_outer_m, deg_to_rad(ring_jitter_deg))
	var shape := Terrain.of(self)
	for i in roots.size():
		var fell := roots[i]
		for _try in ring_retries:
			if shape == null or shape.is_on_ground(roots[i].x, roots[i].z):
				break
			roots[i] = fell + ZoneRules.disk_point(rng, ring_retry_m)
		roots[i] = _ground(roots[i])
	return roots


## `at` with the height of the land under it (the click's own height when there is no land to ask).
func _ground(at: Vector3) -> Vector3:
	var shape := Terrain.of(self)
	var land := shape.height_at(at.x, at.z) if shape != null else NAN
	return Vector3(at.x, at.y if is_nan(land) else land, at.z)
