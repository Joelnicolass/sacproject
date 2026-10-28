class_name ProjectileLaunch
extends RefCounted

## What a guided spell projectile (or a carrier) is told when it leaves: where it starts, what it
## aims at, who cast it and the spell's numbers. It travels as a Dictionary only inside SpellSpawner
## (`to_dict` on the server, `from_dict` in the projectile's `setup` on every peer).

## The node name SpellSpawner gave it, the same on every peer. Set by the spawner, not by the
## caller.
var name := ""
## Where it starts, in world space.
var from := Vector3.ZERO
## Where it flies when the target is gone: the target's center at launch, or the clicked point.
var aim := Vector3.ZERO
## The body it flies at (empty = only `aim`).
var target := NodePath()
## The body that cast it (empty = none).
var caster := NodePath()
## The caster's player slot (0 = no player).
var slot := 0
var speed_m_s := 0.0
var acceleration_m_s2 := 0.0
var damage := 0.0
## The splash radius around the body it hits.
var damage_range_m := 0.0
## How many ticks the casting lasts (the rock rises during them; a carrier waits).
var cast_ticks := 0


## A launch of `spell` by `wizard` from `at` toward `body` (or toward `point` when there is no
## body).
static func toward(
	wizard: WizardBody, spell: SpellType, at: Vector3, body: Node3D, point: Vector3
) -> ProjectileLaunch:
	var launch := ProjectileLaunch.new()
	launch.from = at
	launch.aim = ProjectileTargets.body_center(body) if body else point
	launch.target = body.get_path() if body else NodePath()
	launch.caster = wizard.get_path()
	launch.slot = wizard.owner_slot
	launch.speed_m_s = spell.speed_m_s
	launch.acceleration_m_s2 = spell.acceleration_m_s2
	launch.damage = float(spell.damage)
	launch.damage_range_m = spell.damage_range_m
	return launch


## The wire form: plain values only, so it crosses the network the same on every peer.
func to_dict() -> Dictionary:
	return {
		"from": from,
		"aim": aim,
		"target": str(target),
		"caster": str(caster),
		"slot": slot,
		"speed": speed_m_s,
		"acceleration": acceleration_m_s2,
		"damage": damage,
		"damage_range": damage_range_m,
		"cast_ticks": cast_ticks,
	}


## Reads the wire form back (the `name` key comes from SpellSpawner).
static func from_dict(data: Dictionary) -> ProjectileLaunch:
	var launch := ProjectileLaunch.new()
	launch.name = str(data.get("name", ""))
	launch.from = data.get("from", Vector3.ZERO)
	launch.aim = data.get("aim", Vector3.ZERO)
	launch.target = NodePath(str(data.get("target", "")))
	launch.caster = NodePath(str(data.get("caster", "")))
	launch.slot = int(data.get("slot", 0))
	launch.speed_m_s = float(data.get("speed", 0.0))
	launch.acceleration_m_s2 = float(data.get("acceleration", 0.0))
	launch.damage = float(data.get("damage", 0.0))
	launch.damage_range_m = float(data.get("damage_range", 0.0))
	launch.cast_ticks = int(data.get("cast_ticks", 0))
	return launch
