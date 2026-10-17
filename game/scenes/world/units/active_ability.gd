class_name ActiveAbility
extends Node

## A creature's active ability, used on command (Ctrl+Q / Shift+B). sacengine `ability`
## (sacobject.d:444): abilities[1] for a ranged creature, else abilities[0].
## Checks follow abilityStatus (state.d:29582-29604): cooldown → mana → target → range → the
## ability's own rule. `useAbility` (state.d:13463-13561) drains manaCost and sets the ability
## cooldown (cooldown·60 frames, counted down every frame, state.d:13937) when it applies.
## Implemented from the active book roster:
## Rockform (dihk), Run Away (!nur), Play Dead (dedp), Stealth (ivni),
## Life Shield (hsba), Divine Sight (eesd).
##
## Rockform (state.d:13052-13065, 25040-25067): the creature stops, drops its orders and turns into a
## rock (renderer.d:2084-2091: the rock model at its center, scale 0.55·hit box diagonal, grown over
## 30 frames). It takes 5 % damage (state.d:8964), still regenerates (state.d:1430), is hidden from
## enemy AI and does nothing until it gets an order (state.d:13663-13669).

const COOLING := "Enfriando"
const NO_MANA := "Sin maná"
const OUT_OF_RANGE := "Fuera de alcance"
const BAD_TARGET := "Blanco inválido"
const NOT_IMPLEMENTED := "No implementado"
const NO_ABILITY := "Sin habilidad"

## sacengine SpellTag.rockForm.
const ROCK_FORM := "dihk"
const RUN_AWAY := "!nur"
const PLAY_DEAD := "dedp"
const STEALTH := "ivni"
const LIFE_SHIELD := "hsba"
const DIVINE_SIGHT := "eesd"
const _SPEEDUP_EFFECT := preload("res://scenes/world/spells/speedup_effect.gd")
## sacengine manaEpsilon (abilityStatus).
const MANA_EPSILON := 0.01
const DEFAULT_STEALTH_S := 5.0
const DEFAULT_PLAY_DEAD_S := 6.0

@export_group("Rockform")
## Baked model of the rock shell (the Rock spell's rock.MRMM).
@export var rock_model := "rock"
@export var rock_scale_factor := 0.55
## sacengine RockForm.numFrames at 60 fps.
@export var rock_grow_s := 0.5
@export var rock_color := Color(0.42, 0.4, 0.34)
@export_group("Active effects")
## F126: which tag has an AbilityEffect scene of its own (Protector); a tag that is not there keeps the branches below.
@export var catalog: AbilityCatalog
@export var stealth_alpha := 0.25

var ability: AbilityType
## A guardian has no active ability (activeAbility, state.d:1414). GuardianBond sets it.
var locked := false

var _body: Node3D
var _mana: Node
var _cooldown := 0.0
var _shell: MeshInstance3D
var _shell_tween: Tween
var _play_dead_left := 0.0
var _stealth_left := 0.0
## F126: the AbilityEffect of this ability (instanced from the catalog), or null.
var _effect: AbilityEffect


func setup(body: Node3D, creature: CreatureType, mana: Node) -> void:
	_body = body
	_mana = mana
	ability = GameData.ability(creature.active_ability_tag) if creature and not creature.active_ability_tag.is_empty() else null
	var scene := catalog.scene_for(ability.tag) if catalog and ability else null
	if scene:
		_effect = scene.instantiate() as AbilityEffect
		_effect.name = "Effect"
		_effect.setup(body, ability)
		add_child(_effect)


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _play_dead_left > 0.0:
		_play_dead_left = maxf(0.0, _play_dead_left - delta)
		if _play_dead_left == 0.0 and _body and _body.has_method("set_playing_dead"):
			_body.call("set_playing_dead", false)
	if _stealth_left > 0.0:
		_stealth_left = maxf(0.0, _stealth_left - delta)
		if _stealth_left == 0.0 and _body and _body.has_method("set_stealth"):
			_body.call("set_stealth", false)


func display_name() -> String:
	return ability.display_name if ability else ""


func cooldown_left() -> float:
	return _cooldown


## "" = ready. Clients see the replicated mana, not the cooldown: the server checks again.
func status(target_pos: Vector3, target: Node3D) -> String:
	if ability == null or locked:
		return NO_ABILITY
	if _effect == null and not [ROCK_FORM, RUN_AWAY, PLAY_DEAD, STEALTH, LIFE_SHIELD, DIVINE_SIGHT].has(ability.tag):
		return NOT_IMPLEMENTED
	if _cooldown > 0.0:
		return COOLING
	if maxf(1.0, float(ability.mana_cost)) > _mana_left() + MANA_EPSILON:
		return NO_MANA
	if _effect:
		return _effect.status(target_pos, target)
	match ability.tag:
		ROCK_FORM:
			if _body.call("is_rock_form"):
				return BAD_TARGET
		RUN_AWAY:
			var speeding := _body.get_node_or_null("SpeedupEffect") != null
			if speeding:
				return BAD_TARGET
		PLAY_DEAD:
			if _play_dead_left > 0.0:
				return BAD_TARGET
		STEALTH:
			if _stealth_left > 0.0:
				return BAD_TARGET
		LIFE_SHIELD:
			var shield := LifeShield.of(_body)
			if shield == null or shield.is_on():
				return BAD_TARGET
		DIVINE_SIGHT:
			if target == null:
				return BAD_TARGET
			if _body.global_position.distance_to(target_pos) > ability.cast_range:
				return OUT_OF_RANGE
	return ""


## Server or solo. Returns "" when used, else the reason.
func use(target_pos: Vector3, target: Node3D) -> String:
	var reason := status(target_pos, target)
	if not reason.is_empty():
		return reason
	var before := _mana_left()
	if _effect:
		if not _effect.fire(target_pos, target):
			return BAD_TARGET
	else:
		_apply(target)
	_mana.call("spend", maxf(1.0, float(ability.mana_cost)))
	_cooldown = ability.cooldown_s
	print("habilidad %s mana %d->%d" % [ability.display_name, roundi(before), roundi(_mana_left())])
	return ""


func _apply(target: Node3D) -> void:
	match ability.tag:
		ROCK_FORM:
			_body.call("enter_rock_form")
			FxBus.broadcast("rock_emerge", _body.global_position + Vector3.UP * 0.5)
		RUN_AWAY:
			_apply_run_away()
		PLAY_DEAD:
			_apply_play_dead()
		STEALTH:
			_apply_stealth()
		LIFE_SHIELD:
			LifeShield.of(_body).start_for(ability)
			FxBus.broadcast("heal", _body.global_position + Vector3.UP)
		DIVINE_SIGHT:
			_apply_divine_sight(target)


## Every peer, from UnitBody's mode setter.
func show_rock_form(on: bool) -> void:
	if on and _shell == null:
		_shell = MeshInstance3D.new()
		_shell.name = "RockShell"
		_shell.mesh = BodyLibrary.mesh(rock_model)
		if _shell.mesh == null:
			var ball := SphereMesh.new()
			_shell.mesh = ball
			var mat := StandardMaterial3D.new()
			mat.albedo_color = rock_color
			mat.roughness = 1.0
			_shell.material_override = mat
		_body.add_child(_shell)
	if _shell == null:
		return
	var profile: Dictionary = _body.call("melee_profile")
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


func _mana_left() -> float:
	return float(_mana.get("current")) if _mana else 0.0


func _apply_run_away() -> void:
	if _body.get_node_or_null(_SPEEDUP_EFFECT.NODE_NAME) != null:
		return
	var effect: Node = _SPEEDUP_EFFECT.new()
	effect.name = _SPEEDUP_EFFECT.NODE_NAME
	effect.call("start", maxf(ability.duration, 1.0))
	_body.add_child(effect)
	if _body.has_method("halt"):
		_body.call("halt")
	FxBus.broadcast("speedup", _body.global_position + Vector3.UP)


func _apply_play_dead() -> void:
	_play_dead_left = maxf(ability.duration, DEFAULT_PLAY_DEAD_S)
	if _body.has_method("set_playing_dead"):
		_body.call("set_playing_dead", true)
	FxBus.broadcast("dirt", _body.global_position + Vector3.UP * 0.3)


func _apply_stealth() -> void:
	_stealth_left = maxf(ability.duration, DEFAULT_STEALTH_S)
	if _body.has_method("set_stealth"):
		_body.call("set_stealth", true)
	FxBus.broadcast("spit_trail", _body.global_position + Vector3.UP)


func _apply_divine_sight(target: Node3D) -> void:
	if target and target.has_method("set_stealth"):
		target.call("set_stealth", false)
	if target and target.has_method("clear_special_states"):
		target.call("clear_special_states")
	FxBus.broadcast("spit_rock", _body.global_position + Vector3.UP)
	if target:
		FxBus.broadcast("spit_dirt", target.global_position + Vector3.UP * 0.5)
