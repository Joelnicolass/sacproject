extends Node

## RFC-036 036d: MatchRules.max_creatures_per_player. With a cap of 3 the 4th summon of the local
## wizard is refused with «Límite de criaturas» and costs no mana nor souls; after one creature
## dies a new summon works. Drives Caster.request_summon, the call the creature_1 action makes.
## Prints `CREATURE_CAP PASS` or `CREATURE_CAP FAIL <reason>` and quits.

const LIMIT_TEXT := "Límite de criaturas"
const SLOT := 1
const MAX_WAIT_FRAMES := 1800

var _feedback: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _wizard() -> Node3D:
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) == SLOT:
			return wizard as Node3D
	return null


func _mine() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for unit in get_tree().get_nodes_in_group(&"unit"):
		if int(unit.get("owner_slot")) == SLOT and not unit.call("is_dead"):
			out.append(unit)
	return out


## Waits until the cast has ended and the creature_1 cooldown is over.
func _settle(caster: Node) -> void:
	for _i in MAX_WAIT_FRAMES:
		await get_tree().physics_frame
		if not caster.is_casting() and float(caster.spellbook.creature_cooldown(0)) <= 0.0:
			return


func _finish(ok: bool, reason: String) -> void:
	print("CREATURE_CAP %s" % ("PASS" if ok else "FAIL %s" % reason))
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	await _frames(30)
	var wizard := _wizard()
	if wizard == null:
		_finish(false, "no wizard in slot %d" % SLOT)
		return
	var caster = wizard.get_node("Caster")
	caster.feedback.connect(func(text: String) -> void: _feedback.append(text))
	var tag: String = caster.spellbook.creature_at(0).tag
	var before := _mine().size()
	for i in 3:
		caster.request_summon(tag)
		await _settle(caster)
	var ok_three := _mine().size() == before + 3 and not _feedback.has(LIMIT_TEXT)
	if not ok_three:
		_finish(false, "first three summons: %d creatures, feedback %s" % [_mine().size() - before, _feedback])
		return
	var mana: float = caster._mana()
	var souls: int = caster._souls()
	_feedback.clear()
	caster.request_summon(tag)
	await _frames(5)
	if _feedback != [LIMIT_TEXT]:
		_finish(false, "4th summon feedback %s" % [_feedback])
		return
	if not is_equal_approx(caster._mana(), mana) or caster._souls() != souls or _mine().size() != before + 3:
		_finish(false, "4th summon cost: mana %s -> %s, souls %d -> %d, creatures %d" % [mana, caster._mana(), souls, caster._souls(), _mine().size() - before])
		return
	_mine()[0].get_node("Health").call("damage", 1.0e9, 2)
	await _frames(5)
	if _mine().size() != before + 2:
		_finish(false, "a dead creature still counts: %d" % (_mine().size() - before))
		return
	await _settle(caster)
	_feedback.clear()
	caster.request_summon(tag)
	await _settle(caster)
	if _feedback.has(LIMIT_TEXT) or _mine().size() != before + 3:
		_finish(false, "summon after a death: %d creatures, feedback %s" % [_mine().size() - before, _feedback])
		return
	_finish(true, "")
