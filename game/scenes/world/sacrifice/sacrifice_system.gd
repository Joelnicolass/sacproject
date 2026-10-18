@tool
class_name SacrificeSystem
extends Node

## Door of the sacrifice rituals (RFC-020) in the server (or solo): it validates, opens the red vortex
## when the cast starts and, when it ends, spawns the carrier doctor. The Caster does not know the
## rules: a SpellAction (DesecrateAction) asks the system. Clients only hold the spawners, so they
## see the vortex and the doctors. Desecrate (020c, d): the carrier takes an own creature to the closest
## enemy altar and the ritual drains its wizard. Convert (020e): the carrier pumps the corpse of a red
## soul back to life and takes it to the own altar closest to the caster; the ritual there turns it into
## souls for the caster.

## A carrier reached the ritual site holding its creature (CarryErrand.reached_site). 020d starts
## the ritual from this signal.
signal carrier_arrived(errand: CarryErrand)
## A Convert ritual ended: `count` souls go into the purse of the wizard of `slot`, announced right before the
## purse changes. `origin` is where the creature came from (SoulSystem.origin_of: npc / creature), for the
## souls ledger of the bench.
signal souls_converted(slot: int, count: int, origin: StringName)

const GROUP := &"sacrifice_system"
const CARRIER := preload("res://scenes/world/sacrifice/carrier_doctor.tscn")
const RITUAL_DOCTOR := preload("res://scenes/world/sacrifice/ritual_doctor.tscn")
const RITUAL := preload("res://scenes/world/sacrifice/ritual.tscn")
const VORTEX := preload("res://scenes/world/sacrifice/red_vortex.tscn")
const NO_ALTAR := "Sin altar"
const FAR_FROM_ALTAR := "Lejos del altar enemigo"
const BAD_TARGET := SpellAction.BAD_TARGET
## The vortex outlives the cast by this much if nobody frees it.
const VORTEX_GRACE_S := 1.0


## What a running cast keeps between its start and its end (the action holds it).
class Cast extends RefCounted:
	var kind := Ritual.Kind.DESECRATE
	var caster_slot := 0
	## Desecrate: the creature sacrificed. Convert: the corpse the soul sits on.
	var creature: UnitBody
	## Convert: the red soul, reserved for the caster until the doctor is done with it.
	var soul: Soul
	## Where the ritual will be: the enemy altar (Desecrate) or the caster's own (Convert).
	var altar: Altar
	var vortex: RedVortex
	## Where the doctor comes out (under the vortex) and where it lands.
	var exit_point := Vector3.ZERO
	var landing := Vector3.ZERO


## Holds `rules: MatchRules` (HighNoon).
@export var world: Node
## Without it the system takes the world's rules.
@export var rules: MatchRules
@export var doctors_root: Node3D
@export var doctor_spawner: MpSpawner
@export var vortices_root: Node3D
@export var vortex_spawner: MpSpawner
@export var rituals_root: Node3D
@export var ritual_spawner: MpSpawner

## Casts of Desecrate between their start and their end (the casting time, before the carrier doctor drops).
var _desecrations: Array[Cast] = []
var _doctor_serial := 0
var _vortex_serial := 0
var _ritual_serial := 0
## Carriers at their site waiting for it to be free (a second carrier waits, state.d:15780, 15866).
var _waiting: Array[CarryErrand] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if rules == null and world != null:
		rules = world.get("rules") as MatchRules
	doctor_spawner.spawn_function = _make_doctor
	vortex_spawner.spawn_function = _make_vortex
	ritual_spawner.spawn_function = _make_ritual
	set_physics_process(not MpKit.is_networked() or MpKit.is_server())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if doctors_root == null:
		warnings.append("Asigná `doctors_root` (Node3D donde nacen los doctores).")
	if doctor_spawner == null:
		warnings.append("Asigná `doctor_spawner` (MpSpawner de carrier_doctor.tscn).")
	if vortices_root == null:
		warnings.append("Asigná `vortices_root` (Node3D donde nacen los vórtices).")
	if vortex_spawner == null:
		warnings.append("Asigná `vortex_spawner` (MpSpawner de red_vortex.tscn).")
	if rituals_root == null:
		warnings.append("Asigná `rituals_root` (Node3D donde nacen los rituales).")
	if ritual_spawner == null:
		warnings.append("Asigná `ritual_spawner` (MpSpawner de ritual.tscn).")
	if world == null and rules == null:
		warnings.append("Asigná `world` (HighNoon) o `rules` (MatchRules).")
	return warnings


## Server or solo: the Ritual says what a finished Convert gives, before it fills the purse.
func announce_conversion(slot: int, count: int, creature: Node) -> void:
	souls_converted.emit(slot, count, SoulSystem.origin_of(creature))


# --- Questions (any peer: the owner arms the icon with them, the server decides) ---

## The closest standing enemy altar to `from` within `max_range` on the plane, or null
## (sacengine closestEnemyAltar, state.d:28083). A destroyed or collapsing altar is not there.
func closest_enemy_altar(slot: int, from: Vector3, max_range := INF) -> Altar:
	var best: Altar = null
	var best_d := max_range
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		var altar := node as Altar
		if altar == null or not altar.is_standing() or altar.owner_slot <= 0 or altar.owner_slot == slot:
			continue
		var d := Vector2(altar.global_position.x - from.x, altar.global_position.z - from.z).length()
		if d <= best_d:
			best_d = d
			best = altar
	return best


## "" when Desecrate can be armed from `from`, else why not (sacengine mustBeNearEnemyAltar, state.d:29562).
func altar_status(slot: int, from: Vector3) -> String:
	if closest_enemy_altar(slot, from) == null:
		return NO_ALTAR
	if closest_enemy_altar(slot, from, _rules().desecrate_altar_range) == null:
		return FAR_FROM_ALTAR
	return ""


## "" when `picked` can be sacrificed by the wizard of `slot`: one of the caster's own creatures, alive,
## free and able to be taken. Not a wizard, a doctor, an enemy, a corpse or one that is already held.
## `picked` comes from the client: nothing about it is trusted.
func sacrifice_status(slot: int, picked: Node3D) -> String:
	var unit := picked as UnitBody
	if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree():
		return BAD_TARGET
	if not unit.is_in_group(Captive.UNIT_GROUP) or unit.owner_slot != slot or slot <= 0:
		return BAD_TARGET
	if unit.is_dead() or unit.is_summoning() or unit.is_held() or Captive.of(unit) == null:
		return BAD_TARGET
	return ""


## The standing altar of `slot` closest to `from` on the plane, or null: where a Convert takes the creature
## (sacengine closestShrine, state.d:28060-28095: no range, any altar or shrine of the side that is active).
func closest_own_altar(slot: int, from: Vector3) -> Altar:
	var best: Altar = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		var altar := node as Altar
		if altar == null or not altar.is_standing() or altar.owner_slot != slot or slot <= 0:
			continue
		var d := Vector2(altar.global_position.x - from.x, altar.global_position.z - from.z).length()
		if d < best_d:
			best_d = d
			best = altar
	return best


## "" when Convert can be armed from `from`: the wizard needs an own altar standing (sacengine
## mustBeConnectedToConversion, state.d:29563).
func convert_arm_status(slot: int, from: Vector3) -> String:
	return "" if closest_own_altar(slot, from) != null else NO_ALTAR


## "" when `picked` is a soul the wizard of `slot` can convert: red for him, in the open, on the corpse of a
## creature that can be revived and that no doctor of his is already coming for. `picked` comes from the client.
func convert_status(slot: int, picked: Node3D) -> String:
	var soul := picked as Soul
	if soul == null or not is_instance_valid(soul) or not soul.is_inside_tree() or slot <= 0:
		return BAD_TARGET
	if not soul.can_convert_by(slot):
		return BAD_TARGET
	var corpse := soul.corpse as UnitBody
	if corpse == null or not is_instance_valid(corpse) or not corpse.is_inside_tree() or not corpse.is_dead():
		return BAD_TARGET
	if corpse.owner_slot == slot or Captive.of(corpse) == null:
		return BAD_TARGET
	return ""


## Is a Desecrate underway against the altars of `altar_slot`: a wizard casting it, a carrier on its way or a ritual running
## (sacengine desecrationOngoing, shiny.d:3079 over the `sacDocCastings`: the whole thing from the cast to the end).
## RFC-024 024d: the AI reads it to guard its altar, to leave a target alone and to stop claiming creatures.
func desecration_against(altar_slot: int) -> bool:
	return _desecration_matches(altar_slot, 0)


## Is a Desecrate underway cast by the wizard of `caster_slot` (the `ucas` attachment of the wizard, shiny.d:2264).
func desecration_by(caster_slot: int) -> bool:
	return _desecration_matches(0, caster_slot)


func _desecration_matches(altar_slot: int, caster_slot: int) -> bool:
	for cast in _desecrations:
		if cast.altar != null and is_instance_valid(cast.altar) \
				and (altar_slot <= 0 or cast.altar.owner_slot == altar_slot) and (caster_slot <= 0 or cast.caster_slot == caster_slot):
			return true
	for node in get_tree().get_nodes_in_group(DoctorBody.GROUP):
		var errand := node.get_node_or_null("Errand") as CarryErrand
		if errand == null or errand.kind != Ritual.Kind.DESECRATE or errand.site == null or not is_instance_valid(errand.site):
			continue
		if (altar_slot <= 0 or errand.site.owner_slot() == altar_slot) and (caster_slot <= 0 or errand.caster_slot == caster_slot):
			return true
	for node in get_tree().get_nodes_in_group(Ritual.GROUP):
		var ritual := node as Ritual
		if ritual != null and ritual.kind == Ritual.Kind.DESECRATE and ritual.outcome == Ritual.Outcome.RUNNING \
				and (altar_slot <= 0 or ritual.target_slot == altar_slot) and (caster_slot <= 0 or ritual.caster_slot == caster_slot):
			return true
	return false


# --- Cast (server or solo) ---

## The cast of Desecrate starts: the vortex opens near the creature, on the wizard's side. The altar
## is fixed now, as sacengine does with `closestEnemyAltar` when the cast starts.
func begin_cast(wizard: WizardBody, creature: UnitBody, casting_s: float) -> Cast:
	var rule := _rules()
	var cast := Cast.new()
	cast.kind = Ritual.Kind.DESECRATE
	cast.caster_slot = wizard.owner_slot
	cast.creature = creature
	cast.altar = closest_enemy_altar(wizard.owner_slot, wizard.global_position, rule.desecrate_altar_range)
	_open_vortex(cast, creature.global_position, wizard.global_position, casting_s, false)
	_desecrations.append(cast)
	return cast


## The cast of Convert starts: the vortex opens past the soul as seen from the wizard, the soul is reserved
## for him and the altar the creature will be taken to is fixed now (castConvert with `closestShrine`,
## state.d:10181-10196, 9907).
func begin_convert_cast(wizard: WizardBody, soul: Soul, casting_s: float) -> Cast:
	var cast := Cast.new()
	cast.kind = Ritual.Kind.CONVERT
	cast.caster_slot = wizard.owner_slot
	cast.soul = soul
	cast.creature = soul.corpse as UnitBody
	cast.altar = closest_own_altar(wizard.owner_slot, wizard.global_position)
	soul.reserve_for(cast.caster_slot)
	_open_vortex(cast, soul.global_position, wizard.global_position, casting_s, true)
	return cast


## The wizard died or was interrupted: the vortex closes and no doctor comes out
## (sacengine updateSacDocCasting `interrupted`, state.d:15526-15530).
func cancel_cast(cast: Cast) -> void:
	if cast != null:
		_desecrations.erase(cast)
		_free_vortex(cast)
		_release_soul(cast)


## The casting time ended. The vortex closes and the carrier doctor drops. Returns something to tell
## the owner when nothing came out, or "".
func finish_cast(cast: Cast) -> String:
	if cast == null:
		return BAD_TARGET
	_desecrations.erase(cast)
	_free_vortex(cast)
	var problem := _cast_problem(cast)
	if not problem.is_empty():
		_release_soul(cast)
		return problem
	var toward := cast.landing - cast.exit_point
	_doctor_serial += 1
	var data := {
		"name": "Doctor%d" % _doctor_serial,
		"x": cast.exit_point.x, "y": cast.exit_point.y, "z": cast.exit_point.z,
		"yaw": atan2(toward.x, toward.z) if Vector2(toward.x, toward.z).length_squared() > 0.000001 else 0.0,
		"slot": cast.caster_slot,
	}
	var doctor := _spawn_doctor(data)
	var errand := doctor.get_node_or_null("Errand") as CarryErrand if doctor != null else null
	if errand == null:
		if doctor != null:
			doctor.queue_free()
		_release_soul(cast)
		return BAD_TARGET
	errand.configure(cast.kind, cast.caster_slot, cast.creature, cast.altar.site, cast.soul)
	errand.reached_site.connect(_on_reached_site.bind(errand))
	doctor.drop_to(cast.landing)
	return ""


## Why the doctor does not come out when the casting time ends, or "" (state.d:15519-15545).
func _cast_problem(cast: Cast) -> String:
	if cast.altar == null or not is_instance_valid(cast.altar) or not cast.altar.is_standing():
		return NO_ALTAR
	if cast.kind == Ritual.Kind.CONVERT:
		if cast.soul == null or not is_instance_valid(cast.soul) or not cast.soul.is_inside_tree():
			return BAD_TARGET
		if cast.soul.state != Soul.State.NORMAL and cast.soul.state != Soul.State.EMERGING:
			return BAD_TARGET
		return "" if is_instance_valid(cast.creature) else BAD_TARGET
	if not is_instance_valid(cast.creature):
		return BAD_TARGET
	return sacrifice_status(cast.caster_slot, cast.creature)


# --- The ritual (server or solo) ---

## The wizard of that slot in this world, or null.
func wizard_of(slot: int) -> WizardBody:
	for node in get_tree().get_nodes_in_group("wizard"):
		var wizard := node as WizardBody
		if wizard != null and wizard.owner_slot == slot and (world == null or world.is_ancestor_of(wizard)):
			return wizard
	return null


## The carrier holds its creature at the site: the ritual starts if the site is free, else the carrier
## waits and it is tried again every frame. Returns the ritual, or null if it has to wait.
func start_ritual(errand: CarryErrand) -> Ritual:
	var site := errand.site
	if site == null or not errand.is_carrying() or not site.is_standing() or not site.is_free():
		return null
	var rule := _rules()
	var center := site.center()
	var creature := errand.creature
	_ritual_serial += 1
	var ritual := _spawn_ritual({
		"name": "Ritual%d" % _ritual_serial,
		"x": center.x, "y": center.y, "z": center.z,
		"kind": int(errand.kind),
		"caster": errand.caster_slot, "target": site.owner_slot(),
		"creature": str(creature.get_path()),
	})
	if ritual == null:
		return null
	if not site.occupy(ritual):
		ritual.queue_free()
		return null
	var ring: Array[DoctorBody] = []
	for k in 4:
		var at := SacrificeMath.ring_point(center, k, 0.0, rule.ritual_radius, rule.ritual_walk_shrink)
		at.y = _ground_y(at)
		_doctor_serial += 1
		var doctor := _spawn_doctor({
			"name": "Doctor%d" % _doctor_serial,
			"x": at.x, "y": at.y, "z": at.z,
			"yaw": SacrificeMath.yaw_toward(at, center),
			"slot": errand.caster_slot, "ritual": true,
		})
		if doctor != null:
			ring.append(doctor)
	## The carrier hands the creature over and is gone ("the carrier dies"): the ritual moves it now.
	if errand.captive != null:
		errand.captive.hand_to_ritual()
	errand.hand_over()
	errand.body.kill()
	## Convert drains nobody: it has no wizard to name.
	ritual.begin(creature, site, ring, wizard_of(site.owner_slot()) if errand.kind == Ritual.Kind.DESECRATE else null)
	return ritual


# --- Internals ---

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var still: Array[CarryErrand] = []
	for errand in _waiting:
		if not is_instance_valid(errand) or not errand.is_carrying():
			continue
		if start_ritual(errand) == null:
			still.append(errand)
	_waiting = still


func _rules() -> MatchRules:
	return rules if rules != null else MatchRules.new()


func _on_reached_site(errand: CarryErrand) -> void:
	print("sacrificio: el portador de slot %d llegó al altar de slot %d" % [errand.caster_slot, errand.site.owner_slot()])
	carrier_arrived.emit(errand)
	if start_ritual(errand) == null:
		_waiting.append(errand)


func _terrain() -> Node:
	return FallCheck.terrain_of(self)


func _on_ground(point: Vector3) -> bool:
	var terrain := _terrain()
	return terrain == null or bool(terrain.call("is_on_ground", point.x, point.z))


## Land height under the point; without ground data (a bare test world) the point's own height.
func _ground_y(point: Vector3) -> float:
	var terrain := _terrain()
	if terrain == null:
		return point.y
	var y := float(terrain.call("ground_height", point.x, point.z))
	return point.y if is_nan(y) else y


func _spawn_vortex(at: Vector3, life_s: float) -> RedVortex:
	_vortex_serial += 1
	var data := {"name": "Vortex%d" % _vortex_serial, "x": at.x, "y": at.y, "z": at.z, "life": life_s}
	if MpKit.is_networked():
		if not MpKit.is_server():
			return null
		return vortex_spawner.spawn(data) as RedVortex
	var vortex := _make_vortex(data) as RedVortex
	vortices_root.add_child(vortex)
	return vortex


## Opens the vortex of a cast over `target` (state.d:10162-10213): `beyond` hangs it past the target as seen
## from the caster (Convert), else on the caster's side (Desecrate). Fixes where the doctor comes out and lands.
func _open_vortex(cast: Cast, target: Vector3, caster: Vector3, casting_s: float, beyond: bool) -> void:
	var rule := _rules()
	var drop := SacrificeMath.drop_positions(target, caster, rule.doctor_drop_distance, _on_ground, beyond)
	var vortex_ground := _ground_y(drop["vortex"])
	var vortex_point: Vector3 = Vector3(drop["vortex"].x, vortex_ground + rule.doctor_drop_height, drop["vortex"].z)
	## state.d:15489: the doctor comes out under the vortex, never below the ground.
	cast.exit_point = Vector3(vortex_point.x, maxf(vortex_point.y - rule.doctor_exit_depth, vortex_ground), vortex_point.z)
	cast.landing = Vector3(drop["landing"].x, _ground_y(drop["landing"]), drop["landing"].z)
	cast.vortex = _spawn_vortex(vortex_point, casting_s + VORTEX_GRACE_S)


## The soul of a Convert cast that did not get a doctor is free to convert again.
func _release_soul(cast: Cast) -> void:
	if cast.soul != null and is_instance_valid(cast.soul):
		cast.soul.release_for(cast.caster_slot)


func _free_vortex(cast: Cast) -> void:
	if cast.vortex != null and is_instance_valid(cast.vortex):
		cast.vortex.queue_free()
	cast.vortex = null


func _make_vortex(data: Variant) -> Node:
	var info: Dictionary = data
	var vortex := VORTEX.instantiate() as RedVortex
	vortex.name = str(info["name"])
	vortex.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	vortex.max_life_s = float(info.get("life", 0.0))
	return vortex


func _spawn_doctor(data: Dictionary) -> DoctorBody:
	if MpKit.is_networked():
		if not MpKit.is_server():
			return null
		return doctor_spawner.spawn(data) as DoctorBody
	var doctor := _make_doctor(data) as DoctorBody
	doctors_root.add_child(doctor)
	return doctor


func _spawn_ritual(data: Dictionary) -> Ritual:
	if MpKit.is_networked():
		if not MpKit.is_server():
			return null
		return ritual_spawner.spawn(data) as Ritual
	var ritual := _make_ritual(data) as Ritual
	rituals_root.add_child(ritual)
	return ritual


func _make_ritual(data: Variant) -> Node:
	var info: Dictionary = data
	var ritual := RITUAL.instantiate() as Ritual
	ritual.name = str(info["name"])
	ritual.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	ritual.kind = int(info.get("kind", 0)) as Ritual.Kind
	ritual.caster_slot = int(info.get("caster", 0))
	ritual.target_slot = int(info.get("target", 0))
	ritual.creature_path = NodePath(str(info.get("creature", "")))
	ritual.rules = _rules()
	return ritual


func _make_doctor(data: Variant) -> Node:
	var info: Dictionary = data
	var scene := RITUAL_DOCTOR if bool(info.get("ritual", false)) else CARRIER
	var doctor := scene.instantiate() as DoctorBody
	doctor.name = str(info["name"])
	doctor.owner_slot = int(info.get("slot", 0))
	doctor.rules = _rules()
	doctor.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	doctor.rotation.y = float(info.get("yaw", 0.0))
	return doctor
