class_name CreatureFx
extends Node3D

## The sprite effect a creature carries, from `CreatureType.carried_fx` (the Manahoar's mana flame). It adds the scene
## once the body has its type, at `offset` over the feet, and tints it with the side's mana color (`SideColors.mana_color`):
## the original draws it with additive sprites, not with a light. A creature with no `carried_fx` gets nothing.
## WORKAROUND: the baked `maho` clips carry no attachment point, so the flame sits at a fixed `offset` instead of on its bone.
## Presentation only: the simulation never reads it; a dedicated process draws nothing (SpriteEmitter is inert there).

@export var body: UnitBody
## Where the flame floats, in meters over the creature's feet.
@export var offset := Vector3(0.0, 2.2, 0.0)

var _fx: Node3D


func _ready() -> void:
	if body == null:
		return
	body.ready.connect(_attach, CONNECT_ONE_SHOT)
	if body.is_node_ready():
		_attach()


func _attach() -> void:
	if _fx != null or body.type == null or body.type.carried_fx == null:
		return
	_fx = body.type.carried_fx.instantiate() as Node3D
	_fx.position = offset
	add_child(_fx)
	var emitter := _fx as SpriteEmitter
	if emitter:
		emitter.set_tint(SideColors.mana_color(body.owner_slot), SideColors.mana_energy_scale(body.owner_slot))
		emitter.set_active(true)

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray([] if body else ["Assign `body`."])
