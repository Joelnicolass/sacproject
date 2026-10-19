class_name Caster
extends Node

## Casts the wizard's book (sacengine startCasting). The owner calls request_cast() or
## request_summon(); in a networked match the server validates the slot and runs the cast.
## Spells check mana, target, range, then cooldown (a cooling spell answers «Enfriando» even
## without mana). Creatures check souls, mana, then cooldown, and need no target: the
## Summoner puts them in front of the wizard when the cast starts. Starting sets every
## cooldown, then mana drains at cast_drain_per_s during the casting frames.
## Every spell of the book (combat or structure) is a SpellAction child of `actions`, found by tag (RFC-041):
## Caster does the common part and asks the action to check, begin, start, finish and cancel. A creature needs
## no action: the Summoner puts it in front of the wizard when the cast starts and finishes it when it ends.

signal feedback(text: String)
## The cast particle that is showing changed: "" when the wizard is not casting (RFC-023 023d). Every peer emits it.
signal cast_fx_changed(type_name: String)

## sacengine updateFPS: casting and drain are counted in frames.
const FPS := 60.0
## sacengine manaEpsilon.
const MANA_EPSILON := 0.01
## sacengine SacSpell: manaCost = max(1, manaCost).
const MIN_MANA_COST := 1.0
const NO_MANA := SpellAction.NO_MANA
const NO_SOULS := Refusal.NO_SOULS
const COOLING := SpellAction.COOLING
const OUT_OF_RANGE := SpellAction.OUT_OF_RANGE
const BAD_TARGET := SpellAction.BAD_TARGET
const NOT_IMPLEMENTED := SpellAction.NOT_IMPLEMENTED
const BUSY := Refusal.CASTING
const NO_ROOM := SpellAction.NO_ROOM
## RFC-036 036d: MatchRules.max_creatures_per_player reached.
const CREATURE_LIMIT := Refusal.CREATURE_LIMIT

@export var rules: MatchRules
@export var spellbook: Spellbook
@export var summoner: Summoner
## Holds the SpellAction children. Without it, or without the child, the spell answers «No implementado».
@export var actions: Node

## SpellType or CreatureType being cast.
var _entry: Resource
var _target: Node3D
var _frames_left := 0
var _drain_left := 0
var _drain_per_frame := 0.0
## The action whose cast is running, or null.
var _active: SpellAction

## RFC-023 023d: the ParticleType name of the cast in progress ("" while idle). The server sets it and it is replicated, so
## the wizard's hands (HandFx) play the god's casting particle and the body its spellcast pose on every peer. Presentation only.
@export var cast_fx_shown := "":
	set(value):
		if value == cast_fx_shown:
			return
		cast_fx_shown = value
		cast_fx_changed.emit(value)

@onready var _wizard: WizardBody = get_parent()


func is_casting() -> bool:
	return _entry != null


## sacengine canCast (state.d:9520): only an idle or moving wizard, not a dying or ghost one.
func wizard_can_cast() -> bool:
	return _wizard.can_cast()


## Can the spell be armed? (sacengine selectSpell: mana, then cooldown.) "" = yes.
func arm_status(index: int) -> String:
	var spell := spellbook.spell_at(index)
	if spell == null:
		return BAD_TARGET
	if action_for(spell.tag) == null:
		return NOT_IMPLEMENTED
	var status := ""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = NO_MANA
	if spellbook.cooldown(index) > 0.0:
		status = COOLING
	return status


## Can the creature be summoned now? (sacengine spellStatus: souls, mana, then cooldown.) "" = yes.
func summon_status(index: int) -> String:
	var type := spellbook.creature_at(index)
	if type == null:
		return BAD_TARGET
	if summoner == null or not summoner.can_summon(type):
		return NOT_IMPLEMENTED
	var status := ""
	if type.souls > _souls():
		status = NO_SOULS
	elif _cost(type) > _mana() + MANA_EPSILON:
		status = NO_MANA
	if spellbook.creature_cooldown(index) > 0.0:
		status = COOLING
	if at_creature_limit():
		status = CREATURE_LIMIT
	return status


## RFC-036 036d. True when the wizard's side already owns rules.max_creatures_per_player live
## creatures (0 = no cap). Counts the creatures of the wizard's slot that are not dead, including
## one still being summoned; the wizard itself and NPCs (slot 0) are not units of that slot.
func at_creature_limit() -> bool:
	var cap := rules.max_creatures_per_player if rules != null else 0
	if cap <= 0:
		return false
	var slot := int(_wizard.get("owner_slot"))
	var count := 0
	for unit in get_tree().get_nodes_in_group(&"unit"):
		if unit.get("owner_slot") == slot and unit is UnitBody and not (unit as UnitBody).is_dead():
			count += 1
	return count >= cap


## Can this structure entry be armed? "" = yes.
func structure_status(index: int) -> String:
	var spell := spellbook.structure_at(index)
	if spell == null or not bool(spell.is_structure):
		return BAD_TARGET
	var action := action_for(spell.tag)
	if action == null:
		return NOT_IMPLEMENTED
	var status := action.arm_status(_wizard as WizardBody, spell)
	if not status.is_empty():
		return status
	return _funds(spell)


## The action that answers to `tag`, or null (the spell is not implemented). A child of `actions` wins; else the
## scene in the SpellType's `action` is instanced under `actions` the first time (RFC-041).
func action_for(tag: String) -> SpellAction:
	if actions == null:
		return null
	for child in actions.get_children():
		if child is SpellAction and not child.is_queued_for_deletion() and (child as SpellAction).tag == tag:
			return child
	var spell := _spell_of(tag)
	if spell == null or spell.action == null:
		return null
	var made := spell.action.instantiate() as SpellAction
	if made == null:
		return null
	made.tag = tag
	actions.add_child(made)
	return made


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
	var spell := spellbook.structure_at(index)
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
	if not wizard_can_cast():
		return ""
	var action := action_for(tag)
	if action == null:
		return NOT_IMPLEMENTED if spellbook.spell_by_tag(tag) != null else BAD_TARGET
	var spell := _spell_of(tag)
	if spell == null:
		return BAD_TARGET
	if is_casting():
		return BUSY
	return _try_action(action, spell, point, path)


## Server or solo. Returns the creature name when the summon starts, or the reason it did not.
func _try_summon(tag: String) -> String:
	var index := spellbook.creature_index_of(tag)
	var type := spellbook.creature_at(index)
	if not wizard_can_cast():
		return ""
	if type == null:
		return BAD_TARGET
	if is_casting():
		return BUSY
	var status := summon_status(index)
	if not status.is_empty():
		return status
	var unit := summoner.begin(type)
	if unit == null:
		return NO_ROOM
	_start(type, unit)
	return type.display_name


## Server or solo. Returns the structure name when the cast starts.
func _try_structure(index: int, point: Vector3) -> String:
	var spell := spellbook.structure_at(index)
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
	var frames := _start(spell, aim.target)
	action.started(wizard, spell, aim, frames)
	return spell.display_name


func _wizard_level() -> int:
	var value: Variant = _wizard.get("level")
	return int(value) if value != null else 1


## Takes the cast: counts the casting frames and the drain, sets the cooldowns. Returns the casting frames.
func _start(entry: Resource, target: Node3D) -> int:
	## RFC-030 030c: the wizard level shortens the cast (CastTime, sacspell.d castingTime).
	var frames := floori(FPS * CastTime.seconds(entry, _wizard_level()))
	var cost := _cost(entry)
	_entry = entry
	_target = target
	_frames_left = frames
	_drain_left = mini(frames, ceili(cost * FPS / rules.cast_drain_per_s))
	_drain_per_frame = cost / float(maxi(_drain_left, 1))
	spellbook.apply_cooldown(str(entry.get("tag")))
	var verb := "convoca" if entry is CreatureType else "lanza"
	print("%s %s slot %d" % [verb, str(entry.get("display_name")), int(_wizard.get("owner_slot"))])
	return frames


func _physics_process(_delta: float) -> void:
	if _entry == null:
		return
	if not wizard_can_cast():
		_interrupt()
		return
	if _drain_left > 0:
		_drain_left -= 1
		_spend(_drain_per_frame)
	cast_fx_shown = _cast_fx()
	_frames_left -= 1
	if _frames_left <= 0:
		_finish()


## The wizard died, or was stunned or petrified (F138), while casting: the spell does not land and a creature being
## summoned goes.
func _interrupt() -> void:
	print("se corta %s slot %d" % [str(_entry.get("display_name")), int(_wizard.get("owner_slot"))])
	if _entry is CreatureType and is_instance_valid(_target):
		_target.queue_free()
	if _active != null:
		_active.cancel()
		_active = null
	_entry = null
	_target = null
	cast_fx_shown = ""


func _finish() -> void:
	var entry := _entry
	var target := _target if is_instance_valid(_target) else null
	_entry = null
	_target = null
	cast_fx_shown = ""
	if entry is CreatureType:
		var text := summoner.finish(target, entry)
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


## The cast particle of the action (Rock throws dirt, Wrath its own sparks: state.d:16386, 16707); the rest
## use the god's casting particle.
func _cast_fx() -> String:
	if _active != null and not _active.cast_fx.is_empty():
		return _active.cast_fx
	var god_type: GodType = GameCatalog.shared().god(_cast_god())
	return god_type.cast_fx_name() if god_type != null else "cast_%s" % _cast_god()


## sacengine animateCreatureCasting: the creature's god, else the wizard's.
func _cast_god() -> String:
	var god := str(_entry.get("god")) if _entry is CreatureType else ""
	if god.is_empty() or god == "none":
		god = str(_wizard.get("god"))
	return god


## The spell of the book by tag, from either tab, or null.
func _spell_of(tag: String) -> SpellType:
	var spell := spellbook.structure_by_tag(tag)
	if spell == null:
		spell = spellbook.spell_by_tag(tag)
	return spell


## Mana and cooldown of a spell with an action: "", NO_MANA, or COOLING (which wins).
func _funds(spell: SpellType) -> String:
	var status := ""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = NO_MANA
	var index := spellbook.structure_index_of(spell.tag)
	var cooldown := spellbook.structure_cooldown(index) if index >= 0 else 0.0
	if index < 0:
		index = spellbook.index_of(spell.tag)
		cooldown = spellbook.cooldown(index) if index >= 0 else 0.0
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
	var pool := _wizard.get_node_or_null("ManaPool") as ManaPool
	if pool:
		pool.spend(minf(amount, pool.current))
