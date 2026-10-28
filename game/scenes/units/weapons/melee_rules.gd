class_name MeleeRules
extends RefCounted

## The numbers behind a melee blow, with no node: which way a body faces, the defense and size of a target and the damage a blow
## rolls. Not: when a swing starts or lands (MeleeWeapon) nor where it reaches (MeleeReach).

## The clip of each swing: attack, attack2 (both picked at random) and attack3 (the downward one).
const SWING_ROLES: Array[StringName] = [&"attack", &"attack2", &"attack3"]


static func facing_of(node: Node3D) -> Vector3:
	if node is GameBody:
		return (node as GameBody).facing_flat()
	var ahead := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, node.global_rotation.y)
	return Vector3(ahead.x, 0.0, ahead.z).normalized()


## Defense and size of any target: a creature, a Sac Doctor or a building answers melee_profile(); a wizard reads its type.
static func profile_of(target: Node3D) -> Dictionary:
	if target is UnitBody:
		return (target as UnitBody).melee_profile()
	if target is DoctorBody:
		return (target as DoctorBody).melee_profile()
	if target is MapBuilding:
		return (target as MapBuilding).melee_profile()
	var facts := BodyFacts.of_body(target)
	var result := {
		"evasion": 0.0,
		"resistance": 1.0,
		"reach": facts.reach_m,
		"height": facts.height_m,
	}
	var wizard: WizardType = (target as WizardBody).wizard_type if target is WizardBody else null
	if wizard:
		result["evasion"] = float(wizard.melee_evasion_milli())
		result["resistance"] = wizard.melee_resistance
	return result


## The blow of `weapon` on `target`: the chance to hit, one roll and the damage it carries. The one draw from the body's stream
## is the roll; do not add another before it.
static func roll(weapon: MeleeWeapon, target: Node3D) -> Dictionary:
	var body := weapon.body
	var type := weapon.type
	var passive := weapon.passive()
	var pending := weapon.swing.pending
	var facing := 1.5 + 0.5 * facing_of(body).dot(facing_of(target))
	var damage := facing * pending
	var foe := profile_of(target)
	# The Storm Giant's Lightning Charge makes it x1.5; each layer of Slime on the attacker costs accuracy and each on the target
	# costs its evasion, x0.2.
	var accuracy := (
		float(type.melee_accuracy_milli())
		* (passive.melee_accuracy_factor() if passive != null else 1.0)
		* Afflictions.stat_factor_of(body, Afflictions.Stat.ACCURACY)
	)
	var evasion := (
		float(foe.get("evasion", 0.0))
		* Afflictions.stat_factor_of(target, Afflictions.Stat.ACCURACY)
	)
	var total := accuracy + evasion / facing
	if not (total > 0.0):
		return {
			"amount": 0.0,
			"chance": 0.0,
			"roll": 1.0,
			"accuracy": accuracy,
			"evasion": evasion,
			"facing": facing,
			"pending": pending,
			"resistance": 0.0
		}
	var hit_chance := accuracy / total
	var rolled := weapon.rng.randf()
	if rolled >= hit_chance:
		damage *= (1.0 - rolled) / (1.0 - hit_chance)
	damage *= float(type.melee_strength)
	# The poison's resistance bonus goes inside the max; so do what the target has devoured down to and its afflictions.
	var resistance := maxf(
		0.0,
		(
			float(foe.get("resistance", 1.0)) * DevourGrowth.resistance_factor_of(target)
			+ Poisoning.resistance_bonus_of(target)
			+ Afflictions.resistance_bonus_of(target)
		)
	)
	damage *= weapon.melee_resistance_scale * resistance
	return {
		"amount": damage,
		"chance": hit_chance,
		"roll": rolled,
		"accuracy": accuracy,
		"evasion": evasion,
		"facing": facing,
		"pending": pending,
		"resistance": resistance
	}


## A guardian hits harder, and the passive scales melee by the attacker's health
## (Firefist).
static func attack_factor(weapon: MeleeWeapon) -> float:
	var result := maxf(0.0, weapon.body.attack_factor)
	var own: Health = weapon.weapons.health if weapon.weapons != null else null
	var fury := weapon.passive()
	if fury != null and own != null and own.maximum > 0.0:
		result *= fury.outgoing_melee_factor(own.current / own.maximum)
	return result
