@tool
class_name DeathCloudSpawner
extends Node

## The only owner of «does this creature leave a cloud when it dies?»: every DeathCloudType in the creature's `passives`
## instances its scene where the body died. A child of unit.tscn; take it out and nobody leaves a cloud. Server (or solo) only:
## Health.died fires there, the cloud acts there and its puff reaches every peer through FxBus.
## Ref: F118 (RFC-030g), sacengine kill() walks passiveAbility and passiveAbility2 (state.d:8274-8278).

@export var body: UnitBody
@export var health: Health

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
	if not is_multiplayer_authority():
		return
	health.died.connect(_on_died)


func _on_died(_from_slot: int) -> void:
	if body == null or body.type == null:
		return
	## The center is taken now, where the body died; the cloud acts after the hit that killed it is over (sacengine adds
	## the effect and runs it in its effects pass, state.d:27454-27522).
	var center := _center()
	for passive: CreaturePassive in body.type.passives:
		var cloud_type := passive as DeathCloudType
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


## sacengine boxCenter(hitbox): the center of the body's collision capsule.
func _center() -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position
