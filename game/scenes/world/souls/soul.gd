class_name Soul
extends Node3D

## sacengine Soul (state.d:1580, updateSoul 14904). The server (or solo) moves it; clients get
## position, scaling and state from the MultiplayerSynchronizer and only draw it.
##
## While `attached` it sits on its corpse (soulPosition = corpse center). A free soul (dropped,
## or its corpse is gone) falls at 1 m/s to the ground. It grows in over 3 s (EMERGING) before
## anyone can take it, and shrinks toward the collector at 4/s (COLLECTING).
## Color is per viewer (`color_for`): blue if it has no side or it is the viewer's, else red.
## Convert (RFC-020e): a red soul can be converted by the other side; while a Sac Doctor revives its
## corpse the soul is REVIVING (nobody collects or converts it, it is not drawn).

## REVIVING is last: `state` is replicated as an integer.
enum State { NORMAL, EMERGING, COLLECTING, REVIVING }
enum SoulColor { BLUE, RED }

const _SPRITES := preload("res://scenes/fx/sprite_particles.gd")
## SacSoul.getMesh(color, frame/2) with frame at 30 fps: 8 cells at 15 fps (sacobject.d:1174).
const ANIM_FPS := 15.0
const ANIM_FRAMES := 8
const FIRST_FRAME := { SoulColor.BLUE: 0, SoulColor.RED: 8 }
## SacSoul soulWidth 1, soulHeight 1.6, soulRadius 0.3 (sacobject.d:1163).
const SPRITE_SIZE := Vector2(1.0, 1.6)
const RING_RADIUS := 0.3
## renderer.d:1533: the sprite is drawn 1.25·soulHeight over the soul position.
const SPRITE_LIFT := 1.25 * 1.6

## Souls inside (Cre8.souls of the creature, 1 when dropped).
@export var number := 1:
	set(value):
		number = maxi(value, 0)
		_rebuild_sprites()
## Slot of the creature or of the wizard that dropped it (0 = nobody).
@export var owner_slot := 0
## Still on its corpse (sacengine creatureId != 0).
@export var attached := false
## Slot of the wizard taking it, while COLLECTING.
@export var collector_slot := 0
## Dropped with P: creature orders will not target it (sacengine `dropped`).
@export var dropped := false
@export var state: State = State.NORMAL
@export var scaling := 1.0

@export_group("Motion")
@export var emerge_s := 3.0
@export var collect_shrink_per_s := 4.0
@export var fall_speed := 1.0
@export var collector_lift := 0.5
## sacengine turns the ring of a multi-soul 2π/8 rad/s.
@export var ring_turn_per_s := TAU / 8.0
@export_flags_3d_physics var ground_mask := 1

@export_group("Look")
@export_file("*.json") var catalog_path := "res://cache/look/fx/fx.json"
@export var atlas_key := "soul"
@export var shader: Shader = preload("res://scenes/world/souls/soul.gdshader")
## sacengine uses 20 with its own tonemap; under High Noon's ACES that clips the soul to white.
@export var energy := 2.0

var corpse: Node3D
var collector: Node3D
## Where it came from (SoulSystem.ORIGIN_*), for the ledger of the bench. Not replicated: the clients only draw.
var origin: StringName = &"creature"

## Server only: bit `slot` set = a Convert of that slot is underway on this soul.
var _reserved_mask := 0
var _anim_t := 0.0
var _facing := 0.0
var _sprites: Array[MeshInstance3D] = []
var _material: ShaderMaterial


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	number = int(data.get("number", 1))
	owner_slot = int(data.get("owner_slot", 0))
	attached = bool(data.get("attached", false))
	dropped = bool(data.get("dropped", false))
	origin = StringName(str(data.get("origin", "creature")))
	state = State.EMERGING if bool(data.get("emerging", true)) else State.NORMAL
	scaling = 0.0 if state == State.EMERGING else 1.0


func _ready() -> void:
	add_to_group("soul")
	var target := get_node_or_null("Target")
	if target:
		target.add_to_group("soul_target")
	_rebuild_sprites()
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


## sacengine Soul.side: a soul off its corpse and not being taken has no side.
func side() -> int:
	if not attached and collector_slot == 0:
		return 0
	return owner_slot


func color_for(slot: int) -> SoulColor:
	var soul_side := side()
	return SoulColor.BLUE if soul_side == 0 or soul_side == slot else SoulColor.RED


## A red soul still on its corpse needs Convert first (state.d:14951).
func can_be_collected_by(slot: int) -> bool:
	return state == State.NORMAL and (not attached or color_for(slot) == SoulColor.BLUE)


## A red soul in the open that no doctor of that side is already coming for (sacengine convertSideMask,
## state.d:1588, 10184, 29547).
func can_convert_by(slot: int) -> bool:
	return state == State.NORMAL and color_for(slot) == SoulColor.RED and not is_reserved_for(slot)


## Server or solo. A Convert cast of `slot` fixes this soul (castConvert clears the side's bit).
func reserve_for(slot: int) -> void:
	if slot > 0 and slot < 32:
		_reserved_mask |= 1 << slot


## Server or solo. The doctor died or the cast stopped: the soul can be converted again (freeSoulImpl).
func release_for(slot: int) -> void:
	if slot > 0 and slot < 32:
		_reserved_mask &= ~(1 << slot)


func is_reserved_for(slot: int) -> bool:
	return slot > 0 and slot < 32 and (_reserved_mask & (1 << slot)) != 0


func begin_collect(by: Node3D, slot: int) -> void:
	collector = by
	collector_slot = slot
	attached = false
	corpse = null
	state = State.COLLECTING


func _physics_process(delta: float) -> void:
	if state != State.COLLECTING:
		if attached:
			_follow_corpse()
		else:
			_settle(delta)
	match state:
		State.EMERGING:
			scaling = minf(scaling + delta / emerge_s, 1.0)
			if scaling >= 1.0:
				state = State.NORMAL
		State.COLLECTING:
			_collect_step(delta)


func _follow_corpse() -> void:
	if corpse == null or not is_instance_valid(corpse) or not corpse.is_inside_tree():
		attached = false
		corpse = null
		return
	global_position = corpse.call("soul_anchor") if corpse.has_method("soul_anchor") else corpse.global_position


## Without ground under it (terrain not built yet) it stays put; sacengine drops off-map souls.
func _settle(delta: float) -> void:
	var at := global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = ground_mask
	query.exclude = _wizard_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var ground := float(hit.position.y)
	if at.y > ground:
		global_position.y = maxf(at.y - fall_speed * delta, ground)
	else:
		global_position.y = ground


## Wizards share the ground layer.
func _wizard_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for body in get_tree().get_nodes_in_group("wizard"):
		if body is CollisionObject3D:
			rids.append((body as CollisionObject3D).get_rid())
	return rids


func _collect_step(delta: float) -> void:
	var previous := scaling
	scaling = maxf(scaling - collect_shrink_per_s * delta, 0.0)
	if collector and is_instance_valid(collector):
		var factor := scaling / previous if previous > 0.0 else 0.0
		global_position = global_position * factor + _collector_center() * (1.0 - factor)
	if scaling <= 0.0:
		number = 0
		queue_free()


func _collector_center() -> Vector3:
	var col := collector.get_node_or_null("Collision") as Node3D
	var center := col.global_position if col else collector.global_position
	return center + Vector3.UP * collector_lift


func _process(delta: float) -> void:
	if _sprites.is_empty():
		return
	_anim_t += delta
	_facing = wrapf(_facing + ring_turn_per_s * delta, -PI, PI)
	var cell: int = FIRST_FRAME[color_for(MpKit.local_slot())] + int(_anim_t * ANIM_FPS) % ANIM_FRAMES
	var lift := Vector3.UP * SPRITE_LIFT * scaling
	var count := _sprites.size()
	if state == State.REVIVING:
		for sprite in _sprites:
			sprite.visible = false
		return
	if count == 1:
		_place(_sprites[0], lift, scaling, cell)
		return
	var each := maxf(0.5, 1.0 - 0.05 * count) * scaling
	var radius := scaling * RING_RADIUS
	if count <= 3:
		radius *= 0.3 * count
	for k in count:
		var angle := _facing + TAU * k / count
		var offset := Vector3(-sin(angle), 0.0, cos(angle)) * radius
		_place(_sprites[k], offset + lift, each, cell)


func _place(sprite: MeshInstance3D, at: Vector3, size: float, cell: int) -> void:
	sprite.position = at
	sprite.scale = Vector3.ONE * maxf(size, 0.001)
	sprite.visible = size > 0.0
	sprite.set_instance_shader_parameter("frame", cell)


func _rebuild_sprites() -> void:
	if not is_node_ready() or DisplayServer.get_name() == "headless":
		return
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	if number <= 0:
		return
	var material := _soul_material()
	if material == null:
		return
	var quad := QuadMesh.new()
	quad.size = SPRITE_SIZE
	for k in number:
		var sprite := MeshInstance3D.new()
		sprite.name = "Sprite%d" % k
		sprite.mesh = quad
		sprite.material_override = material
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sprite)
		_sprites.append(sprite)


func _soul_material() -> ShaderMaterial:
	if _material:
		return _material
	var texture := _SPRITES.atlas_texture(atlas_key, catalog_path)
	if texture == null:
		return null
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("atlas", texture)
	_material.set_shader_parameter("energy", energy)
	return _material
