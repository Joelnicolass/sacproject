@tool
class_name CaptiveRing
extends Node

## The ring drawn around a creature while a Sac Doctor holds it (UnitBody.mode HELD), centred on the
## body's `Center` (`mount.facts.center`). Local presentation on every peer, drawn from replicated
## state only: the server never creates it, and neither does the dedicated server (no meshes). It
## changes no simulation. Remove the node and the creature is held without a ring. The radii are
## 0.65 * (1.1, 0.9) * the diagonal of the creature's box.

## The creature that wears the ring.
@export var body: UnitBody
## The disc (scenes/fx/portal_disc.tscn, blue). Empty = no ring.
@export var portal_scene: PackedScene
## The ring radii = 0.65 * (1.1, 0.9) * the diagonal of the creature's box.
@export var portal_scale := Vector2(1.1, 0.9) * 0.65

var _portal: PortalDisc


## The CaptiveRing child of a creature, or null.
static func of(unit: Node) -> CaptiveRing:
	return unit.get_node_or_null("CaptiveRing") as CaptiveRing if unit != null else null


func _ready() -> void:
	if Engine.is_editor_hint() or body == null:
		return
	body.held_changed.connect(_on_held_changed)
	_on_held_changed(body.is_held())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Assign to `body` the unit (UnitBody) that wears the ring.")
	if portal_scene == null:
		warnings.append("Assign to `portal_scene` the disc (scenes/fx/portal_disc.tscn).")
	return warnings


## The ring while the creature is held (and closing), or null outside HELD and on the dedicated
## server.
func ring() -> Node3D:
	if _portal == null or not is_instance_valid(_portal) or _portal.is_closing():
		return null
	return _portal


func _on_held_changed(held: bool) -> void:
	if not held:
		if _portal != null and is_instance_valid(_portal):
			_portal.close()
		return
	if portal_scene == null or not BodyLook.loads_meshes():
		return
	if _portal == null or not is_instance_valid(_portal):
		_portal = portal_scene.instantiate() as PortalDisc
		if _portal == null:
			return
		_portal.openness = 0.0
		body.add_child(_portal)
	var facts := BodyFacts.of_body(body)
	# Diagonal of the box (width x width x height): the size of the hitbox (estimated).
	var diagonal := Vector3(2.0 * facts.radius_m, 2.0 * facts.radius_m, facts.height_m).length()
	_portal.position = facts.center
	_portal.radius = portal_scale * diagonal
	_portal.open()
