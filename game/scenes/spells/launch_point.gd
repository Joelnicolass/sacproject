class_name LaunchPoint
extends RefCounted

## Where a wizard's ball leaves and what a guided projectile is told when it does. It does not aim, pick a target or spawn anything.

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")


## Where a thrown ball leaves: the Muzzle marker of the wizard's body scene (hand height, in front of his hit box).
static func from_hand(wizard: WizardBody) -> Vector3:
	return from_hand_facing(wizard, wizard.facing_flat())


## The same spot with the wizard turned to `facing` (flat, unit): the AI asks where the ball will leave once he turns to his target.
static func from_hand_facing(wizard: WizardBody, facing: Vector3) -> Vector3:
	var muzzle := BodyFacts.of_body(wizard).muzzle
	var at := wizard.global_position + Vector3(0.0, muzzle.y, 0.0)
	at += facing * muzzle.z
	return at


## The keys every guided projectile's `setup` reads, flying from `from` at `target` (or at `point` when it is gone).
static func projectile_data(wizard: Node3D, spell: SpellType, from: Vector3, target: Node3D, point: Vector3) -> Dictionary:
	var aim := _ROCK.body_center(target) if target else point
	return {
		"x": from.x, "y": from.y, "z": from.z,
		"tx": aim.x, "ty": aim.y, "tz": aim.z,
		"target": str(target.get_path()) if target else "",
		"caster": str(wizard.get_path()),
		"slot": int(wizard.get("owner_slot")),
		"speed": spell.speed_m_s,
		"acceleration": spell.acceleration_m_s2,
		"damage": float(spell.damage),
	}
