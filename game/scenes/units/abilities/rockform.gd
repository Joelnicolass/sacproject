class_name Rockform
extends AbilityEffect

## The Earthfling's Rockform (dihk): the creature stops, drops its orders and turns into a rock that grows at its center (scale 0.55 x the
## diagonal of its box, over `rock_grow_s`). It takes 5 % damage (UnitBody sets damage_factor), still regenerates, is hidden from enemy
## AI and does nothing until it gets an order. status()/fire() are the server's; show_rock_form() runs on every peer, from UnitBody's mode setter.
## What it does not do: the damage factor (UnitBody), the state (RockFormState) or the look of the rock (rock_shell.tscn).

## The rock shell (rock_shell.tscn): instanced under the body only where meshes are drawn, at `shell_socket`.
@export var shell_scene: PackedScene = preload("res://scenes/units/abilities/rock_shell.tscn")
@export var shell_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER
@export var rock_scale_factor := 0.55
## How long the body takes to grow into the rock.
@export var rock_grow_s := 0.5
## The burst on every peer when the body turns to rock, and where on the body (not verified).
@export var emerge_fx: ParticleType = preload("res://data/fx/rock_emerge.tres")
@export var emerge_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

var _shell: Node3D
var _shell_tween: Tween


func status(_target_pos: Vector3, _target: Node3D) -> String:
	if user.is_rock_form():
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	user.special_forms.enter_rock()
	if emerge_fx != null:
		FxBus.broadcast(emerge_fx, BodyFacts.point(user, emerge_socket))
	return true


## Every peer: the shell grows when the body enters ROCK_FORM and shrinks when it leaves. Never where meshes are not drawn (dedicated).
func show_rock_form(on: bool) -> void:
	if DebugLog.on(&"effects"):
		print("rockform %s %s (tick %d)" % ["abierto" if on else "cerrado", AbilityEffect.who(user), MatchClock.now()])
	if on and _shell == null and shell_scene != null and BodyLook.loads_meshes():
		_shell = shell_scene.instantiate() as Node3D
		user.add_child(_shell)
	if _shell == null:
		return
	var facts := BodyFacts.of_body(user)
	var full := rock_scale_factor * Vector3(2.0 * facts.reach_m, facts.height_m, 2.0 * facts.reach_m).length()
	_shell.position = facts.local(shell_socket)
	if _shell_tween:
		_shell_tween.kill()
	if on:
		_shell.visible = true
		_shell.scale = Vector3.ONE * 0.01
	_shell_tween = _shell.create_tween()
	_shell_tween.tween_property(_shell, "scale", Vector3.ONE * (full if on else 0.01), rock_grow_s)
	if not on:
		_shell_tween.tween_callback(_shell.hide)
