extends Node

## Casts the wizard's book (sacengine startCasting). The owner calls request_cast() or
## request_summon(); in a networked match the server validates the slot and runs the cast.
## Spells check mana, target, range, then cooldown (a cooling spell answers «Enfriando» even
## without mana). Creatures check souls, mana, then cooldown, and need no target: the
## Summoner puts them in front of the wizard when the cast starts. Starting sets every
## cooldown, then mana drains at cast_drain_per_s during the casting frames.
## Speedup works at once; Heal, Wrath and creatures when the casting time ends. Rock rises
## out of the ground while casting and flies when it ends.
## A spell with its own procedure (Manalith…) is a SpellAction child of `actions`, found by tag:
## Caster does the common part and asks the action to check, begin, finish and cancel.

signal feedback(text: String)

const SPEEDUP := "pups"
const HEAL := "laeh"
const ROCK := "kcor"
const WRATH := "oalf"
const FIREBALL := "brif"
const LIGHTNING := "ntil"
const SWARM := "mrws"
const IMPLEMENTED: PackedStringArray = [SPEEDUP, HEAL, ROCK, WRATH, FIREBALL, LIGHTNING, SWARM]
## sacengine updateFPS: casting and drain are counted in frames.
const FPS := 60.0
## sacengine manaEpsilon.
const MANA_EPSILON := 0.01
## sacengine SacSpell: manaCost = max(1, manaCost).
const MIN_MANA_COST := 1.0
## Hands of a wizard, as a fraction of the body height (Wrath leaves from there).
const HAND_HEIGHT := 0.65
const NO_MANA := SpellAction.NO_MANA
const NO_SOULS := "Sin almas"
const COOLING := SpellAction.COOLING
const OUT_OF_RANGE := SpellAction.OUT_OF_RANGE
const BAD_TARGET := SpellAction.BAD_TARGET
const NOT_IMPLEMENTED := SpellAction.NOT_IMPLEMENTED
const BUSY := "Lanzando"
const NO_ROOM := SpellAction.NO_ROOM

const _HEAL_EFFECT := preload("res://scenes/world/spells/heal_effect.gd")
const _SPEEDUP_EFFECT := preload("res://scenes/world/spells/speedup_effect.gd")
const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")
const _HEALTH := preload("res://scenes/world/components/health.gd")

@export var rules: MatchRules
@export var spellbook: Node
@export var summoner: Node
## Holds the SpellAction children (Manalith…). Without it, or without the child, the spell answers «No implementado».
@export var actions: Node

## SpellType or CreatureType being cast.
var _entry: Resource
var _target: Node3D
var _point := Vector3.ZERO
var _frames_left := 0
var _drain_left := 0
var _drain_per_frame := 0.0
var _fx_left := 0.0
## The action whose cast is running, or null.
var _active: SpellAction

@onready var _wizard: Node3D = get_parent()


func is_casting() -> bool:
	return _entry != null


## sacengine canCast (state.d:9520): only an idle or moving wizard, not a dying or ghost one.
func wizard_can_cast() -> bool:
	return not _wizard.has_method("can_cast") or bool(_wizard.call("can_cast"))


## Can the spell be armed? (sacengine selectSpell: mana, then cooldown.) "" = yes.
func arm_status(index: int) -> String:
	var spell: SpellType = spellbook.call("spell_at", index)
	if spell == null:
		return BAD_TARGET
	if not IMPLEMENTED.has(spell.tag):
		return NOT_IMPLEMENTED
	var status := ""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = NO_MANA
	if float(spellbook.call("cooldown", index)) > 0.0:
		status = COOLING
	return status


## Can the creature be summoned now? (sacengine spellStatus: souls, mana, then cooldown.) "" = yes.
func summon_status(index: int) -> String:
	var type: CreatureType = spellbook.call("creature_at", index)
	if type == null:
		return BAD_TARGET
	if summoner == null or not summoner.call("can_summon", type):
		return NOT_IMPLEMENTED
	var status := ""
	if type.souls > _souls():
		status = NO_SOULS
	elif _cost(type) > _mana() + MANA_EPSILON:
		status = NO_MANA
	if float(spellbook.call("creature_cooldown", index)) > 0.0:
		status = COOLING
	return status


## Can this structure entry be armed? "" = yes.
func structure_status(index: int) -> String:
	var spell: SpellType = spellbook.call("structure_at", index)
	if spell == null or not bool(spell.is_structure):
		return BAD_TARGET
	var action := action_for(spell.tag)
	if action == null:
		return NOT_IMPLEMENTED
	var status := action.arm_status(_wizard as WizardBody, spell)
	if not status.is_empty():
		return status
	return _funds(spell)


## The action that answers to `tag`, or null (the spell is not implemented).
func action_for(tag: String) -> SpellAction:
	if actions == null:
		return null
	for child in actions.get_children():
		if child is SpellAction and not child.is_queued_for_deletion() and (child as SpellAction).tag == tag:
			return child
	return null


## Read only: what a cast of the spell `tag` that has an action (Manalith, Convert, Desecrate, Guardian, Teleport) would answer now at
## `point` / `picked`, without casting: "" = it would start. The same steps as `_try_action` up to the start. RFC-024 024e: the AI
## asks it before a request that waited its delay (Easy), so the delay never turns into a refusal.
func action_status(tag: String, point: Vector3, picked: Node3D) -> String:
	var action := action_for(tag)
	var spell := _spell_of(tag)
	if action == null or spell == null:
		return BAD_TARGET
	var wizard := _wizard as WizardBody
	var status := action.arm_status(wizard, spell)
	if not status.is_empty():
		return status
	return action.check(wizard, spell, point, picked, _funds(spell)).status


## The action of an entry of the structures tab, or null.
func structure_action(index: int) -> SpellAction:
	var spell: SpellType = spellbook.call("structure_at", index)
	return action_for(spell.tag) if spell != null else null


## Owner side. `target` is the wizard or creature under the cursor, or null.
func request_cast(tag: String, point: Vector3, target: Node3D) -> void:
	var path := target.get_path() if target else NodePath()
	if MpAuthority.should_send_command():
		submit_cast.rpc_id(MpAuthority.SERVER_PEER, tag, point, path)
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_report(_try_cast(tag, point, path))


## Owner side. The creature appears in front of the wizard; there is no target.
func request_summon(tag: String) -> void:
	if MpAuthority.should_send_command():
		submit_summon.rpc_id(MpAuthority.SERVER_PEER, tag)
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_report(_try_summon(tag))


## Owner side. Structure entries use a ground point.
func request_structure(index: int, point: Vector3) -> void:
	if MpAuthority.should_send_command():
		submit_structure.rpc_id(MpAuthority.SERVER_PEER, index, point)
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_report(_try_structure(index, point))


@rpc("any_peer", "call_remote", "reliable")
func submit_cast(tag: String, point: Vector3, path: NodePath) -> void:
	var sender := _owner_sender()
	if sender > 0:
		_receive_feedback.rpc_id(sender, _try_cast(tag, point, path))


@rpc("any_peer", "call_remote", "reliable")
func submit_summon(tag: String) -> void:
	var sender := _owner_sender()
	if sender > 0:
		_receive_feedback.rpc_id(sender, _try_summon(tag))


@rpc("any_peer", "call_remote", "reliable")
func submit_structure(index: int, point: Vector3) -> void:
	var sender := _owner_sender()
	if sender > 0:
		_receive_feedback.rpc_id(sender, _try_structure(index, point))


@rpc("authority", "call_remote", "reliable")
func _receive_feedback(text: String) -> void:
	_report(text)


## Server only: the RPC sender when it owns this wizard, else 0.
func _owner_sender() -> int:
	if not MpAuthority.accept_command(self, int(_wizard.get("owner_slot"))):
		return 0
	return multiplayer.get_remote_sender_id()


## "" = refused without a word (a dying or ghost wizard: startCasting just fails).
func _report(text: String) -> void:
	if not text.is_empty():
		feedback.emit(text)


## Server or solo: tells the owner something that happened after the request answered.
func _tell_owner(text: String) -> void:
	if MpKit.is_networked() and MpKit.is_server():
		var peer := MpKit.peer_id_for(int(_wizard.get("owner_slot")))
		if peer > 0 and peer != multiplayer.get_unique_id():
			_receive_feedback.rpc_id(peer, text)
			return
	feedback.emit(text)


## Server or solo. Returns the spell name when it starts, or the reason it did not.
func _try_cast(tag: String, point: Vector3, path: NodePath) -> String:
	var index := int(spellbook.call("index_of", tag))
	var spell: SpellType = spellbook.call("spell_at", index)
	if not wizard_can_cast():
		return ""
	var action := action_for(tag)
	if action != null:
		var entry_spell := _spell_of(tag)
		if entry_spell == null:
			return BAD_TARGET
		if is_casting():
			return BUSY
		return _try_action(action, entry_spell, point, path)
	if spell == null:
		return BAD_TARGET
	if not IMPLEMENTED.has(tag):
		return NOT_IMPLEMENTED
	if is_casting():
		return BUSY
	var picked := get_node_or_null(path) as Node3D if not path.is_empty() else null
	var target := _resolve_target(spell, picked)
	var status := ""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = NO_MANA
	elif target == null:
		status = BAD_TARGET
	elif _wizard.global_position.distance_to(target.global_position if target else point) > spell.cast_range:
		status = OUT_OF_RANGE
	if float(spellbook.call("cooldown", index)) > 0.0:
		status = COOLING
	if not status.is_empty():
		return status
	_start(spell, target, point)
	if spell.tag == SPEEDUP:
		_speed_up(target, spell)
	elif spell.tag == ROCK:
		_raise_rock(spell, target)
	elif spell.tag == FIREBALL:
		_throw_fireball(spell, target)
	elif spell.tag == SWARM:
		_throw_swarm(spell, target)
	return spell.display_name


## Server or solo. Returns the creature name when the summon starts, or the reason it did not.
func _try_summon(tag: String) -> String:
	var index := int(spellbook.call("creature_index_of", tag))
	var type: CreatureType = spellbook.call("creature_at", index)
	if not wizard_can_cast():
		return ""
	if type == null:
		return BAD_TARGET
	if is_casting():
		return BUSY
	var status := summon_status(index)
	if not status.is_empty():
		return status
	var unit: Node3D = summoner.call("begin", type)
	if unit == null:
		return NO_ROOM
	_start(type, unit, unit.global_position)
	return type.display_name


## Server or solo. Returns the structure name when the cast starts.
func _try_structure(index: int, point: Vector3) -> String:
	var spell: SpellType = spellbook.call("structure_at", index)
	if not wizard_can_cast():
		return ""
	if spell == null or not bool(spell.is_structure):
		return BAD_TARGET
	if is_casting():
		return BUSY
	var action := action_for(spell.tag)
	if action == null:
		return NOT_IMPLEMENTED
	return _try_action(action, spell, point, NodePath())


## Server or solo. Runs the shared steps of a spell that has a SpellAction: it can be armed, it
## aims (the action's own checks), the cast starts. Returns the spell name or the reason.
func _try_action(action: SpellAction, spell: SpellType, point: Vector3, path: NodePath) -> String:
	var wizard := _wizard as WizardBody
	var status := action.arm_status(wizard, spell)
	if not status.is_empty():
		return status
	var picked := get_node_or_null(path) as Node3D if not path.is_empty() else null
	var aim := action.check(wizard, spell, point, picked, _funds(spell))
	if not aim.status.is_empty():
		return aim.status
	action.begin(wizard, spell, aim)
	_active = action
	_start(spell, aim.target, aim.point)
	return spell.display_name


## Speedup and Heal go to a friendly wizard or creature, else to the caster. Rock and Wrath
## (SPEL flags 8213: wizards, creatures, structures, disallowAlly; no targetGround, so
## sacspell.d isApplicable rejects the ground) need a living enemy body under the cursor.
func _resolve_target(spell: SpellType, picked: Node3D) -> Node3D:
	if spell.tag == ROCK or spell.tag == WRATH or spell.tag == FIREBALL or spell.tag == LIGHTNING or spell.tag == SWARM:
		return picked if picked and not _is_ally(picked) and _ROCK.is_live_body(picked) else null
	var body: Node3D = picked if picked and _is_ally(picked) else null
	if picked == null:
		body = _wizard
	if body == null:
		return null
	if spell.tag == HEAL and body.get_node_or_null("Health") == null:
		return null
	if spell.tag == SPEEDUP and _SPEEDUP_EFFECT.duration_s(body, spell) < 0.0:
		return null
	return body


func _wizard_level() -> int:
	var value: Variant = _wizard.get("level")
	return int(value) if value != null else 1


func _is_ally(body: Node) -> bool:
	return body == _wizard or int(body.get("owner_slot") if "owner_slot" in body else 0) == int(_wizard.get("owner_slot"))


func _start(entry: Resource, target: Node3D, point: Vector3) -> void:
	## RFC-030 030c: the wizard level shortens the cast (CastTime, sacspell.d castingTime).
	var frames := floori(FPS * CastTime.seconds(entry, _wizard_level()))
	var cost := _cost(entry)
	_entry = entry
	_target = target
	_point = point
	_frames_left = frames
	_drain_left = mini(frames, ceili(cost * FPS / rules.cast_drain_per_s))
	_drain_per_frame = cost / float(maxi(_drain_left, 1))
	_fx_left = 0.0
	spellbook.call("apply_cooldown", str(entry.get("tag")))
	var verb := "convoca" if entry is CreatureType else "lanza"
	print("%s %s slot %d" % [verb, str(entry.get("display_name")), int(_wizard.get("owner_slot"))])


func _physics_process(delta: float) -> void:
	if _entry == null:
		return
	if not wizard_can_cast():
		_interrupt()
		return
	if _drain_left > 0:
		_drain_left -= 1
		_spend(_drain_per_frame)
	_fx_left -= delta
	if _fx_left <= 0.0:
		_fx_left = 0.5
		FxBus.broadcast(_cast_fx(), _wizard.global_position + Vector3.UP)
	_frames_left -= 1
	if _frames_left <= 0:
		_finish()


## The wizard died while casting: the spell does not land and a creature being summoned goes.
func _interrupt() -> void:
	if _entry is CreatureType and is_instance_valid(_target):
		_target.queue_free()
	if _active != null:
		_active.cancel()
		_active = null
	_entry = null
	_target = null


func _finish() -> void:
	var entry := _entry
	var target := _target if is_instance_valid(_target) else null
	_entry = null
	_target = null
	if entry is CreatureType:
		var text := str(summoner.call("finish", target, entry))
		if not text.is_empty():
			_tell_owner(text)
		return
	var spell := entry as SpellType
	if _active != null:
		var action := _active
		_active = null
		var text := action.finish(_wizard as WizardBody, spell, target)
		if not text.is_empty():
			_tell_owner(text)
		return
	if spell.tag == HEAL and target and _HEAL_EFFECT.can_heal(target):
		var effect: Node = target.get_node_or_null(_HEAL_EFFECT.NODE_NAME)
		if effect == null:
			effect = _HEAL_EFFECT.new()
			effect.name = _HEAL_EFFECT.NODE_NAME
			target.add_child(effect)
		effect.call("add", float(spell.damage))
		print("cura %d a %s" % [spell.damage, target.name])
	elif spell.tag == WRATH:
		_throw_wrath(spell, target)
	elif spell.tag == LIGHTNING:
		_strike_lightning(spell, target)


## sacengine animateRockCasting throws dirt and animateWrathCasting its own sparks
## (state.d:16386, 16707); the rest use the god's casting particle.
func _cast_fx() -> String:
	if _active != null and not _active.cast_fx.is_empty():
		return _active.cast_fx
	if _entry is SpellType and (_entry as SpellType).tag == ROCK:
		return "dirt_cast"
	if _entry is SpellType and (_entry as SpellType).tag == WRATH:
		return "wrath_cast"
	return "cast_%s" % _cast_god()


## sacengine animateCreatureCasting: the creature's god, else the wizard's.
func _cast_god() -> String:
	var god := str(_entry.get("god")) if _entry is CreatureType else ""
	if god.is_empty() or god == "none":
		god = str(_wizard.get("god"))
	return god


func _speed_up(target: Node3D, spell: SpellType) -> void:
	var seconds := _SPEEDUP_EFFECT.duration_s(target, spell)
	if seconds < 0.0:
		return
	var effect: Node = _SPEEDUP_EFFECT.new()
	effect.name = _SPEEDUP_EFFECT.NODE_NAME
	effect.call("start", seconds)
	target.add_child(effect)
	FxBus.broadcast("speedup", target.global_position + Vector3.UP)


## sacengine castRock: the rock rises out of the ground during the casting frames, then flies.
func _raise_rock(spell: SpellType, target: Node3D) -> void:
	var spawner := get_tree().get_first_node_in_group("spell_spawner")
	if spawner == null:
		return
	var at := _ROCK.cast_position(_wizard)
	var aim := _ROCK.body_center(target)
	spawner.call("spawn_rock", {
		"x": at.x, "y": at.y, "z": at.z,
		"tx": aim.x, "ty": aim.y, "tz": aim.z,
		"target": str(target.get_path()),
		"caster": str(_wizard.get_path()),
		"slot": int(_wizard.get("owner_slot")),
		"speed": spell.speed,
		"acceleration": spell.acceleration,
		"damage": float(spell.damage),
		"cast_frames": _frames_left,
	})


## sacengine updateWrathCasting: the ball leaves from the hands when the casting ends.
## There are no hand bones here: front of the hit box, at hand height.
func _throw_wrath(spell: SpellType, target: Node3D) -> void:
	var spawner := get_tree().get_first_node_in_group("spell_spawner")
	if spawner == null:
		return
	var info := BodyLibrary.info(str(_wizard.get("model")))
	var at := _wizard.global_position + Vector3.UP * float(info.get("height", 1.8)) * HAND_HEIGHT
	if _wizard.has_method("facing_flat"):
		at += (_wizard.call("facing_flat") as Vector3) * float(info.get("reach", 0.5))
	var aim := _ROCK.body_center(target) if target else _point
	spawner.call("spawn_wrath", {
		"x": at.x, "y": at.y, "z": at.z,
		"tx": aim.x, "ty": aim.y, "tz": aim.z,
		"target": str(target.get_path()) if target else "",
		"caster": str(_wizard.get_path()),
		"slot": int(_wizard.get("owner_slot")),
		"speed": spell.speed,
		"acceleration": spell.acceleration,
		"damage": float(spell.damage),
		"damage_range": spell.damage_range,
	})


## sacengine castFireball / updateFireball: same guided spell family as Wrath/Rock, but with
## fireball size 0.5, flying height 0.5 and splash damage at impact.
func _throw_fireball(spell: SpellType, target: Node3D) -> void:
	var spawner := get_tree().get_first_node_in_group("spell_spawner")
	if spawner == null:
		return
	var info := BodyLibrary.info(str(_wizard.get("model")))
	var at := _wizard.global_position + Vector3.UP * float(info.get("height", 1.8)) * HAND_HEIGHT
	if _wizard.has_method("facing_flat"):
		at += (_wizard.call("facing_flat") as Vector3) * float(info.get("reach", 0.5))
	var aim := _ROCK.body_center(target) if target else _point
	spawner.call("spawn_fireball", {
		"x": at.x, "y": at.y, "z": at.z,
		"tx": aim.x, "ty": aim.y, "tz": aim.z,
		"target": str(target.get_path()) if target else "",
		"caster": str(_wizard.get_path()),
		"slot": int(_wizard.get("owner_slot")),
		"speed": spell.speed,
		"acceleration": spell.acceleration,
		"damage": float(spell.damage),
		"damage_range": spell.damage_range,
	})


## sacengine castSwarm / updateSwarm: guided projectile with lower hit size and higher
## flying height than Fireball.
func _throw_swarm(spell: SpellType, target: Node3D) -> void:
	var spawner := get_tree().get_first_node_in_group("spell_spawner")
	if spawner == null:
		return
	var info := BodyLibrary.info(str(_wizard.get("model")))
	var at := _wizard.global_position + Vector3.UP * float(info.get("height", 1.8)) * HAND_HEIGHT
	if _wizard.has_method("facing_flat"):
		at += (_wizard.call("facing_flat") as Vector3) * float(info.get("reach", 0.5))
	var aim := _ROCK.body_center(target) if target else _point
	spawner.call("spawn_swarm", {
		"x": at.x, "y": at.y, "z": at.z,
		"tx": aim.x, "ty": aim.y, "tz": aim.z,
		"target": str(target.get_path()) if target else "",
		"caster": str(_wizard.get_path()),
		"slot": int(_wizard.get("owner_slot")),
		"speed": spell.speed,
		"acceleration": spell.acceleration,
		"damage": float(spell.damage),
		"damage_range": spell.damage_range,
	})


## sacengine castLightning / lightning: instant strike to a valid target.
func _strike_lightning(spell: SpellType, target: Node3D) -> void:
	if target == null or not _ROCK.is_live_body(target):
		return
	var taken := float(target.get_node("Health").call("damage_typed", float(spell.damage), _HEALTH.DIRECT_SPELL, int(_wizard.get("owner_slot"))))
	_ROCK.report(target, taken, _HEALTH.DIRECT_SPELL)
	var center := _ROCK.body_center(target)
	FxBus.broadcast("wrath_explosion1", center)


## The spell of the book by tag, from either tab, or null.
func _spell_of(tag: String) -> SpellType:
	var spell: SpellType = spellbook.call("structure_by_tag", tag)
	if spell == null:
		spell = spellbook.call("spell_by_tag", tag)
	return spell


## Mana and cooldown of a spell with an action: "", NO_MANA, or COOLING (which wins).
func _funds(spell: SpellType) -> String:
	var status := ""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = NO_MANA
	var index := int(spellbook.call("structure_index_of", spell.tag))
	var cooldown := float(spellbook.call("structure_cooldown", index)) if index >= 0 else 0.0
	if index < 0:
		index = int(spellbook.call("index_of", spell.tag))
		cooldown = float(spellbook.call("cooldown", index)) if index >= 0 else 0.0
	if cooldown > 0.0:
		status = COOLING
	return status


func _cost(entry: Resource) -> float:
	return maxf(MIN_MANA_COST, float(entry.get("mana_cost")))


func _mana() -> float:
	var pool := _wizard.get_node_or_null("ManaPool")
	return float(pool.get("current")) if pool else 0.0


func _souls() -> int:
	var purse := _wizard.get_node_or_null("SoulPurse")
	return int(purse.get("count")) if purse else 0


func _spend(amount: float) -> void:
	var pool := _wizard.get_node_or_null("ManaPool")
	if pool:
		pool.call("spend", minf(amount, float(pool.get("current"))))
