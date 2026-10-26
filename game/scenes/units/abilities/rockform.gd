class_name Rockform
extends AbilityEffect

## F133 (RFC-030 030v-b): the Earthfling's Rockform (dihk), moved from AbilitySlot's branches without a change.
## sacengine rockForm (state.d:13052-13065, 25040-25067): the creature stops, drops its orders and turns into a rock
## (renderer.d:2084-2091: the rock model at its center, scale 0.55·hit box diagonal, grown over 30 frames). It takes 5 % damage
## (state.d:8964; UnitBody sets damage_factor), still regenerates (state.d:1430), is hidden from enemy AI and does nothing until it
## gets an order (state.d:13663-13669). status()/fire() are the server's; show_rock_form() runs on every peer, from UnitBody's mode setter.

## The rock shell: scenes/props/meshes/rock.res (the Rock spell's rock).
@export var rock_mesh: Mesh
@export var rock_scale_factor := 0.55
## sacengine RockForm.numFrames at 60 fps.
@export var rock_grow_s := 0.5
@export var rock_color := Color(0.42, 0.4, 0.34)

var _shell: MeshInstance3D
var _shell_tween: Tween


func status(_target_pos: Vector3, _target: Node3D) -> String:
	if user.is_rock_form():
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority():
		return false
	user.special_forms.enter_rock()
	FxBus.broadcast("rock_emerge", user.global_position + Vector3.UP * 0.5)
	return true


## Every peer: the shell grows when the body enters ROCK_FORM and shrinks when it leaves.
func show_rock_form(on: bool) -> void:
	if DebugLog.on(&"effects"):
		print("rockform %s %s (tick %d)" % ["abierto" if on else "cerrado", AbilityEffect.who(user), MatchClock.now()])
	if on and _shell == null:
		_shell = MeshInstance3D.new()
		_shell.name = "RockShell"
		_shell.mesh = rock_mesh
		if _shell.mesh == null:
			var ball := SphereMesh.new()
			_shell.mesh = ball
			var mat := StandardMaterial3D.new()
			mat.albedo_color = rock_color
			mat.roughness = 1.0
			_shell.material_override = mat
		user.add_child(_shell)
	if _shell == null:
		return
	var profile := user.melee_profile()
	var reach := float(profile.get("reach", 0.35))
	var height := float(profile.get("height", 1.8))
	var full := rock_scale_factor * Vector3(2.0 * reach, height, 2.0 * reach).length()
	_shell.position = Vector3(0.0, height * 0.5, 0.0)
	if _shell_tween:
		_shell_tween.kill()
	if on:
		_shell.visible = true
		_shell.scale = Vector3.ONE * 0.01
	_shell_tween = _shell.create_tween()
	_shell_tween.tween_property(_shell, "scale", Vector3.ONE * (full if on else 0.01), rock_grow_s)
	if not on:
		_shell_tween.tween_callback(_shell.hide)
