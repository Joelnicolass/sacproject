@tool
class_name Ritual
extends Node3D

## A sacrifice ritual in progress (sacengine Ritual, state.d:15854-16045): four Sac Doctors around the
## site, the creature hanging over it, rounds of walk / shoot / wait. Desecrate (020d): each round drains
## the wizard whose altar it is; there is no limit of rounds, it goes on until that wizard dies (then his
## altar falls) or until it is cancelled. Cancelled = any of the four doctors dies, the site stops
## standing or the creature is lost: the doctors die, the creature is let go, alive and its owner's, and
## the site is free again. Convert (020e) is another `kind` of this same node: it drains nobody, lasts
## int(max health of the creature / convert_health_per_round) + 1 rounds and then adds the creature's
## souls to the caster's purse (sacengine state.d:16020-16030).
## The server (or solo) simulates; the Phases machine runs the phases and the other children are the
## parts you can take away: Push (pushes everything out of the radius), Fx (what is seen).
## Replicated: phase, round_index and outcome, so every peer can show the ritual and the notices.
## Numbers: MatchRules, group «Sacrificios» (020d).

## The phase changed (every peer).
signal phase_changed(phase: Phase)
## A round of shooting ended. Server only (XP would listen here, RFC-020 section 13).
signal round_tortured(round_index: int)
## The ritual ended on this peer: completed (the wizard died) or cancelled.
signal ended(completed: bool)

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
		phase = value
		phase_changed.emit(phase)
## Starts at 0; every round adds one (Wait -> Walk).
@export var round_index := 0
@export var outcome := Outcome.RUNNING:
	set(value):
		if outcome == value:
			return
		outcome = value
		if outcome != Outcome.RUNNING:
			ended.emit(outcome == Outcome.COMPLETED)
@export var rules: MatchRules

@export_group("Sockets")
@export var phases: FsmMachine
@export var push: RitualPush
@export var fx: RitualFx

## Server only.
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

var _target_down := false
var _linger_left := 0.0
var _match: MatchState


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if MpKit.is_networked() and not MpKit.is_server():
		phases.run_physics = false
		phases.run_process = false
		set_physics_process(false)
		return
	tree_exiting.connect(_on_leaving)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if phases == null:
		warnings.append("Asigná en `phases` la FsmMachine con Off, Setup, Walk, Shoot, Wait y Ended.")
	if push == null:
		warnings.append("Asigná en `push` el RitualPush (sin él nada se aparta del altar).")
	if fx == null:
		warnings.append("Asigná en `fx` el RitualFx (sin él el ritual no se ve).")
	if rules == null:
		warnings.append("Asigná `rules` (MatchRules) o lo hace SacrificeSystem al crearlo.")
	return warnings


# --- Server: begin and end ---

## Server or solo. The site is already taken by this ritual and the doctors stand on the ring.
func begin(unit: UnitBody, ritual_site: RitualSite, ring_doctors: Array[DoctorBody], wizard: WizardBody) -> void:
	creature = unit
	captive = Captive.of(unit)
	site = ritual_site
	doctors = ring_doctors
	target_wizard = wizard
	souls = int(unit.type.souls) if unit.type else 0
	start_point = unit.global_position
	for doctor in doctors:
		doctor.died.connect(_on_doctor_died)
	var ghost := _ghost_of(wizard)
	if ghost != null:
		ghost.add_desecration()
	print("ritual %s: empieza sobre el altar del slot %d (lanza el slot %d, %d almas)" % [Kind.keys()[kind].to_lower(), target_slot, caster_slot, souls])
	phases.transition(&"Setup")


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


## End of a shooting round (Shoot): the wizard is dead and the ritual is complete, or another round.
func finish_round() -> void:
	round_tortured.emit(round_index)
	if is_last_round():
		complete()
	else:
		phases.transition(&"Wait")


## The round that just ended was the last one (state.d:16020-16042). Desecrate: the wizard is dead or
## not there. Convert: `round == int(maxHealth / 550)`, rounds count from 0.
func is_last_round() -> bool:
	if kind == Kind.CONVERT:
		if not is_instance_valid(creature):
			return true
		var health := creature.get_node_or_null("Health") as Health
		var per_round := rules.convert_health_per_round if rules else 550.0
		return round_index >= SacrificeMath.convert_rounds(health.maximum if health else 0.0, per_round) - 1
	return target_is_gone()


## Drain of the wizard: `fraction` of what a round takes (Shoot calls it with the time that passed).
func drain(fraction: float) -> void:
	if kind != Kind.DESECRATE or target_is_gone() or fraction <= 0.0 or rules == null:
		return
	var health := target_wizard.health as Health
	health.damage(SacrificeMath.desecrate_health(souls, rules.desecrate_health_per_round) * fraction, caster_slot)
	var mana := target_wizard.mana
	var wanted := SacrificeMath.desecrate_mana(souls, rules.desecrate_mana_per_round) * fraction
	mana.set("current", maxf(float(mana.get("current")) - wanted, 0.0))


## Desecrate: the wizard died under the ritual, the creature disintegrates and its souls go back to the
## caster; the altar is already falling (state.d:16036-16041). Convert: the last round ended, the
## creature disintegrates and its souls are the caster's (`gib(state, caster)`, state.d:8341-8350).
func complete() -> void:
	if outcome != Outcome.RUNNING:
		return
	if kind == Kind.DESECRATE:
		_start_collapse()
	outcome = Outcome.COMPLETED
	if is_instance_valid(creature):
		var at := creature.global_position
		FxBus.broadcast("blood", at)
		var caster := _wizard_of(caster_slot)
		var purse := caster.get_node_or_null("SoulPurse") if caster else null
		if purse != null:
			if kind == Kind.CONVERT:
				var system := get_tree().get_first_node_in_group(SacrificeSystem.GROUP) as SacrificeSystem
				if system != null:
					system.announce_conversion(caster_slot, souls, creature)
			purse.call("add", souls)
		creature.queue_free()
	if kind == Kind.CONVERT:
		print("ritual convert: completo, %d almas para el slot %d" % [souls, caster_slot])
	else:
		print("ritual: completo, el mago del slot %d murio" % target_slot)
	_wind_down()


## Cancelled: doctors die, the creature falls alive and free, the wizard is not under ritual any more
## (sacengine stopRitual, state.d:15817-15833).
func abort() -> void:
	if outcome != Outcome.RUNNING:
		return
	outcome = Outcome.ABORTED
	if is_instance_valid(creature) and captive != null and is_instance_valid(captive):
		## It falls where it was when the ritual began (the original throws it toward that point).
		creature.global_position = Vector3(start_point.x, creature.global_position.y, start_point.z)
		captive.release()
	var ghost := _ghost_of(target_wizard)
	if ghost != null:
		ghost.remove_desecration()
	print("ritual: cancelado")
	_wind_down()


# --- Server: every frame ---

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
	_raise_creature(delta)
	_watch()


## The creature goes up to `ritual_creature_height` over the site, slowing in so it is there when the
## setup ends (state.d:15928-15930); after that it is held there.
func _raise_creature(delta: float) -> void:
	if not is_instance_valid(creature) or rules == null:
		return
	var target := center() + Vector3.UP * rules.ritual_creature_height
	var left := maxf(rules.ritual_setup_s - elapsed, delta)
	creature.global_position = creature.global_position.lerp(target, clampf(delta / left, 0.0, 1.0))
	creature.velocity = Vector3.ZERO


## Anything that cancels the ritual (state.d:15921-15925).
func _watch() -> void:
	for doctor in doctors:
		if not is_instance_valid(doctor) or doctor.is_dead():
			abort()
			return
	if not is_instance_valid(creature) or captive == null or not captive.is_held():
		abort()
		return
	if kind == Kind.DESECRATE and target_wizard != null and target_is_gone():
		_start_collapse()
	if not _target_down and not site.is_standing():
		abort()


## The wizard's body is dead: his altar starts to fall, once (state.d:15901-15903).
func _start_collapse() -> void:
	if _target_down:
		return
	_target_down = true
	var match_state := _match_state()
	if match_state != null:
		match_state.begin_altar_collapse(target_slot, caster_slot)


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


func _ghost_of(wizard: WizardBody) -> GhostForm:
	return wizard.ghost as GhostForm if wizard != null and is_instance_valid(wizard) else null


func _wizard_of(slot: int) -> WizardBody:
	for node in get_tree().get_nodes_in_group("wizard"):
		var wizard := node as WizardBody
		if wizard != null and wizard.owner_slot == slot:
			return wizard
	return null


func _match_state() -> MatchState:
	if _match == null or not is_instance_valid(_match):
		_match = get_tree().get_first_node_in_group(&"match_state") as MatchState
	return _match
