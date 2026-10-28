@tool
class_name SacrificeSystem
extends Node

## Door of the sacrifice rituals: a SpellAction (DesecrateAction, ConvertAction) and the AI ask here
## and the door passes the question to its children. Desecrate: a carrier doctor takes an own
## creature to the closest enemy altar and the ritual drains the wizard there. Convert: the carrier
## pumps a red soul's corpse back to life and takes it to the own altar, where the ritual turns it
## into souls.
## What it does not do: any logic of its own. SacrificeSpawns builds, SacrificeTargets answers,
## SacrificeCasts runs the cast, RitualStarter starts the ritual.

## A carrier reached the ritual site holding its creature.
signal carrier_arrived(errand: CarryErrand)
## A Convert ritual ended: `count` souls go into the purse of the wizard of `slot`, announced right
## before the purse changes (`origin`: SoulSystem.origin_of).
signal souls_converted(slot: int, count: int, origin: StringName)

const GROUP := &"sacrifice_system"
const NO_ALTAR := Refusal.NO_ALTAR
const FAR_FROM_ALTAR := Refusal.FAR_FROM_ALTAR
const BAD_TARGET := SpellAction.BAD_TARGET


## What a running cast keeps between its start and its end (the action holds it).
class Cast:
	extends RefCounted
	var kind := Ritual.Kind.DESECRATE
	var caster_slot := 0
	## Desecrate: the creature sacrificed. Convert: the corpse the soul sits on.
	var creature: UnitBody
	## Convert: the red soul, reserved for the caster.
	var soul: Soul
	## Where the ritual will be: the enemy altar's site (Desecrate) or the own altar or Shrine
	## (Convert).
	var site: RitualSite
	var vortex: RedVortex
	var exit_point := Vector3.ZERO
	var landing := Vector3.ZERO


## Holds `rules: MatchRules` (MatchWorld).
@export var world: Node
## Without it the system takes the world's rules.
@export var rules: MatchRules
@export var spawns: SacrificeSpawns
@export var targets: SacrificeTargets
@export var casts: SacrificeCasts
@export var starter: RitualStarter

## The doctors' root, for the debug scenes.
var doctors_root: Node3D:
	get:
		return spawns.doctors_root


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if rules == null and world != null:
		rules = world.get("rules") as MatchRules
	set_physics_process(spawns.simulates())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if spawns == null or targets == null or casts == null or starter == null:
		warnings.append(
			"Assign `spawns`, `targets`, `casts` and `starter` (the system's children)."
		)
	if world == null and rules == null:
		warnings.append("Assign `world` (MatchWorld) or `rules` (MatchRules).")
	return warnings


## The carriers waiting for a free site are tried before the children run.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	starter.retry_waiting()


## The rules in use: the exported ones, else the world's, else the defaults.
func active_rules() -> MatchRules:
	return rules if rules != null else MatchRules.new()


## The places of the sacrifice in meters (scene the rules point at).
func facts() -> SacrificeFacts:
	return SacrificeFacts.of_rules(active_rules())


## Server or solo: the Ritual says what a finished Convert gives, before it fills the purse.
func announce_conversion(slot: int, count: int, creature: Node) -> void:
	souls_converted.emit(slot, count, SoulSystem.origin_of(creature))


func closest_enemy_altar(slot: int, from: Vector3, max_range := INF) -> Altar:
	return targets.closest_enemy_altar(slot, from, max_range)


func altar_status(slot: int, from: Vector3) -> String:
	return targets.altar_status(slot, from)


func sacrifice_status(slot: int, picked: Node3D) -> String:
	return targets.sacrifice_status(slot, picked)


func closest_own_site(slot: int, from: Vector3) -> RitualSite:
	return targets.closest_own_site(slot, from)


func convert_arm_status(slot: int, from: Vector3) -> String:
	return targets.convert_arm_status(slot, from)


func convert_status(slot: int, picked: Node3D) -> String:
	return targets.convert_status(slot, picked)


## Is a Desecrate underway against the altars of `altar_slot`: a wizard casting it, a carrier on its
## way or a ritual running.
func desecration_against(altar_slot: int) -> bool:
	return targets.desecration_matches(altar_slot, 0, casts.desecrations())


func desecration_by(caster_slot: int) -> bool:
	return targets.desecration_matches(0, caster_slot, casts.desecrations())


func wizard_of(slot: int) -> WizardBody:
	return targets.wizard_of(slot)


func begin_cast(wizard: WizardBody, creature: UnitBody, casting_s: float) -> Cast:
	return casts.begin_cast(wizard, creature, casting_s)


func begin_convert_cast(wizard: WizardBody, soul: Soul, casting_s: float) -> Cast:
	return casts.begin_convert_cast(wizard, soul, casting_s)


## The wizard died or was interrupted: no doctor comes out.
func cancel_cast(cast: Cast) -> void:
	casts.cancel_cast(cast)


## The casting time ended: the carrier doctor drops. Returns what to tell the owner when nothing
## came out, or "".
func finish_cast(cast: Cast) -> String:
	return casts.finish_cast(cast)
