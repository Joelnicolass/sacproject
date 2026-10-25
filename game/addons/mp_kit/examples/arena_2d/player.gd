extends CharacterBody2D

## The example player, written like a single-player script. Arrows move it (predicted: no lag for its owner), Enter
## scores a point and flashes it, Space shoots toward the mouse, Tab changes its color, Escape rings the bell. MpActor (sync, owner, calls, prediction) and MpInput (keys of
## the owner) carry it over the network.

const SPEED := 220.0
const SHOT := preload("res://addons/mp_kit/examples/arena_2d/shot.tscn")
const COLORS: Array[Color] = [Color("e05d5d"), Color("5d9de0"), Color("6cc56c"), Color("e0c25d")]

## Synced (MpActor > Sync > Extra): the server changes it, every peer repaints.
@export var color_index: int = 0:
	set(value):
		color_index = value
		_paint()

## How many flashes this peer has drawn (the lab's e2e probe reads it).
var flashes: int = 0

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput
@onready var body: Polygon2D = $Body


func _ready() -> void:
	$Tag.text = "P%d" % net.owner_slot
	_paint()


## Movement (MpActor > Prediction is on): the server runs it, and the owner runs it at once with its own keys,
## so the player answers without waiting for the network. Keep only movement here: it may run more than once.
func mp_move(keys: MpInput, _delta: float) -> void:
	velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED
	move_and_slide()


## Server and solo: the rules. Clients only draw what the server sends.
func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	if input.is_action_just_pressed(&"ui_accept"):
		MpState.of(self).add(StringName("p%d" % net.owner_slot))
		net.to_all(&"flash")
	if input.is_action_just_pressed(&"ui_select"):
		_shoot()


## The owner: aim at the mouse (the server reads it with input.get_value), a new color, ring the bell.
func _process(_delta: float) -> void:
	if not net.is_local():
		return
	input.set_value(&"aim", (get_global_mouse_position() - global_position).normalized())
	if Input.is_action_just_pressed(&"ui_focus_next"):
		net.to_server(&"recolor")
	if Input.is_action_just_pressed(&"ui_cancel"):
		var bell := get_tree().get_first_node_in_group(&"bell")
		if bell:
			bell.ring()


func _shoot() -> void:
	var shots := get_tree().get_first_node_in_group(&"shot_spawner") as MpSpawner
	if shots == null:
		return
	## The aim comes from the client: check it (a Vector2 of length 1) before using it.
	var aim: Variant = input.get_value(&"aim", Vector2.RIGHT)
	var direction: Vector2 = (aim as Vector2).normalized() if aim is Vector2 and (aim as Vector2).length() > 0.01 else Vector2.RIGHT
	shots.spawn_actor(SHOT, {"position": position, "direction": direction}, net.owner_slot)


func mp_sv_recolor() -> void:
	color_index += 1


func mp_all_flash() -> void:
	flashes += 1
	body.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(body, "modulate", Color.WHITE, 0.25)


func _paint() -> void:
	if body:
		body.color = COLORS[(maxi(net.owner_slot, 1) - 1 + color_index) % COLORS.size()]
