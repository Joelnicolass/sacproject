@tool
class_name DeathCloudSpawner
extends UnitPassive

## The cloud a creature leaves when it dies: every DeathCloudType in `clouds` instances its scene
## where the body died. A node of the creature's `<name>_passives.tscn` (Cog, Necryl, Mutant,
## Phoenix); a creature without it leaves nothing. Server (or solo) only: Health.died fires there,
## the cloud acts there and its puff reaches every peer through FxBus.

## The clouds it leaves, in order (data/death_clouds/).
@export var clouds: Array[DeathCloudType] = []

var _health: Health


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if clouds.is_empty():
		warnings.append("Add at least one DeathCloudType to `clouds`.")
	return warnings


func attach(mount: PassiveMount) -> void:
	super(mount)
	_health = mount.health


func _ready() -> void:
	if Engine.is_editor_hint() or _health == null:
		return
	if not is_multiplayer_authority():
		return
	_health.died.connect(_on_died)


func _on_died(_from_slot: int) -> void:
	if body == null:
		return
	# The center is taken now, where the body died; the cloud acts after the hit that killed it is
	# over.
	var center := _center()
	for cloud_type in clouds:
		if cloud_type == null or cloud_type.scene == null or cloud_type.ability == null:
			continue
		_burst.call_deferred(cloud_type, cloud_type.ability, center)


func _burst(cloud_type: DeathCloudType, ability: AbilityType, center: Vector3) -> void:
	if not is_inside_tree():
		return
	var cloud := cloud_type.scene.instantiate() as DeathCloud
	if cloud == null:
		return
	cloud.ability = ability
	cloud.from_slot = body.owner_slot
	cloud.dead = body
	add_child(cloud)
	cloud.burst(center, cloud_type.fx)


## The center of the body's collision capsule.
func _center() -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position
