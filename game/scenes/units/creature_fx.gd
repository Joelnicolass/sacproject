class_name CreatureFx
extends Node3D

## The sprite effect a creature carries, from `CreatureType.carried_fx` (the Manahoar's mana flame). It adds the scene
## once the body has its type and tints it with the side's mana color (`SideColors.mana_color`): the original draws it with
## additive sprites, not with a light. A creature with no `carried_fx` gets nothing.
## Where: the flame follows the `carried_fx_socket` of the model's scene (BodyModel; a BoneAttachment3D + Marker3D the editor
## moves with a gizmo), like sacengine's manahoarManaOffset (a point of the skeleton in the current frame of the clip), so it
## moves with the body standing, walking or in any clip. A model with no socket gets the fallback `offset` over the feet.
## How much: sacengine emits as many flame particles per second as the mana the Manahoar gives (state.d animateManahoar takes
## the rate addManahoar returns), so with `follow_mana_rate` the flame fades out when no allied manalith is near.
## Presentation only: the simulation never reads it; a dedicated process draws nothing (SpriteEmitter is inert there).

@export var body: UnitBody
## The skeleton that draws the body: where the model's socket is.
@export var rig: BodyRig
## The Manahoar's mana aura: its rate says how many flame particles per second there are.
@export var mana_support: UnitManaSupport
## Emit at the rate of the mana the creature gives (0 without allied manaliths) instead of the type's `rate_per_s`.
@export var follow_mana_rate := true
## Where the flame floats, in meters over the creature's feet, when the model has no socket.
@export var offset := Vector3(0.0, 1.0, 0.0)
## Radius in meters of the small circle the flame center travels (sacengine globalMagnitude 0.05, one turn per second).
@export_range(0.0, 0.5, 0.01, "suffix:m") var wobble_m := 0.05
## Seconds between two looks at the mana rate.
@export_range(0.05, 2.0, 0.05, "suffix:s") var rate_interval_s := 0.25

var _fx: Node3D
var _socket: Node3D
var _rate_left := 0.0


func _ready() -> void:
	if body == null or not BodyCatalog.loads_meshes():
		set_process(false)
		return
	if rig != null:
		rig.model_loaded.connect(_find_socket)
	body.ready.connect(_attach, CONNECT_ONE_SHOT)
	if body.is_node_ready():
		_attach()


func _process(delta: float) -> void:
	if _fx == null:
		return
	if is_instance_valid(_socket) and _socket.is_inside_tree():
		_fx.global_position = _socket.global_position + _wobble()
	else:
		_fx.position = offset + _wobble()
	_rate_left -= delta
	if _rate_left <= 0.0:
		_rate_left = rate_interval_s
		_apply_rate()


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
	_find_socket()
	_apply_rate()


func _find_socket() -> void:
	_socket = rig.carried_fx_socket() if rig != null else null


func _apply_rate() -> void:
	var emitter := _fx as SpriteEmitter
	if emitter == null or not follow_mana_rate or mana_support == null:
		return
	emitter.set_rate(mana_support.flame_rate())


## The center of the flame circles in the horizontal plane (sacengine adds it to the point of the skeleton).
func _wobble() -> Vector3:
	var angle := TAU * float(Time.get_ticks_msec()) / 1000.0
	return Vector3(cos(angle), 0.0, sin(angle)) * wobble_m


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray([] if body else ["Assign `body`."])
