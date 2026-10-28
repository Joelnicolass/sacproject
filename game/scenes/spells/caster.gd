@tool
class_name Caster
extends Node

## Casts the wizard's book. The owner calls request_cast() or
## request_summon(); in a networked match the server validates the slot and runs the cast.
## Spells check mana, target, range, then cooldown (a cooling spell answers «Enfriando» even
## without mana). Creatures check souls, mana, then cooldown, and need no target: the
## Summoner puts them in front of the wizard when the cast starts. Starting sets every
## cooldown, then mana drains at cast_drain_per_s during the casting frames.
## Every spell of the book (combat or structure) is a SpellAction child of `actions`, instanced from `SpellType.action` and found by `spell`:
## Caster does the common part and asks the action to check, begin, start, finish and cancel. A creature needs
## no action: the Summoner puts it in front of the wizard when the cast starts and finishes it when it ends.

signal feedback(text: String)
## A cast began (`casting` true; `fx` is the particle of the hands, null for a god without one) or ended or was cut (false, null).
## Every peer emits it, from the replicated `cast_fx_shown`: HandFx, WizardSounds, Ward and the pose follow it.
signal cast_changed(casting: bool, fx: ParticleType)

## Mana tolerance.
const MANA_EPSILON := 0.01
## Every spell costs at least this much: cost = max(1, cost).
const MIN_MANA_COST := 1.0
## `cast_fx_shown` of a cast without a particle (a god without one): the pose and the incantation still follow it.
const BARE := "-"

@export var rules: MatchRules
@export var spellbook: Spellbook
@export var summoner: Summoner
## Holds the SpellAction children. Without it, or without the child, the spell answers «No implementado».
@export var actions: Node
## The wizard that owns this node (set in wizard_body.tscn).
@export var wizard: WizardBody

## SpellType or CreatureType being cast.
var _entry: BookEntry
var _target: Node3D
var _frames_left := 0
var _drain_left := 0
var _drain_per_frame := 0.0
## The action whose cast is running, or null.
var _active: SpellAction
## What `cast_fx_shown` says while the cast in progress lasts (an FxWire id or BARE), taken when it starts.
var _shown_id := ""

## The cast in progress as every peer sees it: the FxWire id of the hands' particle, BARE without one, "" while idle. The server
## writes it and the body's synchronizer replicates it; nothing in the simulation reads it. Presentation only.
@export var cast_fx_shown := "":
	set(value):
		if value == cast_fx_shown:
			return
		cast_fx_shown = value
		cast_changed.emit(not value.is_empty(), cast_fx())


func _get_configuration_warnings() -> PackedStringArray:
	if wizard == null:
		return PackedStringArray(["Assign `wizard`: the WizardBody that owns this node."])
	return PackedStringArray()


func _ready() -> void:
	if not Engine.is_editor_hint() and wizard == null:
		push_error("%s: `wizard` is empty." % get_path())


## A cast is in progress: the server knows the entry; a client reads the replicated `cast_fx_shown`.
func is_casting() -> bool:
	return _entry != null or not cast_fx_shown.is_empty()


## The particle the hands throw now, or null (idle, or a cast without one). Every peer.
func cast_fx() -> ParticleType:
	if cast_fx_shown.is_empty() or cast_fx_shown == BARE:
		return null
	return FxWire.resource(cast_fx_shown) as ParticleType


## Only an idle or moving wizard, not a dying or ghost one.
func wizard_can_cast() -> bool:
	return wizard.can_cast()


## Can the spell be armed? &"" = yes, else a Refusal key.
func arm_status(index: int) -> StringName:
	var spell := spellbook.spell_at(index)
	if spell == null:
		return Refusal.BAD_TARGET
	if action_for(spell.tag) == null:
		return Refusal.NOT_IMPLEMENTED
	var status := &""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = Refusal.NO_MANA
	if spellbook.cooldown(index) > 0.0:
		status = Refusal.COOLING
	return status


## Can the creature be summoned now? &"" = yes, else a Refusal key.
func summon_status(index: int) -> StringName:
	var type := spellbook.creature_at(index)
	if type == null:
		return Refusal.BAD_TARGET
	if summoner == null or not summoner.can_summon(type):
		return Refusal.NOT_IMPLEMENTED
	var status := &""
	if type.souls > _souls():
		status = Refusal.NO_SOULS
	elif _cost(type) > _mana() + MANA_EPSILON:
		status = Refusal.NO_MANA
	if spellbook.creature_cooldown(index) > 0.0:
		status = Refusal.COOLING
	if at_creature_limit():
		status = Refusal.CREATURE_LIMIT
	return status


## True when the wizard's side already owns rules.max_creatures_per_player live
## creatures (0 = no cap). Counts the creatures of the wizard's slot that are not dead, including
## one still being summoned; the wizard itself and NPCs (slot 0) are not units of that slot.
func at_creature_limit() -> bool:
	var cap := rules.max_creatures_per_player if rules != null else 0
	if cap <= 0:
		return false
	var slot := wizard.owner_slot
	var count := 0
	for unit in get_tree().get_nodes_in_group(UnitBody.GROUP):
		if unit.get("owner_slot") == slot and unit is UnitBody and not (unit as UnitBody).is_dead():
			count += 1
	return count >= cap


## Can this structure entry be armed? &"" = yes, else a Refusal key.
func structure_status(index: int) -> StringName:
	var spell := spellbook.structure_at(index)
	if spell == null or not spell.is_structure:
		return Refusal.BAD_TARGET
	var action := action_for(spell.tag)
	if action == null:
		return Refusal.NOT_IMPLEMENTED
	var status := action.arm_status(wizard, spell)
	if not status.is_empty():
		return status
	return _funds(spell)


## The Caster of `node`, or null (a body that casts nothing).
static func of(node: Node) -> Caster:
	for child in node.get_children() if node else []:
		if child is Caster:
			return child
	return null


## The action of the spell `tag`, or null (the spell is not implemented). The scene in the SpellType's `action` is instanced
## under `actions` the first time and kept; its `spell` says which spell it casts.
func action_for(tag: String) -> SpellAction:
	if actions == null:
		return null
	var spell := _spell_of(tag)
	if spell == null or spell.action == null:
		return null
	for child in actions.get_children():
		if child is SpellAction and not child.is_queued_for_deletion() and (child as SpellAction).spell == spell:
			return child
	var made := spell.action.instantiate() as SpellAction
	if made == null:
		return null
	made.spell = spell
	actions.add_child(made)
	return made


## Read only: where a cast of the spell `tag` would land at `point` / `picked`, or why it would not start (`status`). The one answer
## `_try_action`, the AI and the armed preview share: a preview and the server never disagree on the same state.
func aim_for(tag: String, point: Vector3, picked: Node3D) -> SpellAction.Aim:
	var action := action_for(tag)
	var spell := _spell_of(tag)
	var aim := SpellAction.Aim.new()
	aim.status = Refusal.BAD_TARGET if action == null or spell == null else action.arm_status(wizard, spell)
	return aim if not aim.status.is_empty() else action.check(wizard, spell, point, picked, _funds(spell))


## Read only: aim_for(...).status ("" = it would start).
func action_status(tag: String, point: Vector3, picked: Node3D) -> String: return aim_for(tag, point, picked).status


## The cast in progress keeps the wizard standing (a structure): WizardBody neither walks nor turns while it is true. Server or solo.
func holds_wizard() -> bool: return _active != null and _active.stationary


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
	if not MpAuthority.accept_command(self, wizard.owner_slot):
		return 0
	return multiplayer.get_remote_sender_id()


## "" = refused without a word (a dying or ghost wizard cannot start a cast).
func _report(text: String) -> void:
	if not text.is_empty():
		feedback.emit(text)


## Server or solo: tells the owner something that happened after the request answered.
func _tell_owner(text: String) -> void:
	if MpKit.is_networked() and MpKit.is_server():
		var peer := MpKit.peer_id_for(wizard.owner_slot)
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
		return Refusal.NOT_IMPLEMENTED if spellbook.spell_by_tag(tag) != null else Refusal.BAD_TARGET
	var spell := _spell_of(tag)
	if spell == null:
		return Refusal.BAD_TARGET
	if is_casting():
		return Refusal.CASTING
	return _try_action(action, spell, point, path)


## Server or solo. Returns the creature name when the summon starts, or the reason it did not.
func _try_summon(tag: String) -> String:
	var index := spellbook.creature_index_of(tag)
	var type := spellbook.creature_at(index)
	if not wizard_can_cast():
		return ""
	if type == null:
		return Refusal.BAD_TARGET
	if is_casting():
		return Refusal.CASTING
	var status := summon_status(index)
	if not status.is_empty():
		return status
	var unit := summoner.begin(type)
	if unit == null:
		return Refusal.OCCUPIED
	_start(type, unit)
	return type.display_name


## Server or solo. Returns the structure name when the cast starts.
func _try_structure(index: int, point: Vector3) -> String:
	var spell := spellbook.structure_at(index)
	if not wizard_can_cast():
		return ""
	if spell == null or not spell.is_structure:
		return Refusal.BAD_TARGET
	if is_casting():
		return Refusal.CASTING
	var action := action_for(spell.tag)
	if action == null:
		return Refusal.NOT_IMPLEMENTED
	return _try_action(action, spell, point, NodePath())


## Server or solo. Runs the shared steps of a spell that has a SpellAction: it can be armed, it
## aims (the action's own checks), the cast starts. Returns the spell name or the reason.
func _try_action(action: SpellAction, spell: SpellType, point: Vector3, path: NodePath) -> String:
	var picked := get_node_or_null(path) as Node3D if not path.is_empty() else null
	var aim := aim_for(spell.tag, point, picked)
	if not aim.status.is_empty():
		return aim.status
	action.begin(wizard, spell, aim)
	_active = action
	var frames := _start(spell, aim.target)
	action.started(wizard, spell, aim, frames)
	return spell.display_name


## Takes the cast: counts the casting frames and the drain, sets the cooldowns. Returns the casting frames.
func _start(entry: BookEntry, target: Node3D) -> int:
	# The wizard level shortens the cast (CastTime).
	var frames := floori(MatchClock.TICKS_PER_SECOND_F * CastTime.seconds(entry, wizard.level))
	var cost := _cost(entry)
	_entry = entry
	_target = target
	_frames_left = frames
	_drain_left = mini(frames, ceili(cost * MatchClock.TICKS_PER_SECOND_F / rules.cast_drain_per_s))
	_drain_per_frame = cost / float(maxi(_drain_left, 1))
	spellbook.apply_cooldown(entry.tag)
	_shown_id = _cast_fx_id()
	var verb := "convoca" if entry is CreatureType else "lanza"
	print("%s %s slot %d" % [verb, entry.display_name, wizard.owner_slot])
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
	cast_fx_shown = _shown_id
	_frames_left -= 1
	if _frames_left <= 0:
		_finish()


## The wizard died, or was stunned or petrified, while casting: the spell does not land and a creature being
## summoned goes.
func _interrupt() -> void:
	print("cast cut %s slot %d" % [_entry.display_name, wizard.owner_slot])
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
		var text := summoner.finish(target, entry as CreatureType)
		if not text.is_empty():
			_tell_owner(text)
		return
	var spell := entry as SpellType
	if _active != null:
		var action := _active
		_active = null
		var text := action.finish(wizard, spell, target)
		if not text.is_empty():
			_tell_owner(text)


## The id of the hands' particle: the action's own (Rock throws dirt, Wrath its sparks), else the god's, a summon included (a
## creature only comes out of its god's book). BARE when there is none.
func _cast_fx_id() -> String:
	var fx: ParticleType = _active.cast_fx if _active != null else null
	if fx == null and wizard.god_type != null:
		fx = wizard.god_type.cast_fx
	var id := FxWire.id_of(fx) if fx != null else ""
	return id if not id.is_empty() else BARE


## The spell of the book by tag, from either tab, or null.
func _spell_of(tag: String) -> SpellType:
	var spell := spellbook.structure_by_tag(tag)
	if spell == null:
		spell = spellbook.spell_by_tag(tag)
	return spell


## Mana and cooldown of a spell with an action: "", Refusal.NO_MANA, or Refusal.COOLING (which wins).
func _funds(spell: SpellType) -> String:
	var status := ""
	if _cost(spell) > _mana() + MANA_EPSILON:
		status = Refusal.NO_MANA
	var index := spellbook.structure_index_of(spell.tag)
	var cooldown := spellbook.structure_cooldown(index) if index >= 0 else 0.0
	if index < 0:
		index = spellbook.index_of(spell.tag)
		cooldown = spellbook.cooldown(index) if index >= 0 else 0.0
	if cooldown > 0.0:
		status = Refusal.COOLING
	return status


func _cost(entry: BookEntry) -> float:
	return maxf(MIN_MANA_COST, float(entry.mana_cost))


func _mana() -> float:
	return wizard.mana.current


func _souls() -> int:
	return wizard.souls.count


func _spend(amount: float) -> void:
	wizard.mana.spend(minf(amount, wizard.mana.current))
