class_name AiTrackFacts
extends RefCounted

## What a body is for the AI, worked out once when the side takes it in: its kind (wizard, creature,
## Manahoar, structure), its site (altar, fount, Manalith, shrine), whether it fights, what it is
## worth (`rate`). Static: it never follows a body in time (that is AiPerception) and never writes
## into the game. The Manahoar is the creature whose passive is the side's `mana_source` (hmba).

## What summoning a creature of `type` is worth, worked out once per type (it depends on the type
## only).
static var _tag_accs: Dictionary = {}


## The kind of `node` for the AI (NONE: the AI does not track it).
static func kind_of(node: Node, mana_source: AbilityType) -> AiTrack.Kind:
	if node.is_in_group(WizardBody.GROUP):
		return AiTrack.Kind.WIZARD
	if node.is_in_group(UnitBody.GROUP):
		var type: Variant = node.get("type")
		return (
			kind_of_type(type as CreatureType, mana_source)
			if type != null
			else AiTrack.Kind.CREATURE
		)
	if node.is_in_group(Altar.GROUP) or node.is_in_group(ManafountBody.GROUP):
		return AiTrack.Kind.STRUCTURE
	if node is CastTower:
		return AiTrack.Kind.STRUCTURE
	return AiTrack.Kind.NONE


## A creature type is a Manahoar when its passive is the mana source (the Manahoar's ManaSupport),
## else a plain creature.
static func kind_of_type(type: CreatureType, mana_source: AbilityType) -> AiTrack.Kind:
	return (
		AiTrack.Kind.MANAHOAR
		if type != null and type.has_passive(mana_source)
		else AiTrack.Kind.CREATURE
	)


## What a structure is: a fount, an altar, a shrine, else a Manalith.
static func site_of(node: Node) -> AiTrack.Site:
	if node.is_in_group(ManafountBody.GROUP):
		return AiTrack.Site.FOUNT
	if node.is_in_group(Altar.GROUP):
		return AiTrack.Site.ALTAR
	if node is CastTower and (node as CastTower).type.role == BuildingType.Role.SHRINE:
		return AiTrack.Site.SHRINE
	return AiTrack.Site.MANALITH


## A creature fights when it has an ability or is not a pacifist.
static func fights_of(type: CreatureType) -> bool:
	return type != null and (ability_count(type) > 0 or type.aggressiveness != 0)


## The abilities the creature really has: an empty slot does not count.
static func ability_count(type: CreatureType) -> int:
	return type.abilities().size()


## What side `other` is to side `side`: own, ally, enemy or neutral.
static func relation(side: int, other: int) -> AiTrack.Relation:
	if other == side:
		return AiTrack.Relation.OWN
	if (
		SideRelations.stance(side, other) == SideRelations.Stance.ALLY
		or SideRelations.stance(other, side) == SideRelations.Stance.ALLY
	):
		return AiTrack.Relation.ALLY
	if (
		SideRelations.stance(side, other) == SideRelations.Stance.ENEMY
		or SideRelations.stance(other, side) == SideRelations.Stance.ENEMY
	):
		return AiTrack.Relation.ENEMY
	return AiTrack.Relation.NEUTRAL


static func tag_acc(type: CreatureType) -> PackedFloat32Array:
	if not _tag_accs.has(type):
		var abilities: Array = []
		abilities.assign(type.abilities())
		_tag_accs[type] = AiRater.fill_by_tag(type, abilities)
	return _tag_accs[type]


static func make(
	node: Node3D, kind: AiTrack.Kind, origin: AiTrack.Origin, perception: AiPerception
) -> AiTrack:
	var t := AiTrack.new()
	t.kind = kind
	t.node = node
	t.id = node.get_instance_id()
	t.origin = origin
	setup(t, perception)
	return t


## A new track of `perception`: its side, where it is, what it is and, for a body, what it is worth.
## Health and mana only of a body the side sees now: of one it does not (a foe of the first scan) it
## knows nothing until it sees it (no difficulty cheats).
static func setup(t: AiTrack, perception: AiPerception) -> void:
	t.relation = perception.relation_of(t.node)
	if t.relation == AiTrack.Relation.OWN:
		t.age_seen = 0
	var here := t.node.global_position
	t.cur_pos = here
	t.prev_pos = here
	t.extrap_pos = here
	var seen := perception.sees(t)
	if t.is_body() and seen:
		perception.belief.snapshot(t, perception.slot)
	match t.kind:
		AiTrack.Kind.WIZARD:
			t.fights = true
			if seen:
				t.min_mana_cost = float(AiRater.ftol(AiBody.mana_max(t.node)) / 4)
			t.spell_dirty = true
			rate(t, perception)
		AiTrack.Kind.CREATURE, AiTrack.Kind.MANAHOAR:
			var type := t.node.get("type") as CreatureType
			if fights_of(type):
				t.fights = true
			# The mana below which a creature with abilities goes to a source to recharge (the
			# Manahoar has none).
			if t.kind == AiTrack.Kind.CREATURE and type != null and seen:
				t.min_mana_cost = (
					float(AiRater.ftol(AiBody.mana_max(t.node))) if ability_count(type) > 0 else 0.0
				)
				for ability in type.abilities():
					if float(ability.mana_cost) < t.min_mana_cost:
						t.min_mana_cost = float(ability.mana_cost)
			rate(t, perception)
		AiTrack.Kind.STRUCTURE:
			t.site = site_of(t.node)
			refresh_structure(t)


## A structure's state now: a fount is free (nothing built on it) and ready when nobody built on it;
## every other structure is ready.
static func refresh_structure(t: AiTrack) -> void:
	var top_free := true
	if t.site == AiTrack.Site.FOUNT:
		top_free = (t.node as ManafountBody).is_free()
	apply_structure(t, top_free)


## The state of a structure whose top is free or not (the readings of refresh_structure, apart so
## the suite can test them).
static func apply_structure(t: AiTrack, top_free: bool) -> void:
	if t.site == AiTrack.Site.FOUNT:
		t.free_fount = top_free
	t.ready = top_free


## The current mana and the file stats a body is rated by.
static func rate(t: AiTrack, perception: AiPerception) -> void:
	var node := t.node
	var abilities: Array = []
	var spells: Array = []
	var ts: Dictionary
	if t.kind == AiTrack.Kind.WIZARD:
		ts = AiRater.WIZARD_STATS
		var book := AiBody.spellbook(node)
		if book != null:
			for i in book.size():
				spells.append(book.spell_at(i))
	else:
		var type := node.get("type") as CreatureType
		if type == null:
			return
		ts = AiRater.stats_of(type)
		abilities.assign(type.abilities())
	t.acc = AiRater.fill_from_object(ts, perception.mana_of(t).x, abilities, spells)
	t.cached_rate = AiRater.rate(t.acc)
