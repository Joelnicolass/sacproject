@tool
class_name CarryErrand
extends Node

## The errand of a carrier doctor: which creature it came for and which site it takes it to. The body is the DoctorBody (it only walks and dies);
## the errand is what makes this doctor a carrier, and the steps (Wait, Approach, Haul, Over) are nodes of `steps`. A ritual doctor has no errand.
## Server only: the clients get the doctor and the creature through their synchronizers. 020e adds Convert and Pump.
## Ref: sacengine SacDocCarry; sacengine `soul.state.among(normal, emerging)`, state.d:15681; freeSoulImpl, state.d:15617

## The carrier reached the site and holds the creature there. The ritual starts from here (RFC-020d).
signal reached_site
## The errand ended: HANDED_OVER = the ritual took over; FAILED = the doctor died.
signal finished(outcome: Outcome)

enum Outcome { HANDED_OVER, FAILED }

@export var body: DoctorBody
@export var steps: FsmMachine

var kind := Ritual.Kind.DESECRATE
var caster_slot := 0
## Desecrate: the caster's live creature. Convert: the corpse the soul sits on, alive from Pump on.
var creature: UnitBody
## Who the creature belongs to when the errand began: if it changes hands the errand is void.
var creature_owner := 0
## Convert: the red soul the doctor came for (null once the creature took it).
var soul: Soul
var captive: Captive
var site: RitualSite
## Haul: the carrier is at the site, holding the creature.
var arrived := false

var _done := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not body.simulates():
		steps.run_physics = false
		steps.run_process = false
		return
	body.landed.connect(_on_landed)
	body.died.connect(_on_died)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Asigná en `body` el doctor (DoctorBody) que cumple el recado.")
	if steps == null:
		warnings.append("Asigná en `steps` la FsmMachine con Wait, Approach, Pump, Haul y Over.")
	return warnings


## Server or solo. Before the doctor drops. `converted_soul` only for Convert.
func configure(errand_kind: Ritual.Kind, slot: int, target: UnitBody, destination: RitualSite, converted_soul: Soul = null) -> void:
	kind = errand_kind
	caster_slot = slot
	creature = target
	creature_owner = target.owner_slot if target != null else 0
	site = destination
	soul = converted_soul


## The creature is still the caster's, alive and free (not held by anyone).
func creature_is_free() -> bool:
	return _is_alive_own() and creature.is_in_group(Captive.UNIT_GROUP) and not creature.is_held()


## Convert: the soul can still be converted by the doctor: it is there, in the open and its corpse is too.
func soul_is_waiting() -> bool:
	if soul == null or not is_instance_valid(soul) or not soul.is_inside_tree():
		return false
	if soul.state != Soul.State.NORMAL and soul.state != Soul.State.EMERGING:
		return false
	var corpse := soul.corpse as UnitBody
	return corpse != null and is_instance_valid(corpse) and corpse.is_inside_tree() and corpse.is_dead() and Captive.of(corpse) != null


## Convert: the soul goes back to being convertible by the caster.
func release_soul() -> void:
	if soul != null and is_instance_valid(soul):
		soul.release_for(caster_slot)


## Derived, never stored: the errand wants the body to walk (Approach or Haul, not there, not over); StuckGuard reads it.
func walks() -> bool:
	return not _done and not arrived and (steps.is_in(&"Approach") or steps.is_in(&"Haul"))


## The doctor holds the creature and it is alive.
func is_carrying() -> bool:
	return _is_alive_own() and captive != null and creature.is_held() and captive.holder == body


func site_standing() -> bool:
	return site != null and is_instance_valid(site) and site.is_standing()


## Haul: stands at the site with the creature and lets the ritual start.
func arrive() -> void:
	if arrived: return
	arrived = true
	body.stop()
	reached_site.emit()


## RFC-020d: the ritual took the creature over. The carrier's work is done.
func hand_over() -> void:
	_finish(Outcome.HANDED_OVER)
	steps.transition(&"Over")


## Lets the creature go where it hangs, for `reason` (Captive.Release).
func release_creature(reason := Captive.Release.LET_GO) -> void:
	if captive != null and is_instance_valid(captive) and (captive.holder == body or captive.body.is_reviving()):
		captive.release(reason)


func _is_alive_own() -> bool:
	return creature != null and is_instance_valid(creature) and creature.is_inside_tree() \
		and not creature.is_dead() and creature.owner_slot == creature_owner


func _on_landed() -> void:
	if steps.current != null and steps.current.name == &"Wait":
		steps.transition(&"Approach")


## The doctor died, in whatever step: the soul it came for is free again (or goes, if the creature already took it) and
## the creature it holds is dropped by one rule (DeathRules.on_carrier_lost, through Captive).
func _on_died(_from_slot: int) -> void:
	if _done:
		return
	if soul != null and is_instance_valid(soul):
		if creature != null and creature.is_reviving():
			soul.queue_free()
			soul = null
		else:
			release_soul()
	release_creature(Captive.Release.CARRIER_DIED)
	_finish(Outcome.FAILED)


func _finish(outcome: Outcome) -> void:
	if _done:
		return
	_done = true
	finished.emit(outcome)
