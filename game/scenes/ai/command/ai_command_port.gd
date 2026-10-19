class_name AiCommandPort
extends Node

## The only way out of the AI into the game (RFC-024 §3.1 `AiCommandPort`, RULES.md «IA»). Whatever the AI decides becomes
## one of:
##   Caster.request_cast / request_summon / request_structure of its wizard   (the same call a human's click makes), or
##   Orders.apply_for(slot, units, command, point, target)                    (the same validation as a human's order), or
##   WizardBody.request_walk(point)                                            (the same as a click on the ground).
## so the AI pays mana and souls, waits for the cooldowns, and cannot order what is not its own. It never touches a
## body, a pool or a purse. Orders are issued only when they change (orderIfChanged, shiny.d:2393-2431), the radius
## variants hold a position when the body is already close (shiny.d:2433-2457).
## Every request and its answer goes to the audit. Where the game is simulated (solo or the server) only: no RPC.
## 024e (AiDifficulty): with a delay (Easy) every request waits `delay_ticks` between the decision and the call, as a human's hand
## does; a cast that waits keeps the wizard busy, and goes out only if it still can be paid and its target still lives (else it
## lapses, never a refusal). Without perfect information (Easy, Normal) a cast or an order never takes a body of another side the
## side does not see now (the human cannot click it): an order goes to where it was seen last. `unseen_target_reads` counts the
## requests that took the real body or position of an unseen one (only Hard, like the original's startCasting on the entity).

const UnitOrders := preload("res://scenes/units/unit_orders.gd")
## orders.gd has no class_name (other scripts preload it).
const _ORDERS := preload("res://scenes/orders/orders.gd")
## sacengine retreat/guard of a wizard stops this far from the body it goes to (shiny.d:2376, `ntt+0x2e4 + 10.0`).
const WIZARD_STOP_M := 10.0
## Two positions are «the same order» within this squared distance. sacengine compares them exactly (shiny.d:2398); in the port a
## body rests with a jitter of centimeters (BodyAvoidance, the ground), so the exact test would re-issue the order of every
## follower every 12 ticks. 1 m² = 1 m («aprox.»).
const SAME_POS_SQ := 1.0

@export var audit: AiAudit
@export var perception: AiPerception

var slot := 0
var wizard: WizardBody
var orders: Node
var caster: Caster
var orders_issued := 0
## Diagnostic for the report: issued orders by «kind ostate reason» -> [count, microseconds]. «changed»: another ostate or
## target; «moved<3/<10/…»: the same order to a spot that moved (meters; «hold»: the body's own spot; «walking»/«still»:
## the body when it got it); «ended»: the same order again because the live one ended (sacengine re-issues it too).
var order_stats := {}
## Microseconds spent inside the game on behalf of the AI (casts, summons, orders): AiSide subtracts them to report the cost of the decisions.
var game_us := 0
## 024e: physics ticks between a decision and its request (AiDifficulty.request_delay_s); 0 = at once.
var delay_ticks := 0
## The wizard brain's own test (lightCanCast and the rules of the rituals), checked again when a delayed cast leaves: (track, spell, target, point) -> "" or why not.
var can_cast: Callable
## Requests that took the real body or position of a body of another side the side did not see (perfect information only).
var unseen_target_reads := 0
## Delayed requests that did not leave: the cast could no longer be paid or its target died meanwhile.
var lapsed := 0
## "tag reason" -> count of the lapsed casts.
var lapse_reasons := {}
var delayed := 0

var _tick := 0
var _pending_cast := {}
## track id -> {t, ostate, target, pos, due}: one waiting order per body, the newest decision.
var _pending_orders := {}

var _units_root: Node
var _answers: Array[String] = []


func bind(side_slot: int, wizard_body: Node3D, orders_node: Node) -> void:
	slot = side_slot
	wizard = wizard_body
	orders = orders_node
	caster = wizard_body.get_node("Caster") as Caster
	caster.feedback.connect(_on_feedback)
	var spawner := get_tree().get_first_node_in_group("unit_spawner")
	if spawner != null:
		_units_root = spawner.get_node(spawner.spawn_path)


func _on_feedback(text: String) -> void:
	_answers.append(text)


# ---- casting (the call of a human's click) ----

## startCasting of the original (shiny.d:3247-3254). Returns the answer of the Caster: the spell's name when it starts,
## or the reason it did not ("" = refused without a word).
func start_casting(spell: Resource, target: AiTrack, point: Vector3) -> String:
	if delay_ticks > 0:
		_pending_cast = {"spell": spell, "target": target, "point": point, "due": _tick + delay_ticks}
		## the cast is his newest decision: a walk of his still waiting would carry him off it
		if wizard != null:
			_pending_orders.erase(wizard.get_instance_id())
		delayed += 1
		return ""
	var began := Time.get_ticks_usec()
	var answer := _start_casting(spell, target, point)
	game_us += Time.get_ticks_usec() - began
	## the casts and summons go to the same diagnostic table as the orders: «cast <tag>» -> [count, microseconds]
	_note_order("cast " + str(spell.get("tag")), Time.get_ticks_usec() - began)
	return answer


## Physics ticks the side has run (the clock of the delays and of the summon interval of the difficulty).
func now_tick() -> int:
	return _tick


## A cast decided and not yet asked (the delay of the difficulty): the wizard is busy until it leaves.
func cast_pending() -> bool:
	return not _pending_cast.is_empty()


## AiSide calls it at the start of every tick: the requests whose delay is over leave, the cast first, then the orders in the order
## they were decided.
func flush() -> void:
	_tick += 1
	if delay_ticks <= 0:
		return
	if not _pending_cast.is_empty() and int(_pending_cast["due"]) <= _tick:
		var entry := _pending_cast
		_pending_cast = {}
		var target: AiTrack = entry["target"]
		var spell: Resource = entry["spell"]
		var track := perception.find(wizard) if perception != null else null
		var alive := target == null or AiWizardBrain.target_alive(target)
		var refusal := "" if track != null else "sin mago"
		if refusal.is_empty() and can_cast.is_valid():
			refusal = str(can_cast.call(track, spell, target, entry["point"]))
		## the target may have walked out of reach meanwhile (the Caster would answer «Fuera de alcance»)
		var reach := float(spell.get("cast_range")) if spell is SpellType else 0.0
		var aim_ok := target == null or can_aim(target)
		var in_reach := aim_ok and (target == null or not target.is_valid() or reach <= 0.0 \
				or wizard.global_position.distance_to(target.node.global_position) <= reach)
		if not alive:
			refusal = "blanco muerto"
		elif refusal.is_empty() and not in_reach:
			refusal = "fuera de alcance"
		if refusal.is_empty():
			var began := Time.get_ticks_usec()
			_start_casting(spell, target, entry["point"])
			game_us += Time.get_ticks_usec() - began
		else:
			lapsed += 1
			var key := "%s %s" % [str(spell.get("tag")), refusal]
			lapse_reasons[key] = int(lapse_reasons.get(key, 0)) + 1
			if audit != null:
				audit.record("lapse", "slot %d %s" % [slot, key])
	if _pending_orders.is_empty():
		return
	var due: Array = []
	for id in _pending_orders:
		if int(_pending_orders[id]["due"]) <= _tick:
			due.append(id)
	for id in due:
		var entry: Dictionary = _pending_orders[id]
		_pending_orders.erase(id)
		var t: AiTrack = entry["t"]
		if not t.is_valid():
			continue
		var began := Time.get_ticks_usec()
		var goal := _issue(t, int(entry["ostate"]), entry["target"], entry["pos"])
		var spent := Time.get_ticks_usec() - began
		game_us += spent
		_note_order(str(entry["key"]), spent)
		t.ord_pos = goal


## A cast may take `target`: with perfect information always; else a body of another side only while the side sees it.
func can_aim(target: AiTrack) -> bool:
	return perception == null or perception.knows_live(target)


func _unseen_body(target: AiTrack) -> bool:
	return target != null and perception != null and target.is_valid() and not perception.sees(target)


func _start_casting(spell: Resource, target: AiTrack, point: Vector3) -> String:
	_answers.clear()
	var before := _resources()
	var tag := str(spell.get("tag"))
	var is_summon := spell is CreatureType
	if not is_summon and _unseen_body(target):
		if not can_aim(target):
			return ""
		unseen_target_reads += 1
	if is_summon:
		caster.request_summon(tag)
	elif spell is SpellType and bool((spell as SpellType).is_structure) and target != null and target.is_valid():
		## Convert and Desecrate click a soul or a creature (the structures tab gives the spell, the click the target): the same
		## `request_cast` a human's click makes. A structure with no target (Manalith: the ground) goes by its entry of the tab.
		caster.request_cast(tag, target.node.global_position, target.node)
	elif spell is SpellType and bool((spell as SpellType).is_structure):
		var book := wizard.get_node("Spellbook") as Spellbook
		caster.request_structure(book.structure_index_of(tag), point)
	else:
		var node: Node3D = target.node if target != null and target.is_valid() else null
		caster.request_cast(tag, node.global_position if node != null else point, node)
	var answer := _answers[0] if not _answers.is_empty() else ""
	var name := str(spell.get("display_name"))
	var started := answer == name
	if audit != null:
		audit.note_request(slot, tag, name, started, answer, before, is_summon, _new_summoned_unit(tag) if (is_summon and started) else null, target.node if target != null else null)
	return answer


func _resources() -> Dictionary:
	var pool := wizard.get_node_or_null("ManaPool")
	var purse := wizard.get_node_or_null("SoulPurse")
	return {
		"mana": float(pool.get("current")) if pool != null else 0.0,
		"souls": int(purse.get("count")) if purse != null else 0,
	}


## The creature the Summoner just put in front of the wizard (translucent until the cast ends).
func _new_summoned_unit(tag: String) -> Node:
	if _units_root == null or _units_root.get_child_count() == 0:
		return null
	var unit := _units_root.get_child(_units_root.get_child_count() - 1)
	if str(unit.get("creature_tag")) == tag and int(unit.get("owner_slot")) == slot:
		return unit
	return null


# ---- orders (shiny.d:2350-2457) ----

## orderIfChanged (shiny.d:2393-2431). `target` is a track or null; `pos` a Vector3 or null.
func order_if_changed(t: AiTrack, ostate: int, target: AiTrack, pos: Variant) -> void:
	if t.kind == AiTrack.Kind.STR or not t.is_valid():
		return
	var reason := "changed"
	if t.ord_state == ostate and (target == null or t.ord_target == target.id):
		if pos == null or t.ord_pos.distance_squared_to(pos as Vector3) <= SAME_POS_SQ:
			## completed orders are retained: fixed-position orders are not re-issued once the body has arrived (shiny.d:2400-2409)
			if (ostate == 4 or ostate == 7) and t.cur_pos.distance_squared_to(t.ord_pos) <= 0.25:
				return
			if _has_live_order(t):
				return
			reason = "ended"
		else:
			var d := t.ord_pos.distance_to(pos as Vector3)
			reason = "moved<3" if d < 3.0 else ("moved<10" if d < 10.0 else "moved")
			if (pos as Vector3) == t.cur_pos:
				reason += " hold"
			if t.kind != AiTrack.Kind.WIZ:
				reason += " walking" if (t.node as UnitBody).is_walking() else " still"
	var key := "%s %d %s" % [AiTrack.Kind.keys()[t.kind], ostate, reason]
	var goal: Vector3
	if delay_ticks > 0:
		## The order waits its delay; a newer decision for the same body replaces it and keeps its time (else a body whose anchor
		## moves would never get one).
		var waiting: Dictionary = _pending_orders.get(t.id, {})
		_pending_orders[t.id] = {"t": t, "ostate": ostate, "target": target, "pos": pos, "key": key, "due": int(waiting.get("due", _tick + delay_ticks))}
		delayed += 1
		goal = (pos as Vector3) if pos != null else (target.cur_pos if target != null else t.cur_pos)
	else:
		var began := Time.get_ticks_usec()
		goal = _issue(t, ostate, target, pos)
		var spent := Time.get_ticks_usec() - began
		game_us += spent
		_note_order(key, spent)
	t.ord_state = 7 if (t.kind == AiTrack.Kind.WIZ and ostate == 6) else ostate
	t.ord_target = target.id if target != null else 0
	t.ord_pos = goal


## orderTargetRadius (shiny.d:2433-2445): inside `radius` of the target the body holds where it stands.
func order_target_radius(t: AiTrack, ostate: int, target: AiTrack, radius: float) -> int:
	if radius > 0.0 and not (radius * radius < t.cur_pos.distance_squared_to(target.cur_pos)):
		order_if_changed(t, ostate, null, t.cur_pos)
		return 1
	order_if_changed(t, ostate, target, null)
	return 0


## orderPosRadius (shiny.d:2441-2452).
func order_pos_radius(t: AiTrack, ostate: int, pos: Vector3, radius: float) -> int:
	if radius * radius < t.cur_pos.distance_squared_to(pos):
		order_if_changed(t, ostate, null, pos)
		return 0
	order_if_changed(t, ostate, null, t.cur_pos)
	return 1


## orderInteract (shiny.d:2452-2478, 0x487550): too far from `anchor` (more than `radius`): go there (move). Near: at a structure
## stay by it and fight what comes (ostate 5), at an enemy Manalith (BLDG flag 0x80) attack it (6; 7 with more than one guardian,
## which the port does not count), else advance to the anchor (7). Returns 1 when it is near.
func order_interact(t: AiTrack, anchor: Vector3, target: AiTrack, radius: float) -> int:
	if radius * radius < t.cur_pos.distance_squared_to(anchor):
		order_if_changed(t, 4, null, anchor)
		return 0
	if target != null and target.kind == AiTrack.Kind.STR:
		if target.status & AiTrack.MANALITH:
			order_if_changed(t, 6, target, anchor)
		else:
			order_if_changed(t, 5, target, null)
	else:
		order_if_changed(t, 7, null, anchor)
	return 1


## A walk to a place (the wizard going to a soul, ostate 0x22 of the original: «brain-driven engage», a move here).
func order_go_to(t: AiTrack, ostate: int, pos: Vector3) -> void:
	order_if_changed(t, ostate, null, pos)


## A unit with an order in progress, or a wizard walking (the live order sacengine compares with, shiny.d:2398).
func _has_live_order(t: AiTrack) -> bool:
	if _pending_orders.has(t.id):
		return true
	if t.kind == AiTrack.Kind.WIZ:
		## still walking, or standing at the spot he was sent to (a retained, completed order)
		return (t.node as WizardBody).is_walking() or t.cur_pos.distance_squared_to(t.ord_pos) <= 4.0
	var orders_node := t.node.get_node_or_null("Orders")
	return orders_node != null and int(orders_node.get("command")) != UnitOrders.Command.NONE


## issueOrder (shiny.d:2350-2391) in the commands of the port. A «retreat» of the original (ostates 3 and 5 with a target:
## stay near it and fight) is `guard` here: Orders `retreat` orders every creature of the side to the wizard.
func _issue(t: AiTrack, ostate: int, target: AiTrack, pos: Variant) -> Vector3:
	if t.kind == AiTrack.Kind.WIZ:
		var goal: Vector3 = (pos as Vector3) if pos != null else (target.cur_pos if target != null else t.cur_pos)
		if pos == null and target != null and (ostate == 3 or ostate == 5):
			var back := t.cur_pos - target.cur_pos
			back.y = 0.0
			if back.length() > WIZARD_STOP_M:
				goal = target.cur_pos + back.normalized() * WIZARD_STOP_M
			else:
				goal = t.cur_pos
		if audit != null:
			audit.record("order", "slot %d wizard walk %s" % [slot, AiAudit.fmt(goal)])
		wizard.request_walk(goal)
		orders_issued += 1
		return goal
	var command := ""
	match ostate:
		2, 4:
			command = "move"
		3:
			command = "guard" if target != null else "guard_area"
		5:
			command = "guard" if target != null else "move"
		6:
			command = "attack"
		7:
			command = "advance"
		34:
			command = "guard" if target != null else "guard_area"
		_:
			return t.cur_pos
	## The game refuses «advance» and «attack» to a pacifist (Orders._own_units, sacengine order()): the original AI keeps asking
	## and is refused every time; the port does not call, so the Manahoars wait where they were summoned.
	var type: Variant = t.node.get("type")
	if (ostate == 6 or ostate == 7) and type != null and (type as CreatureType).aggressiveness <= 0:
		return t.cur_pos
	var goal_node: Node3D = target.node if target != null and target.is_valid() else null
	var seen_at := t.cur_pos
	if goal_node != null and _unseen_body(target):
		if can_aim(target):
			unseen_target_reads += 1
		else:
			## a body the side does not see: its creatures go to where it was seen last (024e, no perfect information)
			seen_at = target.cur_pos
			goal_node = null
			## guard it -> hold that place; attack it -> advance there (fight what is found on the way)
			if command == "guard":
				command = "guard_area"
			elif command == "attack":
				command = "advance"
	var point: Vector3 = (pos as Vector3) if pos != null else (goal_node.global_position if goal_node != null else seen_at)
	if audit != null:
		audit.record("order", "slot %d %s %s %s" % [slot, t.node.name, command, AiAudit.fmt(point)])
	orders_issued += 1
	(orders as _ORDERS).apply_for(slot, [t.node], command, point, goal_node)
	return point


func _note_order(key: String, spent_us: int) -> void:
	var row: Array = order_stats.get(key, [0, 0])
	row[0] += 1
	row[1] += spent_us
	order_stats[key] = row
