@tool
class_name DeathCloudSpawner
extends Node

## F118 (RFC-030g): the only owner of «does this creature leave a cloud when it dies?». sacengine kill() walks
## passiveAbility and passiveAbility2 and starts the cloud of each one it knows (state.d:8274-8278); here each passive tag of
## CreatureType.passive_abilities that has a DeathCloudType in `types` instances its scene. A child of unit.tscn; take it
## out and nobody leaves a cloud. Server (or solo) only: Health.died fires there, the cloud acts there and its puff reaches
## every peer through FxBus.

@export var body: UnitBody
@export var health: Health
## The clouds of this shape (goc@, cen@, tum@). A new one is a new .tres here.
@export var types: Array[DeathCloudType] = []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta el cuerpo (body).")
	if health == null:
		warnings.append("Falta la vida (health).")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint() or health == null:
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	health.died.connect(_on_died)


## The DeathCloudType of `tag`, or null.
func type_of(tag: String) -> DeathCloudType:
	for candidate in types:
		if candidate != null and candidate.tag == tag:
			return candidate
	return null


func _on_died(_from_slot: int) -> void:
	if body == null or body.type == null:
		return
	## The center is taken now, where the body died; the cloud acts after the hit that killed it is over (sacengine adds
	## the effect and runs it in its effects pass, state.d:27454-27522).
	var center := _center()
	for tag in body.type.passive_abilities:
		var cloud_type := type_of(tag)
		var ability := GameData.ability(tag)
		if cloud_type == null or cloud_type.scene == null or ability == null:
			continue
		_burst.call_deferred(cloud_type, ability, center)


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
	cloud.burst(center, cloud_type.fx_name, cloud_type.fx_height_m)


## sacengine boxCenter(hitbox): the center of the body's collision capsule.
func _center() -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position
