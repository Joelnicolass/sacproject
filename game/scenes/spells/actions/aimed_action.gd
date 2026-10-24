@tool
class_name AimedAction
extends SpellAction

## A combat spell aimed at one body under the cursor (RFC-041). The common part (mana, cooldown, casting
## frames, drain) is Caster's; this holds the shared checks, in the order every spell of the book answers in:
## cooldown and mana (`funds`), then a valid body, then the cast range. A subclass picks which body is valid
## (`resolve_target`) and what the spell does (`started` / `finish`). The default target is a living enemy
## body (SPEL flags 8213: wizards, creatures, structures, disallowAlly; no targetGround).

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

## Hands of a wizard, as a fraction of the body height (a thrown ball leaves from there).
const HAND_HEIGHT := 0.65


## The body the cast lands on, or null (the click named nothing valid). Default: a living enemy.
func resolve_target(wizard: WizardBody, _spell: SpellType, picked: Node3D) -> Node3D:
	return enemy_body(wizard, picked)


## `picked` comes from the client: the body is validated here.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	aim.target = resolve_target(wizard, spell, picked)
	if aim.target == null:
		aim.status = BAD_TARGET
	elif wizard.global_position.distance_to(aim.target.global_position) > spell.cast_range:
		aim.status = OUT_OF_RANGE
	return aim


## The wizard or a creature of his side.
static func is_ally(wizard: Node3D, body: Node) -> bool:
	return body == wizard or int(body.get("owner_slot") if "owner_slot" in body else 0) == int(wizard.get("owner_slot"))


## `picked` when it is a living body of another side, else null.
static func enemy_body(wizard: Node3D, picked: Node3D) -> Node3D:
	return picked if picked and not is_ally(wizard, picked) and _ROCK.is_live_body(picked) else null


## `picked` when it is an ally, the wizard himself when nothing was picked, else null.
static func ally_or_self(wizard: Node3D, picked: Node3D) -> Node3D:
	if picked == null:
		return wizard
	return picked if is_ally(wizard, picked) else null


## Where a thrown ball leaves: the front of the wizard's hit box, at hand height (there are no hand bones).
static func hand_origin(wizard: WizardBody) -> Vector3:
	return hand_origin_facing(wizard, wizard.facing_flat())


## The same spot with the wizard turned to `facing` (flat, unit): the AI asks where the ball will leave once he turns to his target.
static func hand_origin_facing(wizard: WizardBody, facing: Vector3) -> Vector3:
	var info := BodyCatalog.info(str(wizard.get("model")))
	var at := wizard.global_position + Vector3.UP * float(info.get("height", 1.8)) * HAND_HEIGHT
	at += facing * float(info.get("reach", 0.5))
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
		"speed": spell.speed,
		"acceleration": spell.acceleration,
		"damage": float(spell.damage),
	}
