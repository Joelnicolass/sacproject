class_name AiCastOut
extends RefCounted

## The call a human's click makes, for the AI's wizard: Caster.request_cast / request_summon / request_structure, and what the
## Caster answered. A body of another side the side does not see now is never clicked. It does not decide when
## (AiCommandPort: delay, timing) and it never touches a body.
## Ref: shiny.d:3247-3254 startCasting

var wizard: WizardBody
var caster: Caster
## Casts that took the real body of a body of another side the side did not see (a guard: no difficulty aims at one, stays 0).
var unseen_target_reads := 0
var _answers: Array[String] = []


func bind(wizard_body: WizardBody) -> void:
	wizard = wizard_body
	caster = AiBody.caster(wizard_body)
	caster.feedback.connect(_on_feedback)


func _on_feedback(text: String) -> void:
	_answers.append(text)


## Returns the answer of the Caster: the spell's name when it starts, or the reason it did not ("" = refused without a word).
func request(spell: Resource, target: AiTrack, point: Vector3, perception: AiPerception) -> String:
	_answers.clear()
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
	return _answers[0] if not _answers.is_empty() else ""


## What the Caster would answer now to the click `request` makes for this cast (Caster.action_status), without casting: "" when it
## would start. A summon has no click to ask about. 055f f5: Casting asks it before every cast.
func status(spell: Resource, target: AiTrack, point: Vector3) -> String:
	if not (spell is SpellType):
		return ""
	var tag := (spell as SpellType).tag
	var node: Node3D = target.node if target != null and target.is_valid() else null
	if (spell as SpellType).is_structure and node == null:
		return caster.action_status(tag, point, null)
	return caster.action_status(tag, node.global_position if node != null else point, node)

