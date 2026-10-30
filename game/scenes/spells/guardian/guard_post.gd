@tool
class_name GuardPost
extends DamageModifier

## «This building accepts guardians». A child of a Manalith (structure.tscn) or an altar
## (altar.tscn); a shrine would add its own. It knows its owner, where a guardian is tied (the
## attach point), whether it is still open and which creatures are tied to it, and it splits the
## damage the building would take among them. Take the child out and the building cannot be guarded.
## Only the server (or solo) keeps the list: it is a DamageModifier of the building's Health, which
## asks deflect() only where it has authority.
## Damage split: each valid guardian takes damage / min(n, 0.5 (n + 3)) with its own resistances and
## factors; with no valid guardian the building takes the hit. Where the beam ends is the
## `attach_point` marker of the building: move it with the gizmo (15 m up on a Manalith, 2.5 m on an
## altar or a Shrine).

const GROUP := &"guard_post"

## The building (its owner_slot and position). Obligatory.
@export var host: Node3D
## Where the beam ends: a Marker3D child of the building.
@export var attach_point: Marker3D
## The host's Health, if it has one (an altar has none): a dead host closes the post.
@export var health: Health
## The altar, if the host is one: a destroyed altar closes the post.
@export var altar: Altar

var _guards: Array[GuardianBond] = []


## n guardians each take damage / this.
static func split_divisor(count: int) -> float:
	return minf(float(count), 0.5 * (float(count) + 3.0))


## The open post of `slot` closest to `from` on the plane within `max_distance`, or null.
## It is the nearest by distance on the plane, own side. Posts are found by group, never by path.
static func closest(tree: SceneTree, slot: int, from: Vector3, max_distance := INF) -> GuardPost:
	var best: GuardPost = null
	var best_d := INF
	for node in tree.get_nodes_in_group(GROUP):
		var post := node as GuardPost
		if post == null or not post.is_open() or post.owner_slot() != slot:
			continue
		var gap := post.host.global_position - from
		var d := Vector2(gap.x, gap.z).length()
		if d <= max_distance and d < best_d:
			best_d = d
			best = post
	return best


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if host == null:
		warnings.append("Assign the building to `host` (its owner and its position).")
	if attach_point == null:
		warnings.append("Assign to `attach_point` the Marker3D where the beam ends.")
	return warnings


## Slot of the owner (0 = nobody's).
func owner_slot() -> int:
	return int(host.get("owner_slot")) if host != null and "owner_slot" in host else 0


## Where the beam ends.
func attach_position() -> Vector3:
	if attach_point != null:
		return attach_point.global_position
	return host.global_position if host != null else Vector3.ZERO


## The building stands and can hold guardians.
func is_open() -> bool:
	if (
		host == null
		or not is_instance_valid(host)
		or not host.is_inside_tree()
		or host.is_queued_for_deletion()
	):
		return false
	if health != null and health.is_dead():
		return false
	if altar != null and altar.is_destroyed():
		return false
	return true


func guard_count() -> int:
	_prune()
	return _guards.size()


## Server or solo. Creatures tied here, valid or not.
func guards() -> Array[GuardianBond]:
	_prune()
	return _guards.duplicate()


func bind(bond: GuardianBond) -> void:
	if bond != null and not _guards.has(bond):
		_guards.append(bond)


func unbind(bond: GuardianBond) -> void:
	_guards.erase(bond)


func deflect(amount: float, kind: StringName, from_slot: int) -> float:
	_prune()
	if _guards.is_empty() or amount <= 0.0:
		return NAN
	var share := amount / split_divisor(_guards.size())
	var taken := 0.0
	var any := false
	for bond in _guards.duplicate():
		if not bond.is_valid_guard():
			continue
		any = true
		taken += bond.health.damage_typed(share, kind, from_slot)
	return taken if any else NAN


func _prune() -> void:
	for index in range(_guards.size() - 1, -1, -1):
		if not is_instance_valid(_guards[index]):
			_guards.remove_at(index)
