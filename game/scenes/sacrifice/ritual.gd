@tool
class_name Ritual
extends Node3D

## A sacrifice ritual in progress: four Sac Doctors on a ring around the site, the creature hanging over it, rounds of walk /
## shoot / wait. Desecrate and Convert are the same node with another `RitualType` (`types`, picked by `kind`): no branch here.
## Cancelled (a doctor dies, the site falls, the creature is lost): the doctors die, the creature is let go alive and its owner's.
## The server (or solo) simulates: `Phases` runs the phases; each tick `Lift` and then `Watch` step, in that order. `Drain` takes
## the wizard's life (Shoot), `Payoff` pays the souls at the end, `Push` and `Fx` are the barrier and what is seen. Take a part
## out of ritual.tscn and that thing stops happening. Replicated: phase, round_index and outcome. Numbers: MatchRules.
## Every peer tells its start and its end game-wide (Events.ritual_started / ritual_ended).

signal phase_changed(phase: Phase)  ## every peer
signal round_tortured(round_index: int)  ## server only
signal ended(completed: bool)  ## every peer: completed or cancelled

const GROUP := &"ritual"

enum Kind { DESECRATE, CONVERT }
enum Phase { OFF, SETUP, WALK, SHOOT, WAIT, ENDED }
enum Outcome { RUNNING, COMPLETED, ABORTED }

@export var kind := Kind.DESECRATE
## Slot of the wizard that cast it, and of the one whose altar it is.
@export var caster_slot := 0
@export var target_slot := 0
## Absolute path of the creature over the site (it is how a client finds it).
@export var creature_path := NodePath()
@export var phase := Phase.OFF:
	set(value):
		if phase == value:
			return
		var began := phase == Phase.OFF and outcome == Outcome.RUNNING
		phase = value
		phase_changed.emit(phase)
		if began and is_inside_tree():
			Events.ritual_started.emit(self)
## Starts at 0; every round adds one (Wait -> Walk).
@export var round_index := 0
@export var outcome := Outcome.RUNNING:
	set(value):
		if outcome == value:
			return
		var was_running := is_running()
		outcome = value
		if outcome != Outcome.RUNNING:
			ended.emit(outcome == Outcome.COMPLETED)
			if was_running and is_inside_tree():
				Events.ritual_ended.emit(self, outcome == Outcome.COMPLETED)
@export var rules: MatchRules
## One per class of ritual (data/sacrifice/*.tres); `type()` picks the one of `kind`.
@export var types: Array[RitualType]

@export_group("Sockets")
@export var phases: FsmMachine
@export var push: RitualPush
@export var fx: RitualFx

@export_group("Parts")
@export var lift: RitualLift
@export var watch: RitualWatch
@export var drain: RitualDrain
@export var payoff: RitualPayoff

## Server only.
var system: SacrificeSystem
var site: RitualSite
var creature: UnitBody
var captive: Captive
var doctors: Array[DoctorBody] = []
var target_wizard: WizardBody
var souls := 0
## Seconds since it began.
var elapsed := 0.0
## Where the creature was when the ritual began: where it falls if the ritual is cancelled.
var start_point := Vector3.ZERO

var _linger_left := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	# A client that receives a ritual already running (its phase came with the spawn) tells it now.
	if is_running():
		Events.ritual_started.emit(self)
	if not simulates():
		phases.run_physics = false
		phases.run_process = false
		set_physics_process(false)
		return
	tree_exiting.connect(_on_leaving)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if phases == null:
		(
			warnings
			. append(
				"Assign to `phases` the FsmMachine with Setup, Walk, Shoot, Wait and Ended (autostart off: begin() starts it)."
			)
		)
	if types.is_empty():
		(
			warnings
			. append(
				"Assign to `types` one RitualType per kind (data/sacrifice/desecrate_ritual.tres, convert_ritual.tres)."
			)
		)
	if rules == null:
		warnings.append(
			"Assign `rules` (MatchRules), or SacrificeSystem does it when it creates it."
		)
	return warnings


## The class of this ritual (inert without a type for its `kind`).
func type() -> RitualType:
	for entry in types:
		if entry != null and entry.kind == kind:
			return entry
	return RitualType.inert()


## This peer runs the ritual: the server, or a solo game.
func simulates() -> bool:
	return is_multiplayer_authority()


## Server or solo. The site is already taken by this ritual and the doctors stand on the ring.
func begin(
	unit: UnitBody, ritual_site: RitualSite, ring_doctors: Array[DoctorBody], wizard: WizardBody
) -> void:
	creature = unit
	captive = Captive.of(unit)
	site = ritual_site
	doctors = ring_doctors
	target_wizard = wizard
	souls = int(unit.type.souls) if unit.type else 0
	start_point = unit.global_position
	for doctor in doctors:
		doctor.died.connect(_on_doctor_died)
	if drain != null:
		drain.mark_target(true)
	if DebugLog.on(&"ritual"):
		print(
			(
				"ritual %s: starts on the altar of slot %d (cast by slot %d, %d souls)"
				% [Kind.keys()[kind].to_lower(), target_slot, caster_slot, souls]
			)
		)
	phases.start()  # autostart is off: the phases begin here, in their initial_state (Setup)


func is_running() -> bool:
	return outcome == Outcome.RUNNING and phase != Phase.OFF


## The center of the site the ritual is held on (where the node stands).
func center() -> Vector3:
	return global_position


## Server. A doctor of this ritual or its creature: the push does not touch them.
func is_part(body: Node) -> bool:
	return body == creature or (body is DoctorBody and doctors.has(body))


## The wizard whose altar it is cannot take more: dead, or not there at all.
func target_is_gone() -> bool:
	if target_wizard == null or not is_instance_valid(target_wizard):
		return true
	var health := target_wizard.health as Health
	return health == null or health.is_dead()


## End of a shooting round (Shoot): this was the last one and the ritual is complete, or another round.
func finish_round() -> void:
	round_tortured.emit(round_index)
	if type().is_last_round(self):
		complete()
	else:
		phases.transition(&"Wait")


## The last round ended: the altar of a drained wizard falls, Payoff pays, the doctors let go.
func complete() -> void:
	if outcome != Outcome.RUNNING:
		return
	if drain != null and type().collapses_target_altar:
		drain.collapse_altar()
	outcome = Outcome.COMPLETED
	if payoff != null:
		payoff.pay()
	_wind_down()


## Cancelled: doctors die, the creature falls alive and free, the wizard is not under ritual any more.
func abort() -> void:
	if outcome != Outcome.RUNNING:
		return
	outcome = Outcome.ABORTED
	if is_instance_valid(creature) and captive != null and is_instance_valid(captive):
		# It falls where it was when the ritual began.
		creature.global_position = Vector3(start_point.x, creature.global_position.y, start_point.z)
		captive.release()
	if drain != null:
		drain.mark_target(false)
	if DebugLog.on(&"ritual"):
		print("ritual: cancelado")
	_wind_down()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if outcome != Outcome.RUNNING:
		_linger_left -= delta
		if _linger_left <= 0.0:
			queue_free()
		return
	if phase == Phase.OFF:
		return
	elapsed += delta
	if lift != null:
		lift.step(delta)
	if watch != null:
		watch.step()


func _wind_down() -> void:
	for doctor in doctors:
		if is_instance_valid(doctor) and not doctor.is_dead():
			doctor.carried = NodePath()
			doctor.kill(0)
	doctors.clear()
	if site != null and is_instance_valid(site) and site.occupant == self:
		site.release()
	phases.transition(&"Ended")
	phase = Phase.ENDED
	_linger_left = rules.ritual_linger_s if rules else 1.5


func _on_doctor_died(_from_slot: int) -> void:
	if outcome == Outcome.RUNNING:
		abort()


func _on_leaving() -> void:
	if site != null and is_instance_valid(site) and site.occupant == self:
		site.release()
