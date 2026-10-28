@tool
class_name SpellTarget
extends Resource

## Who a spell may land on, as data: the body the click names must be of this kind, alive and (if
## asked) on the ground and not already protected from crowd control. A SpellAction embeds one in
## its scene, so a new single-target spell is a scene and a `.tres`, not a subclass. It does not
## aim, start the cast or apply anything: it answers «is this body a valid target?».

## OWN_OR_SELF and NOT_OWN compare `owner_slot` only (the wizard and the creatures of his player);
## ALLY_OR_SELF and ENEMY use the side relations (allies of other players count). Append only: the
## values are saved as integers.
enum Who { SELF, ALLY_OR_SELF, ENEMY, ANY, OWN_OR_SELF, NOT_OWN }

@export var who := Who.ENEMY
## Off: a dead or untargetable body is valid too (Heal and Speedup only ask for the body they act
## on).
@export var alive_only := true
## Refuses a body that flies (Grasping Vines: a flier is never tied).
@export var ground_only := false
## Refuses a body that is protected from control: shielded, petrified, frozen, in Rings of Fire,
## slimed or vined.
@export var refuse_cc_protected := false
## Refuses a wizard (the level-8 spells aim at creatures: SPEL flags have no «wizards» bit).
@export var refuse_wizards := false
## Off: refuses a body of no player (owner_slot 0: the creatures of the map, which have no wizard).
## Charm's rule.
@export var neutral_allowed := true


## The body the cast lands on, or null when `picked` is not a valid target for `wizard`. SELF and a
## missing pick (for ALLY_OR_SELF) give the wizard.
func pick(wizard: Node3D, picked: Node3D) -> Node3D:
	var body := _by_who(wizard, picked)
	if body == null or (alive_only and not ProjectileTargets.is_live_body(body)):
		return null
	if ground_only and BodyNudge.airborne(body):
		return null
	if refuse_wizards and body.is_in_group(WizardBody.GROUP):
		return null
	if not neutral_allowed and int(body.get("owner_slot")) <= 0:
		return null
	if refuse_cc_protected:
		var afflictions := Afflictions.of(body)
		if afflictions != null and afflictions.cc_protected():
			return null
	return body


## The wizard himself or a body of the same player (same `owner_slot`).
static func same_owner(wizard: Node3D, body: Node) -> bool:
	return (
		body == wizard
		or (
			int(body.get("owner_slot") if "owner_slot" in body else 0)
			== int(wizard.get("owner_slot"))
		)
	)


func _by_who(wizard: Node3D, picked: Node3D) -> Node3D:
	if who == Who.SELF:
		return wizard
	if who == Who.ANY:
		return picked
	if who == Who.OWN_OR_SELF:
		return wizard if picked == null else (picked if same_owner(wizard, picked) else null)
	if who == Who.NOT_OWN:
		return picked if picked != null and not same_owner(wizard, picked) else null
	if picked == null:
		return wizard if who == Who.ALLY_OR_SELF else null
	var allied := (
		picked == wizard
		or (
			SideRelations.stance(int(wizard.get("owner_slot")), int(picked.get("owner_slot")))
			== SideRelations.Stance.ALLY
		)
	)
	return picked if allied == (who == Who.ALLY_OR_SELF) else null
