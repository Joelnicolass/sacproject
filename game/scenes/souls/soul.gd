class_name Soul
extends Node3D

## A soul of a dead creature. The server (or solo) moves it; clients get
## position, scaling and state from the MultiplayerSynchronizer and only draw it.
##
## While `attached` it sits on its corpse (soulPosition = corpse center). A free soul (dropped,
## or its corpse is gone) falls at 1 m/s to the ground. It grows in over 3 s (EMERGING) before
## anyone can take it, and shrinks toward the collector at 4/s (COLLECTING).
## Color is per viewer (`color_for`): blue if it has no side or it is the viewer's, else red.
## Convert (RFC-020e): a red soul can be converted by the other side; while a Sac Doctor revives its
## corpse the soul is REVIVING (nobody collects or converts it, it is not drawn).
## F131 (RFC-030 030t-a): a creature with Devour eats it (DEVOURING): it shrinks at 3/s toward the eater's shot origin and
## the corpse dissolves. This script owns what a soul
## is and what can be done to it: the corpse it leaves (`sever`), who may eat it, which soul waits on a corpse.
## Ref: sacengine Soul, state.d:1580, updateSoul 14904; sacengine devourSoul, severSoul, updateSoul: state.d:13138, 17925, 14991

## REVIVING and DEVOURING go last: `state` is replicated as an integer.
enum State { NORMAL, EMERGING, COLLECTING, REVIVING, DEVOURING }
enum SoulColor { BLUE, RED }

## Every soul in play.
const GROUP := &"soul"

## The state changed (every peer: the setter runs on the replicated value too). RFC-052 052h: SoulSounds listens.
signal state_changed(was: State, now: State)

## SacSoul.getMesh(color, frame/2) with frame at 30 fps: 8 cells at 15 fps.
## Ref: sacobject.d:1174
const ANIM_FPS := 15.0
const ANIM_FRAMES := 8
const FIRST_FRAME := { SoulColor.BLUE: 0, SoulColor.RED: 8 }
## SacSoul soulWidth 1, soulHeight 1.6, soulRadius 0.3.
## Ref: sacobject.d:1163
const SPRITE_SIZE := Vector2(1.0, 1.6)
const RING_RADIUS := 0.3
## The sprite is drawn 1.25·soulHeight over the soul position.
## Ref: renderer.d:1533
const SPRITE_LIFT := 1.25 * 1.6

## Souls inside (Cre8.souls of the creature, 1 when dropped).
@export var number := 1:
	set(value):
		number = maxi(value, 0)
		_rebuild_sprites()
## Slot of the creature or of the wizard that dropped it (0 = nobody).
@export var owner_slot := 0
## Still on its corpse.
## Ref: sacengine creatureId != 0
@export var attached := false
## Slot of the wizard taking it, while COLLECTING.
@export var collector_slot := 0
## Dropped with P: creature orders will not target it.
## Ref: sacengine `dropped`
@export var dropped := false
@export var state: State = State.NORMAL:
	set(value):
		if state == value:
			return
		var was := state
		state = value
		state_changed.emit(was, value)
@export var scaling := 1.0

@export_group("Motion")
@export var emerge_s := 3.0
@export var collect_shrink_per_s := 4.0
## Devour: 3/updateFPS a tick.
## Ref: state.d:14998
@export var devour_shrink_per_s := 3.0
@export var fall_speed := 1.0
## A soul that falls through a hole is gone this far under the last ground it had.
## Ref: soulVanishDepth = mapDepth (sacmap.d:108).
@export_range(0.0, 200.0, 1.0, "suffix:m") var vanish_depth_m := 50.0
@export var collector_lift := 0.5
## The ring of a multi-soul turns 2π/8 rad/s.
## Ref: sacengine
@export var ring_turn_per_s := TAU / 8.0
@export_flags_3d_physics var ground_mask := 1

@export_group("Rise")
## How far under its hover height the soul starts when it appears (it only moves the drawing, never the soul).
@export_range(0.0, 3.0, 0.05, "suffix:m") var rise_m := 0.8
## Seconds the soul takes to rise from the corpse to its hover height.
@export_range(0.0, 5.0, 0.05, "suffix:s") var rise_s := 1.2

@export_group("Look")
## Soul sprite sheet (`spir`, 4x4 frames).
@export var atlas: Texture2D
@export var shader: Shader = preload("res://scenes/souls/soul.gdshader")
## The original uses 20 with its own tonemap; under High Noon's ACES that clips the soul to white.
@export var energy := 2.0


var corpse: Node3D
var collector: Node3D
## The spell that drags it (Soul Mole, Soul Wind): while it lives the soul sits on it. Server only; the clients get the position.
var carrier: Node3D
## Where it came from (SoulSystem.ORIGIN_*), for the ledger of the bench. Not replicated: the clients only draw.
var origin: StringName = &"creature"

## Server only: bit `slot` set = a Convert of that slot is underway on this soul.
var _reserved_mask := 0
## The corpse the soul left (begin_collect, begin_devour): sever() dissolves it. Server only.
var _remains: Node3D
var _who := ""
var _anim_t := 0.0
## The seat that looks at this soul (the colour of its ring), asked once when it enters the tree.
var _viewer_slot := 0
var _facing := 0.0
var _rise_t := 0.0
## Server only: the height of the last ground under it (NAN until it has seen one).
var _last_ground_y := NAN
var _sprites: Array[MeshInstance3D] = []
var _material: ShaderMaterial

@onready var _visual := find_child("Visual", false, false) as Node3D


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
	add_to_group(GROUP)
	_viewer_slot = MpLocalSeat.slot_of(self)
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "Visual"
		add_child(_visual)
	var target := get_node_or_null("Target")
	if target:
		target.add_to_group("soul_target")
	_rebuild_sprites()
	## A soul that is already full grown (a late join) does not rise again.
	if state != State.EMERGING:
		_rise_t = rise_s
	if not is_multiplayer_authority():
		set_physics_process(false)
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## A soul off its corpse and not being taken has no side.
## Ref: sacengine Soul.side
func side() -> int:
	if not attached and collector_slot == 0:
		return 0
	return owner_slot


func color_for(slot: int) -> SoulColor:
	var soul_side := side()
	return SoulColor.BLUE if soul_side == 0 or soul_side == slot else SoulColor.RED


## A red soul still on its corpse needs Convert first.
## Ref: state.d:14951
func can_be_collected_by(slot: int) -> bool:
	return state == State.NORMAL and (not attached or color_for(slot) == SoulColor.BLUE)


## A red soul in the open, grown or still growing in, that no doctor of that side is already coming for. A soul that just
## appeared can be converted right away, like the end of the cast and the carrier already allow.
## Ref: sacengine convertSideMask and spellStatus (no soul state check), state.d:1588, 10184, 29547, 30822.
func can_convert_by(slot: int) -> bool:
	return (state == State.NORMAL or state == State.EMERGING) and color_for(slot) == SoulColor.RED and not is_reserved_for(slot)


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
	carrier = null
	collector = by
	collector_slot = slot
	_remains = corpse
	attached = false
	corpse = null
	state = State.COLLECTING


## Blue for `slot`: no side (free, dropped) or its own.
## Ref: isApplicable of Devour, state.d:30820-30825
func is_free_or_own(slot: int) -> bool:
	return color_for(slot) == SoulColor.BLUE


## Server or solo. `by` eats the soul: it leaves the corpse, takes the eater's side and
## shrinks toward its shot origin; the corpse dissolves. What the eater gains is DevourGrowth's.
## Ref: devourSoul, state.d:13138-13148
func begin_devour(by: Node3D) -> void:
	collector = by
	collector_slot = int(by.get("owner_slot")) if "owner_slot" in by else 0
	_remains = corpse
	_who = label()
	attached = false
	corpse = null
	state = State.DEVOURING
	if DebugLog.on(&"souls"):
		print("alma %s devorando (tick %d)" % [_who, MatchClock.now()])
	sever()


## Server or solo. The soul no longer holds its corpse: it dissolves. The one place that does.
## Ref: severSoul, state.d:17925-17935
func sever() -> void:
	var dead := _remains
	_remains = null
	if dead == null or not is_instance_valid(dead):
		return
	var body := dead.get_node_or_null("Corpse") as Corpse
	if body == null:
		return
	body.dissolve(dead)
	if DebugLog.on(&"souls"):
		print("cadáver %s disuelto (tick %d)" % [dead.name, MatchClock.now()])


## A soul a spell can fetch for `slot`: not dropped with P, blue for that side, and still waiting (not being taken, eaten or revived).
func fetchable_by(slot: int) -> bool:
	return not dropped and is_free_or_own(slot) and (state == State.NORMAL or state == State.EMERGING)


## Server or solo. Soul Mole and Soul Wind take the soul: it lets go of its corpse (which dissolves), prefers the wizard's side
## when somebody collects it, and follows `by` until `by` is gone.
func release_to(slot: int, by: Node3D) -> void:
	if _remains == null:
		_remains = corpse
	attached = false
	corpse = null
	sever()
	owner_slot = slot
	carrier = by


## Server or solo. Rend Soul: the soul explodes. It lets go of its corpse (severSoul dissolves
## it), has nothing inside and goes. What the blast does is the strike's.
## Ref: updateRendShoot, state.d:25867-25890
func burst() -> void:
	_who = label()
	if _remains == null:
		_remains = corpse
	attached = false
	corpse = null
	sever()
	number = 0
	if DebugLog.on(&"souls"):
		print("alma %s reventada (tick %d)" % [_who, MatchClock.now()])
	queue_free()


## What the logs call it: the creature it came from (its corpse), else its own name.
func label() -> String:
	if _remains != null and is_instance_valid(_remains):
		return str(_remains.name)
	if corpse != null and is_instance_valid(corpse):
		return str(corpse.name)
	return _who if not _who.is_empty() else str(name)


## The soul that waits on `corpse` (Soul.corpse), or null. A soul being eaten or collected has let go of it.
static func on_corpse(corpse_node: Node3D) -> Soul:
	if corpse_node == null or not corpse_node.is_inside_tree():
		return null
	for node in corpse_node.get_tree().get_nodes_in_group(&"soul"):
		var soul := node as Soul
		if soul != null and soul.corpse == corpse_node:
			return soul
	return null


func _physics_process(delta: float) -> void:
	if state != State.COLLECTING and state != State.DEVOURING:
		if carrier != null and is_instance_valid(carrier):
			global_position = carrier.global_position
		elif attached:
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
		State.DEVOURING:
			_devour_step(delta)


func _follow_corpse() -> void:
	if corpse == null or not is_instance_valid(corpse) or not corpse.is_inside_tree():
		attached = false
		corpse = null
		return
	global_position = (corpse as UnitBody).soul_anchor() if corpse is UnitBody else corpse.global_position


## A free soul comes down to the land under it. Over a hole (no land under it on the map) it keeps falling at `fall_speed` and is
## gone once it is `vanish_depth_m` under the last ground it had. Without ground and without a hole (the terrain not built yet) it
## stays put.
## Ref: updateSoul (state.d:14912-14920), soulVanishDepth = mapDepth (sacmap.d:108).
func _settle(delta: float) -> void:
	var at := global_position
	var ground := GroundRay.surface_y(self, at, ground_mask, GroundRay.wizard_rids(get_tree()), NAN)
	if is_nan(ground):
		var terrain := Terrain.of(self)
		if terrain == null or terrain.is_on_ground(at.x, at.z):
			return
		if is_nan(_last_ground_y):
			_last_ground_y = at.y
		global_position.y = at.y - fall_speed * delta
		if global_position.y < _last_ground_y - vanish_depth_m:
			_vanish()
		return
	_last_ground_y = ground
	if at.y > ground:
		global_position.y = maxf(at.y - fall_speed * delta, ground)
	else:
		global_position.y = ground


## Server or solo: it fell through a hole and is gone, with nothing inside (no one collects it).
func _vanish() -> void:
	number = 0
	queue_free()


func _collect_step(delta: float) -> void:
	var previous := scaling
	scaling = maxf(scaling - collect_shrink_per_s * delta, 0.0)
	if collector and is_instance_valid(collector):
		var factor := scaling / previous if previous > 0.0 else 0.0
		global_position = global_position * factor + _collector_center() * (1.0 - factor)
	if scaling <= 0.0:
		number = 0
		queue_free()


## updateSoul: it shrinks toward the eater's shot origin and goes at nothing.
## Ref: state.d:14991-15006
func _devour_step(delta: float) -> void:
	var previous := scaling
	scaling = maxf(scaling - devour_shrink_per_s * delta, 0.0)
	if scaling < 1e-6:
		scaling = 0.0
	if collector and is_instance_valid(collector):
		var factor := scaling / previous if previous > 0.0 else 0.0
		global_position = global_position * factor + ShotAim.shot_position(collector) * (1.0 - factor)
	if scaling <= 0.0:
		number = 0
		if DebugLog.on(&"souls"):
			print("alma %s devorada (tick %d)" % [_who, MatchClock.now()])
		queue_free()


func _collector_center() -> Vector3:
	var col := collector.get_node_or_null("Collision") as Node3D
	var center := col.global_position if col else collector.global_position
	return center + Vector3.UP * collector_lift


func _process(delta: float) -> void:
	_rise(delta)
	if _sprites.is_empty():
		return
	_anim_t += delta
	_facing = wrapf(_facing + ring_turn_per_s * delta, -PI, PI)
	var cell: int = FIRST_FRAME[color_for(_viewer_slot)] + int(_anim_t * ANIM_FPS) % ANIM_FRAMES
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


## Presentation only: the drawing starts `rise_m` under the soul and climbs to it; the soul itself does not move.
func _rise(delta: float) -> void:
	_rise_t = minf(_rise_t + delta, rise_s)
	var progress := 1.0 if rise_s <= 0.0 else smoothstep(0.0, 1.0, _rise_t / rise_s)
	_visual.position.y = -rise_m * (1.0 - progress)


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
		_visual.add_child(sprite)
		_sprites.append(sprite)


func _soul_material() -> ShaderMaterial:
	if _material:
		return _material
	var texture := atlas
	if texture == null:
		return null
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("atlas", texture)
	_material.set_shader_parameter("energy", energy)
	return _material
