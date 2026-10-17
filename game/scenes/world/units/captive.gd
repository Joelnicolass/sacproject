@tool
class_name Captive
extends Node

## A creature taken by a Sac Doctor (RFC-020c). While it is held it is not a creature of the match:
## out of the group «unit» (so it cannot be selected, ordered, targeted or separated from), without
## collision, hanging behind the doctor. Let go, it is the same creature again, alive and with its owner.
## `UnitBody.mode = HELD` is what every peer sees (it is replicated); this node reacts to it. Only the
## server (or solo) calls take()/release() and moves the body. Remove the child and the creature
## cannot be taken: the Desecrate cast answers «Blanco inválido».
## RFC-020e: a Convert doctor also revives a corpse with it (revive(), mode REVIVING: stood up, still
## taken, nobody's target) and, if the doctor dies then, kills it again (die_again()).
## Numbers: rules.carry_height / carry_distance / carry_speed_factor (sacengine state.d:15759-15766).
## The creature does not use move_and_slide: like sacengine it follows a point without colliding.

## The doctor took it.
signal taken(holder: DoctorBody)
## Let go (by the doctor or because the doctor is gone).
signal freed
## A Convert doctor brought the corpse back to life; it is REVIVING until the doctor takes it.
signal revived

const HELD_GROUP := &"captive"
const UNIT_GROUP := &"unit"

@export var body: UnitBody
## Ring drawn around the creature while it is held (scenes/fx/portal_disc.tscn, blue). Local
## presentation on every peer; empty = no ring. sacengine renderer.d:1638-1677.
@export var portal_scene: PackedScene
## sacengine: ring radii = 0.65 * (1.1, 0.9) * the diagonal of the creature's box (renderer.d:1639-1644).
@export var portal_scale := Vector2(1.1, 0.9) * 0.65

var holder: DoctorBody
## The ring while it is held or closing. Null on the dedicated server.
var portal: PortalDisc

var _layer := 0
var _applied := false


## The Captive child of a creature, or null.
static func of(unit: Node) -> Captive:
	return unit.get_node_or_null("Captive") as Captive if unit != null else null


func _ready() -> void:
	if Engine.is_editor_hint() or body == null:
		return
	body.taken_changed.connect(_apply)
	body.held_changed.connect(_apply_ring)
	_apply(body.is_taken())
	_apply_ring(body.is_held())


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
	## unit_orders.gd has no class_name: it is existing code, called by its name.
	var orders := body.get_node_or_null("Orders")
	if orders:
		orders.call("clear")
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


## Server or solo. Lets the creature go where it is: it falls to the ground, alive and with its owner,
## and answers orders again.
func release() -> void:
	if not is_held():
		holder = null
		return
	if is_instance_valid(holder):
		holder.carried = NodePath()
	holder = null
	body.velocity = Vector3.ZERO
	body.mode = UnitBody.Mode.IDLE
	freed.emit()


## Server or solo (RFC-020e). A Convert doctor starts to pump the corpse: it stands up with
## min(max(min_health, fraction * max health), max health) (convertRevive, state.d:8679) and is not
## a target, nobody's creature and without collision until the doctor takes it (take()) or it dies again.
## False if it is not a corpse.
func revive(min_health: float, fraction: float) -> bool:
	if body == null or not body.is_dead():
		return false
	var health := body.get_node_or_null("Health") as Health
	if health == null:
		return false
	var orders := body.get_node_or_null("Orders")
	if orders:
		orders.call("clear")
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


## Server or solo. The Convert doctor died while it pumped: the creature dies again (freeCreature on a
## convertReviving creature kills it, state.d:10145-10147) and leaves its soul, on its own side.
func die_again() -> void:
	if body == null or not body.is_reviving():
		return
	var health := body.get_node_or_null("Health") as Health
	if health == null:
		return
	health.current = 0.0
	health.died.emit(0)


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
		release()
		return
	var rules := holder.rules
	var want := hang_point(
		holder.global_position, holder.facing_flat(),
		rules.carry_height if rules else 3.5, rules.carry_distance if rules else 2.7)
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


## The ring is only drawn while the doctor carries the creature (HELD), not while it pumps it.
func _apply_ring(held: bool) -> void:
	if held:
		_open_portal()
	elif portal != null and is_instance_valid(portal):
		portal.close()


## Center of the creature's box and the ring around it. Local presentation: not on the dedicated server.
func _open_portal() -> void:
	if portal_scene == null or not BodyCatalog.loads_meshes():
		return
	if portal == null or not is_instance_valid(portal):
		portal = portal_scene.instantiate() as PortalDisc
		if portal == null:
			return
		portal.openness = 0.0
		body.add_child(portal)
	var info := BodyCatalog.info(body.model)
	var height := float(info.get("height", 1.5))
	var width := 2.0 * float(info.get("radius", 0.5))
	## Diagonal of the box (width x width x height): the original size of the hitbox (estimated).
	var diagonal := Vector3(width, width, height).length()
	portal.position = Vector3(0.0, height * 0.5, 0.0)
	portal.radius = portal_scale * diagonal
	portal.open()
