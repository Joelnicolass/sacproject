@tool
class_name Captive
extends Node

## A creature taken by a Sac Doctor (RFC-020c). While it is held it is not a creature of the match:
## out of the group «unit» (so it cannot be selected, ordered, targeted or separated from), without
## collision, hanging behind the doctor. The ring around it is `CaptiveRing`. Let go, it is the same creature again, alive and with its owner.
## `UnitBody.mode = HELD` is what every peer sees (it is replicated); this node reacts to it. Only the
## server (or solo) calls take()/release() and moves the body. Remove the child and the creature
## cannot be taken: the Desecrate cast answers «Blanco inválido».
## RFC-020e: a Convert doctor also revives a corpse with it (revive(), mode REVIVING: stood up, still
## taken, nobody's target) and, if the doctor dies then, release(CARRIER_DIED) kills it again.
## Numbers: SacrificeFacts.carry_up_m / carry_back_m (the Carry/Hang marker of the places scene), rules.carry_speed_factor (sacengine state.d:15759-15766).
## The creature does not use move_and_slide: like sacengine it follows a point without colliding.

## The doctor took it.
signal taken(holder: DoctorBody)
## Let go (by the doctor or because the doctor is gone).
signal freed
## A Convert doctor brought the corpse back to life; it is REVIVING until the doctor takes it.
signal revived

## Why a creature is let go: the doctor chose to (or the ritual ended), or the doctor died holding it.
enum Release { LET_GO, CARRIER_DIED }

const HELD_GROUP := &"captive"
const UNIT_GROUP := &"unit"
## unit_orders.gd has no class_name (other scripts preload it).
const _ORDERS := preload("res://scenes/units/unit_orders.gd")

@export var body: UnitBody
## The creature's own Health and Orders (it is emptied of orders when taken, its health is set when revived).
@export var health: Health
@export var orders: _ORDERS

var holder: DoctorBody
var _layer := 0
var _applied := false


## The Captive child of a creature, or null.
static func of(unit: Node) -> Captive:
	return unit.get_node_or_null("Captive") as Captive if unit != null else null


func _ready() -> void:
	if Engine.is_editor_hint() or body == null:
		return
	body.taken_changed.connect(_apply)
	_apply(body.is_taken())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Asigná en `body` la unidad (UnitBody) que puede ser tomada.")
	return warnings


func is_held() -> bool:
	return body != null and body.mode == UnitBody.Mode.HELD


## Server or solo. The doctor picks the creature up. False if it cannot be taken (dead, summoning,
## already held, no holder).
func take(by: DoctorBody) -> bool:
	if body == null or by == null or not is_instance_valid(by) or by.is_dead():
		return false
	if body.is_dead() or body.is_summoning() or is_held():
		return false
	if not body.is_reviving():
		body.halt()
	if orders != null:
		orders.clear()
	holder = by
	by.carried = body.get_path()
	body.mode = UnitBody.Mode.HELD
	body.velocity = Vector3.ZERO
	taken.emit(by)
	return true


## Server or solo (RFC-020d). The ritual takes the creature over: no doctor carries it any more (and
## the doctor's rope is gone), the ritual moves it. It stays held; release() lets it go as always.
func hand_to_ritual() -> void:
	if not is_held():
		return
	if is_instance_valid(holder):
		holder.carried = NodePath()
	holder = null


## Server or solo. Lets the creature go where it is. LET_GO: it falls to the ground, alive and with its owner, and
## answers orders again. CARRIER_DIED: DeathRules says if it lands alive or dies in the air and falls as a corpse.
func release(reason := Release.LET_GO) -> void:
	if not is_held() and not (reason == Release.CARRIER_DIED and body != null and body.is_reviving()):
		holder = null
		return
	var kind := DeathRules.Carried.REVIVING if body.is_reviving() else DeathRules.Carried.HELD
	var outcome := DeathRules.Outcome.LAND_ALIVE
	if reason == Release.CARRIER_DIED:
		outcome = DeathRules.on_carrier_lost(kind, not body.is_dead(), _dies_when_dropped())
	if is_instance_valid(holder):
		holder.carried = NodePath()
	holder = null
	body.velocity = Vector3.ZERO
	if outcome == DeathRules.Outcome.DROP_DEAD:
		_kill()
	else:
		body.mode = UnitBody.Mode.IDLE
	freed.emit()


## Server or solo (RFC-020e). A Convert doctor starts to pump the corpse: it stands up with
## min(max(min_health, fraction * max health), max health) (convertRevive, state.d:8679) and is not
## a target, nobody's creature and without collision until the doctor takes it (take()) or it dies again.
## False if it is not a corpse.
func revive(min_health: float, fraction: float) -> bool:
	if body == null or not body.is_dead():
		return false
	if health == null:
		return false
	if orders != null:
		orders.clear()
	health.current = SacrificeMath.revive_health(health.maximum, min_health, fraction)
	body.velocity = Vector3.ZERO
	body.mode = UnitBody.Mode.REVIVING
	revived.emit()
	return true


## Server or solo (RFC-030 030p-b). The fast revival ends (FastRevive): REVIVING → IDLE, still, alive and with its owner.
## `taken_changed(false)` gives back the unit layer and the group «unit». False if it was not REVIVING.
func finish_revive() -> bool:
	if body == null or not body.is_reviving():
		return false
	body.velocity = Vector3.ZERO
	body.mode = UnitBody.Mode.IDLE
	return true


## The creature dies where it hangs (a corpse that falls to the floor and leaves its soul there).
func _kill() -> void:
	if health == null:
		return
	health.current = 0.0
	health.died.emit(0)


## The match rule: does a dropped creature die? The doctor's rules win, then the body's; without any, yes.
func _dies_when_dropped() -> bool:
	var rules: MatchRules = holder.rules if is_instance_valid(holder) and holder.rules else body.rules
	return rules.carried_dies_when_dropped if rules else true


## Where the creature hangs for a doctor at `at` facing `facing_flat` (a unit vector on the plane).
static func hang_point(at: Vector3, facing_flat: Vector3, height: float, behind: float) -> Vector3:
	return at - facing_flat * behind + Vector3.UP * height


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or body == null or holder == null:
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	if not is_held():
		holder = null
		return
	if not is_instance_valid(holder) or holder.is_dead():
		release(Release.CARRIER_DIED)
		return
	var rules := holder.rules
	var facts := SacrificeFacts.of_rules(rules)
	var want := hang_point(holder.global_position, holder.facing_flat(), facts.carry_up_m, facts.carry_back_m)
	var gap := want - body.global_position
	var distance := gap.length()
	if distance <= 0.75:
		return
	## sacengine only steps while farther than 0.75 m, at 1.1 times the doctor's ground speed.
	var step := (rules.carry_speed_factor if rules else 1.1) * holder.pace() * delta
	body.global_position = want if distance < step else body.global_position + gap / distance * step


func _apply(held: bool) -> void:
	if body == null or held == _applied:
		return
	_applied = held
	if not held and body.is_dead():
		## It died again while a doctor pumped it: Corpse.lay_down already made it a corpse.
		body.remove_from_group(HELD_GROUP)
		return
	if held:
		_layer = body.collision_layer
		body.collision_layer = 0
		body.remove_from_group(UNIT_GROUP)
		body.add_to_group(HELD_GROUP)
	else:
		body.collision_layer = _layer if _layer != 0 else body.unit_layer
		body.remove_from_group(HELD_GROUP)
		body.add_to_group(UNIT_GROUP)

