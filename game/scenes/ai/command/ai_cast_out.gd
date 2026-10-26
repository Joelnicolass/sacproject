class_name AiCastOut
extends RefCounted

## The call a human's click makes, for the AI's wizard: Caster.request_cast / request_summon / request_structure, and what the
## Caster answered, to the audit. A body of another side the side does not see now is never clicked. It does not decide when
## (AiCommandPort: delay, timing) and it never touches a body. Ref: shiny.d:3247-3254 startCasting.

var slot := 0
var wizard: WizardBody
var caster: Caster
## Casts that took the real body of a body of another side the side did not see (a guard: no difficulty aims at one, stays 0).
var unseen_target_reads := 0
var _units_root: Node
var _answers: Array[String] = []


func bind(side_slot: int, wizard_body: WizardBody, units_root: Node) -> void:
	slot = side_slot
	wizard = wizard_body
	_units_root = units_root
	caster = AiBody.caster(wizard_body)
	caster.feedback.connect(_on_feedback)


func _on_feedback(text: String) -> void:
	_answers.append(text)


## Returns the answer of the Caster: the spell's name when it starts, or the reason it did not ("" = refused without a word).
func request(spell: Resource, target: AiTrack, point: Vector3, audit: AiAudit, perception: AiPerception) -> String:
	_answers.clear()
	var before := {"mana": AiBody.mana_now(wizard), "souls": AiBody.souls(wizard)}
	var tag := str(spell.get("tag"))
	var is_summon := spell is CreatureType
	if not is_summon and AiCommandPort.unseen(perception, target):
		if not AiCommandPort.aims(perception, target):
			return ""
		unseen_target_reads += 1
	if is_summon:
		caster.request_summon(tag)
	elif spell is SpellType and bool((spell as SpellType).is_structure) and target != null and target.is_valid():
		## Convert and Desecrate click a soul or a creature (the structures tab gives the spell, the click the target): the same
		## `request_cast` a human's click makes. A structure with no target (Manalith: the ground) goes by its entry of the tab.
		caster.request_cast(tag, target.node.global_position, target.node)
	elif spell is SpellType and bool((spell as SpellType).is_structure):
		caster.request_structure(AiBody.spellbook(wizard).structure_index_of(tag), point)
	else:
		var node: Node3D = target.node if target != null and target.is_valid() else null
		caster.request_cast(tag, node.global_position if node != null else point, node)
	var answer := _answers[0] if not _answers.is_empty() else ""
	var name := str(spell.get("display_name"))
	var started := answer == name
	if audit != null:
		audit.note_request(slot, tag, name, started, answer, before, is_summon, _new_summoned_unit(tag) if (is_summon and started) else null, target.node if target != null else null, spell as CreatureType)
	return answer


## The creature the Summoner just put in front of the wizard (translucent until the cast ends).
func _new_summoned_unit(tag: String) -> Node:
	if _units_root == null or _units_root.get_child_count() == 0:
		return null
	var unit := _units_root.get_child(_units_root.get_child_count() - 1)
	if str(unit.get("creature_tag")) == tag and int(unit.get("owner_slot")) == slot:
		return unit
	return null
