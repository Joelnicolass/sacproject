class_name AiFutileTargets
extends RefCounted

## The bodies the wizard's attack spells do not bring down: each attack cast on a body is noted with the health the side knew,
## and a body that lost too little since the last one is banned as a spell target for `spell_futile_forget_s`. It does not
## cast and it does not rate: Casting notes the casts, the attack phase asks `is_futile`. RFC-053.

var perception: AiPerception
var port: AiCommandPort
var tactics: AiTactics
## Diagnostic: bodies banned as futile spell targets.
var futile_bans := 0
## Track id -> [the health the side knew at the last cast, tick its ban ends or 0].
var _attack_marks: Dictionary = {}


func _init(p_perception: AiPerception, p_port: AiCommandPort, p_tactics: AiTactics) -> void:
	perception = p_perception
	port = p_port
	tactics = p_tactics


## A body the side's attack spells do not bring down is not a spell target until its ban ends.
func is_futile(target: AiTrack) -> bool:
	var mark: Array = _attack_marks.get(target.id, [])
	if mark.is_empty() or int(mark[1]) == 0:
		return false
	if port.now_tick() < int(mark[1]):
		return true
	_attack_marks.erase(target.id)
	return false


## An attack spell started on a body: if what it lost since the last one (the health the side knows), spell_kill_max_casts times over,
## would not bring it down, it is banned for spell_futile_forget_s.
func note_cast(spell: Resource, target: AiTrack) -> void:
	if tactics == null or tactics.spell_futile_forget_s <= 0.0 or target == null or not target.is_body():
		return
	if not (spell is SpellType) or (spell as SpellType).is_structure or not AiSpellEval.casts_in(spell as SpellType, SpellType.AiPhase.ATTACK):
		return
	var health := perception.health_of(target)
	var mark: Array = _attack_marks.get(target.id, [])
	if DebugLog.on(&"ai_attack"):
		print("ai_attack slot %d hechizo %s sobre %s: vida conocida %d de %d, antes %s, ve %s" % [perception.slot, (spell as SpellType).tag,
			target.node.name, health.x, health.y, str(mark[0]) if not mark.is_empty() else "-", str(perception.knows_live(target))])
	if not mark.is_empty() and health.y > 0 and (int(mark[0]) - health.x) * tactics.spell_kill_max_casts < health.x:
		mark[1] = port.now_tick() + MatchClock.ticks_for(tactics.spell_futile_forget_s)
		futile_bans += 1
		if DebugLog.on(&"ai_attack"):
			print("ai_attack slot %d hechizo inutil sobre %s: vida %d antes %d de %d" % [perception.slot, target.node.name, health.x,
				int(mark[0]), health.y])
	else:
		mark = [health.x, 0]
	mark[0] = health.x
	_attack_marks[target.id] = mark
