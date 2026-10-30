class_name SacrificeCasts
extends Node

## The life of a Desecrate or Convert cast, server or solo, from its start to its end: the red
## vortex opens near the creature when the cast starts and, when the casting time ends, closes and
## the carrier doctor drops (or nobody comes if the cast was interrupted or the altar fell). The
## Caster does not know the rules: a SpellAction asks the system, which asks this.
## What it does not do: start the ritual (RitualStarter does) or answer the questions
## (SacrificeTargets does).

const BAD_TARGET := SpellAction.BAD_TARGET
const NO_ALTAR := Refusal.NO_ALTAR
## The vortex outlives the cast by this much if nobody frees it.
const VORTEX_GRACE_S := 1.0

@export var system: SacrificeSystem
@export var spawns: SacrificeSpawns
@export var targets: SacrificeTargets
@export var starter: RitualStarter

## Casts of Desecrate between their start and their end (the casting time, before the carrier doctor
## drops).
var _desecrations: Array[SacrificeSystem.Cast] = []


## The Desecrate casts in their casting time, for SacrificeTargets.desecration_matches.
func desecrations() -> Array[SacrificeSystem.Cast]:
	return _desecrations


## The cast of Desecrate starts: the vortex opens near the creature, on the wizard's side. The altar
## is fixed now.
func begin_cast(wizard: WizardBody, creature: UnitBody, casting_s: float) -> SacrificeSystem.Cast:
	var cast := SacrificeSystem.Cast.new()
	cast.kind = Ritual.Kind.DESECRATE
	cast.caster_slot = wizard.owner_slot
	cast.creature = creature
	var altar := targets.closest_enemy_altar(
		wizard.owner_slot, wizard.global_position, system.active_rules().desecrate_altar_range
	)
	cast.site = altar.site if altar != null else null
	_open_vortex(cast, creature.global_position, wizard.global_position, casting_s, false)
	_desecrations.append(cast)
	return cast


## The cast of Convert starts: the vortex opens past the soul as seen from the wizard, the soul is
## reserved for him and the altar the creature will be taken to is fixed now.
func begin_convert_cast(wizard: WizardBody, soul: Soul, casting_s: float) -> SacrificeSystem.Cast:
	var cast := SacrificeSystem.Cast.new()
	cast.kind = Ritual.Kind.CONVERT
	cast.caster_slot = wizard.owner_slot
	cast.soul = soul
	cast.creature = soul.corpse as UnitBody
	cast.site = targets.closest_own_site(wizard.owner_slot, wizard.global_position)
	soul.reserve_for(cast.caster_slot)
	_open_vortex(cast, soul.global_position, wizard.global_position, casting_s, true)
	return cast


## The wizard died or was interrupted: the vortex closes and no doctor comes out.
func cancel_cast(cast: SacrificeSystem.Cast) -> void:
	if cast != null:
		_desecrations.erase(cast)
		_free_vortex(cast)
		_release_soul(cast)


## The casting time ended. The vortex closes and the carrier doctor drops. Returns something to tell
## the owner when nothing came out, or "".
func finish_cast(cast: SacrificeSystem.Cast) -> String:
	if cast == null:
		return BAD_TARGET
	_desecrations.erase(cast)
	_free_vortex(cast)
	var problem := _cast_problem(cast)
	if not problem.is_empty():
		_release_soul(cast)
		return problem
	var toward := cast.landing - cast.exit_point
	var data := {
		"name": spawns.next_doctor_name(),
		"x": cast.exit_point.x,
		"y": cast.exit_point.y,
		"z": cast.exit_point.z,
		"yaw":
		(
			atan2(toward.x, toward.z)
			if Vector2(toward.x, toward.z).length_squared() > 0.000001
			else 0.0
		),
		"slot": cast.caster_slot,
	}
	var doctor := spawns.spawn_doctor(data)
	var errand := doctor.get_node_or_null("Errand") as CarryErrand if doctor != null else null
	if errand == null:
		if doctor != null:
			doctor.queue_free()
		_release_soul(cast)
		return BAD_TARGET
	doctor.errand = errand  # The doctor holds its errand.
	errand.configure(cast.kind, cast.caster_slot, cast.creature, cast.site, cast.soul)
	errand.reached_site.connect(starter.on_reached.bind(errand))
	doctor.drop_to(cast.landing)
	return ""


## Why the doctor does not come out when the casting time ends, or "".
func _cast_problem(cast: SacrificeSystem.Cast) -> String:
	if cast.site == null or not is_instance_valid(cast.site) or not cast.site.is_standing():
		return NO_ALTAR
	if cast.kind == Ritual.Kind.CONVERT:
		if cast.soul == null or not is_instance_valid(cast.soul) or not cast.soul.is_inside_tree():
			return BAD_TARGET
		if cast.soul.state != Soul.State.NORMAL and cast.soul.state != Soul.State.EMERGING:
			return BAD_TARGET
		return "" if is_instance_valid(cast.creature) else BAD_TARGET
	if not is_instance_valid(cast.creature):
		return BAD_TARGET
	return targets.sacrifice_status(cast.caster_slot, cast.creature)


func _on_ground(point: Vector3) -> bool:
	return SacrificeGround.is_on(self, point)


## Opens the vortex of a cast over `target`: `beyond` hangs it past the target as seen from the
## caster (Convert), else on the caster's side (Desecrate). Fixes where the doctor comes out and
## lands. The doctor never comes out below the ground.
func _open_vortex(
	cast: SacrificeSystem.Cast, target: Vector3, caster: Vector3, casting_s: float, beyond: bool
) -> void:
	var facts := system.facts()
	var drop := SacrificeMath.drop_positions(target, caster, facts.drop_out_m, _on_ground, beyond)
	var vortex_ground := SacrificeGround.height(self, drop["vortex"])
	var vortex_point: Vector3 = Vector3(
		drop["vortex"].x, vortex_ground + facts.drop_up_m, drop["vortex"].z
	)
	cast.exit_point = Vector3(
		vortex_point.x, maxf(vortex_point.y - facts.exit_down_m, vortex_ground), vortex_point.z
	)
	cast.landing = Vector3(
		drop["landing"].x, SacrificeGround.height(self, drop["landing"]), drop["landing"].z
	)
	cast.vortex = spawns.spawn_vortex(vortex_point, casting_s + VORTEX_GRACE_S)


## The soul of a Convert cast that did not get a doctor is free to convert again.
func _release_soul(cast: SacrificeSystem.Cast) -> void:
	if cast.soul != null and is_instance_valid(cast.soul):
		cast.soul.release_for(cast.caster_slot)


func _free_vortex(cast: SacrificeSystem.Cast) -> void:
	if cast.vortex != null and is_instance_valid(cast.vortex):
		cast.vortex.queue_free()
	cast.vortex = null
