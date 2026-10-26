class_name AiBody
extends RefCounted

## The one place where the AI reads a body of the game: whether it is dead, its health, its mana and its book. It only
## reads (it never writes into a body) and answers zero or null for a body without that part. Typed: no `has_method`, no `call`.
## Ref: shiny.d:1458-1464 node vtbl[5] (mana pair), 2715-2722 healthPair.


## A unit or a Sac Doctor that is dying or dead (the bodies that can die; a wizard, a structure or a soul answer false).
static func is_dead(node: Node) -> bool:
	if node is UnitBody:
		return (node as UnitBody).is_dead()
	if node is DoctorBody:
		return (node as DoctorBody).is_dead()
	return false


static func mana_now(node: Node) -> float:
	var pool := node.get_node_or_null("ManaPool")
	return float(pool.get("current")) if pool != null else 0.0


static func mana_max(node: Node) -> float:
	var pool := node.get_node_or_null("ManaPool")
	return float(pool.get("maximum")) if pool != null else 0.0


## (current, maximum) of health, rounded like the original.
static func health_pair(node: Node) -> Vector2i:
	var health := node.get_node_or_null("Health")
	if health == null:
		return Vector2i.ZERO
	return Vector2i(AiRater.ftol(float(health.get("current"))), AiRater.ftol(float(health.get("maximum"))))


## (mana, maximum mana) of a creature or a wizard; a Manahoar has none.
static func mana_pair(t: AiTrack) -> Vector2i:
	if t.kind == AiTrack.Kind.MANAHOAR:
		return Vector2i.ZERO
	return Vector2i(AiRater.ftol(mana_now(t.node)), AiRater.ftol(mana_max(t.node)))


static func spellbook(node: Node) -> Spellbook:
	return node.get_node_or_null("Spellbook") as Spellbook
