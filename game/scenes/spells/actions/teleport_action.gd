@tool
class_name TeleportAction
extends SpellAction

## Teleport (elet): the wizard and the creatures of his side near him jump to an own building (RFC-021c).
## The click is a standing building of his own (OWN_BUILDING: Manalith, altar, shrine) at any distance
## (flags 4112 = targetStructures | onlyAlly, range 5000). When the casting ends, he and every creature of
## his within `effect_range` (30) of him go to `effect_range` from the building, on the side he came from,
## keeping their formation (sacengine teleport / getTeleportPosition, state.d:10213-10228, 10313-10327).
## Not carried: the dead, Sac Doctors, guardians (canTeleport, state.d:10306-10311) and, a port decision
## (RFC-021 risk 3), any creature in group «rooted» or held by a doctor. The destination follows the
## building until the casting ends; if it falls meanwhile, the last one is used (updateTeleportCasting,
## state.d:16056-16072). A wizard who dies in the middle moves nobody (the Caster calls cancel()).
## The arithmetic is TeleportMath; the body moves itself (warp_to). Here only the rules, and the cosmetic
## burst, which is local presentation on every peer (nothing is drawn on the dedicated server).

## A body in this group does not travel (the guardian, the captive; GuardianBond adds it).
const NOT_CARRIED := &"rooted"
## sacengine canTeleport excludes the Sac Doctor (state.d:10308).
const DOCTOR_GROUP := &"doctor"

## Groups a building can be in to be aimed at. A shrine would add its own.
@export var target_groups: PackedStringArray = PackedStringArray(["structure", "altar"])
## Particle (FxBus name, res://data/fx/<name>.tres) at the origin and at the destination of each body.
@export var out_fx := "teleport_out"
@export var in_fx := "teleport_in"
## The rings of blue light of each body (TeleportRings). Empty = no rings.
@export var rings_scene: PackedScene

var _destination := Vector3.ZERO
var _has_destination := false


func check(wizard: WizardBody, spell: SpellType, _point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	if not is_building_of(wizard.owner_slot, picked):
		aim.status = BAD_TARGET
		return aim
	aim.target = picked
	aim.point = picked.global_position
	aim.status = standing_status(funds, wizard, spell, aim.point)
	return aim


func begin(wizard: WizardBody, spell: SpellType, aim: Aim) -> void:
	_destination = _landing(wizard.global_position, aim.target, spell.effect_range_m)
	_has_destination = true


## `target` is the building, or null when it is gone: then the last destination stands.
func finish(wizard: WizardBody, spell: SpellType, target: Node3D) -> String:
	if is_building_of(wizard.owner_slot, target):
		_destination = _landing(wizard.global_position, target, spell.effect_range_m)
		_has_destination = true
	if not _has_destination:
		return BAD_TARGET
	var start := wizard.global_position
	var destination := _destination
	_has_destination = false
	var radius := spell.effect_range_m
	var shape := GroundSurface.of(wizard)
	var on_ground := _on_ground_of(shape)
	var froms := PackedVector3Array()
	var tos := PackedVector3Array()
	var widths := PackedFloat32Array()
	var heights := PackedFloat32Array()
	var centers := PackedFloat32Array()
	for body in travelers(wizard, radius):
		var facts := BodyFacts.of_body(body)
		var flying := body is UnitBody and (body as UnitBody).is_flying()
		var spot := TeleportMath.carried(body.global_position, start, destination, flying, on_ground)
		spot.y = _land_y(shape, spot, destination.y)
		froms.append(_feet_of(body))
		body.call("warp_to", spot)  # dynamic: a unit or a wizard warps
		tos.append(_feet_of(body))
		widths.append(2.0 * facts.radius_m)
		heights.append(facts.height_m)
		centers.append(facts.center.y)
	_announce(froms, tos, widths, heights, centers)
	return ""


func cancel() -> void:
	_has_destination = false


## A standing building of `slot` that can be aimed at. Altars count while they stand; any other building,
## while it has life (state.d:30786-30790). `picked` comes from the client.
func is_building_of(slot: int, picked: Node3D) -> bool:
	if picked == null or not is_instance_valid(picked) or not picked.is_inside_tree() or picked.is_queued_for_deletion():
		return false
	var listed := false
	for group in target_groups:
		if picked.is_in_group(group):
			listed = true
			break
	if not listed or slot <= 0 or int(picked.get("owner_slot")) != slot:
		return false
	var altar := picked as Altar
	if altar != null and altar.is_destroyed():
		return false
	var health := picked.get_node_or_null("Health") as Health
	return health == null or not health.is_dead()


## The wizard and each creature of his side within `radius` of him on the plane that can travel.
func travelers(wizard: WizardBody, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = [wizard]
	for node in get_tree().get_nodes_in_group(&"unit"):
		var unit := node as UnitBody
		if unit == null or not unit.is_inside_tree() or unit.is_queued_for_deletion() or unit.owner_slot != wizard.owner_slot:
			continue
		if unit.is_dead() or unit.is_taken() or unit.is_in_group(NOT_CARRIED) or unit.is_in_group(DOCTOR_GROUP):
			continue
		if TeleportMath.in_radius(unit.global_position, wizard.global_position, radius):
			out.append(unit)
	return out


func _landing(start: Vector3, building: Node3D, radius: float) -> Vector3:
	var shape := GroundSurface.of(building)
	var spot := TeleportMath.landing(start, building.global_position, radius, _on_ground_of(shape))
	spot.y = _land_y(shape, spot, building.global_position.y)
	return spot


## The land under a spot (the terrain, never the first collision from above: that is a pillar or a roof),
## or `fallback` where there is no terrain data.
func _land_y(shape: GroundSurface, spot: Vector3, fallback: float) -> float:
	if shape == null:
		return fallback
	var height := shape.height_at(spot.x, spot.z)
	return fallback if is_nan(height) else height


func _on_ground_of(shape: GroundSurface) -> Callable:
	if shape == null:
		return Callable()
	return shape.is_on_ground


## Where the feet of a body are: its Feet marker (a wizard's origin sits above the soles).
func _feet_of(body: Node3D) -> Vector3:
	return body.global_position + BodyFacts.of_body(body).feet


## Server or solo: every peer shows the same burst at the origin and at the destination of each body.
## `centers` is the y of the Center marker of each body, over its feet: where the particle goes.
func _announce(froms: PackedVector3Array, tos: PackedVector3Array, widths: PackedFloat32Array, heights: PackedFloat32Array, centers: PackedFloat32Array) -> void:
	if MpKit.is_networked():
		if MpKit.is_server():
			_show_jump.rpc(froms, tos, widths, heights, centers)
		return
	_show_jump(froms, tos, widths, heights, centers)


@rpc("authority", "call_local", "reliable")
func _show_jump(froms: PackedVector3Array, tos: PackedVector3Array, widths: PackedFloat32Array, heights: PackedFloat32Array, centers: PackedFloat32Array) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	for i in froms.size():
		_burst(out_fx, true, froms[i], widths[i], heights[i], centers[i])
		_burst(in_fx, false, tos[i], widths[i], heights[i], centers[i])


func _burst(fx: String, going_out: bool, feet: Vector3, width: float, height: float, center_y: float) -> void:
	if not fx.is_empty():
		FxBus.play(fx, feet + Vector3(0.0, center_y, 0.0))
	if rings_scene == null:
		return
	var rings := rings_scene.instantiate() as TeleportRings
	if rings == null:
		return
	get_tree().current_scene.add_child(rings)
	rings.start(going_out, feet, width, height)
