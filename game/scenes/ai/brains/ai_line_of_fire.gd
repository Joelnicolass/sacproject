class_name AiLineOfFire
extends RefCounted

## Whether the AI's wizard has a clear shot at a body (RFC-053 053b, F371; executeBestCast's line of fire and sight, shiny.d:3246-3270).
## One owner of the question: a ray from where the ball leaves (AimedAction.hand_origin, the wizard turned to the target) to the
## center of the target.
##   A projectile (Rock, Wrath, Fireball, Swarm): the first body the ball would burst on that is not the target blocks it. The
##   bodies are the ones `pick_body` takes (mask 3, live bodies of Attackable, the caster skipped; the thrown balls skip their
##   own side as wrathCollisionTarget does). A body that is not one of those (the terrain, a rock of the map) blocks the sight.
##   Any other spell (Lightning): only the terrain and what is not a body block it.
## Rays, not the ball's box (0.1 m Wrath, 2 m Rock): «aprox.», the line the human sees and one under it. It reads the world as it is, like the
## human's eye; the AI only asks it about a body it can aim at (AiCommandPort.can_aim, checked before).

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

## pick_body's mask: the ground and buildings (1) and the creatures (2).
const BODY_MASK := 3
## A ray that keeps going through bodies it ignores stops after this many.
const MAX_STEPS := 8
## The second ray of a projectile, this far under the straight line: the ball's box and its lift over the ground (Wrath flies
## 0.5 m over it) take it lower than the line from the hand to the center («aprox.»).
const LOW_RAY_M := 0.5

## How the spell's effect travels (flight_of): nothing flies, a projectile, a thrown ball that skips its own side.
const FLIGHT_NONE := 0
const FLIGHT_PROJECTILE := 1
const FLIGHT_THROWN := 2


## {"blocker": the node that stops the shot (null: clear), "point": where the spell would burst (the blocker's hit point, else the
## target's center), "flight": FLIGHT_*}.
static func trace(wizard: WizardBody, target: Node3D, spell: SpellType) -> Dictionary:
	var flight := flight_of(wizard, spell)
	var to := _ROCK.body_center(target)
	## the wizard turns to the target as he casts: the ball leaves from his hands facing it
	var facing := to - wizard.global_position
	facing.y = 0.0
	var from := AimedAction.hand_origin_facing(wizard, facing.normalized()) if facing.length_squared() > 0.0001 else AimedAction.hand_origin(wizard)
	var out := _ray(wizard, target, from, to, flight)
	if out["blocker"] == null and flight != FLIGHT_NONE:
		## A ball flies lower than the straight line (its box, the lift over the ground): a second ray LOW_RAY_M under it.
		var low := _ray(wizard, target, from + Vector3.DOWN * LOW_RAY_M, to + Vector3.DOWN * LOW_RAY_M, flight)
		if low["blocker"] != null:
			out = low
	out["point"] = out["point"] if out["blocker"] != null else to
	out["flight"] = flight
	return out


static func _ray(wizard: WizardBody, target: Node3D, from: Vector3, to: Vector3, flight: int) -> Dictionary:
	var out := {"blocker": null, "point": to}
	if from.distance_squared_to(to) < 0.0001:
		return out
	var space := wizard.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, BODY_MASK)
	var exclude: Array[RID] = [wizard.get_rid()]
	var slot := int(wizard.owner_slot)
	for _step in MAX_STEPS:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return out
		var node := hit.get("collider") as Node3D
		if node == target:
			return out
		var blocks := node == null or not _is_body(node)
		if not blocks and flight != FLIGHT_NONE and _ROCK.is_live_body(node):
			blocks = not (flight == FLIGHT_THROWN and _owner_of(node) == slot)
		if blocks:
			out["blocker"] = node
			out["point"] = hit.get("position", to)
			return out
		var rid: Variant = hit.get("rid")
		if rid == null:
			return out
		exclude.append(rid)
	return out


## The first body hit that is not the target, or null when the line is clear.
static func clear(wizard: WizardBody, target: Node3D, spell: SpellType) -> Node3D:
	return trace(wizard, target, spell)["blocker"] as Node3D


## How the spell of `wizard`'s book travels: a thrown ball that skips its own side (ThrownAction: Wrath, Fireball, Swarm), a
## projectile that does not (Rock), or nothing (Lightning, Heal).
static func flight_of(wizard: WizardBody, spell: SpellType) -> int:
	var caster := wizard.get_node_or_null("Caster") as Caster
	var action: SpellAction = caster.action_for(spell.tag) if caster != null else null
	if action is ThrownAction:
		return FLIGHT_THROWN
	if action is RockAction:
		return FLIGHT_PROJECTILE
	return FLIGHT_NONE


## A spell whose burst hurts every body around it (ThrownAction explodes with SplashDamage over damage_range).
static func is_splash(wizard: WizardBody, spell: SpellType) -> bool:
	return spell.damage_range > 0.0 and flight_of(wizard, spell) == FLIGHT_THROWN


static func _is_body(node: Node) -> bool:
	return Attackable.is_body(node) or node.is_in_group(Attackable.CORPSE)


static func _owner_of(node: Node) -> int:
	return int(node.get("owner_slot")) if "owner_slot" in node else 0
