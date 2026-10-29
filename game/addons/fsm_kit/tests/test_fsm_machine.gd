extends "res://addons/fsm_kit/tests/fsm_test.gd"

## FsmMachine and FsmState: start, transitions, payload, the request hook, manual steps. One small tree per test.


## A state that writes what happens to it into a shared trace.
class Rec extends FsmState:
	var trace: Array[String]

	func enter() -> void:
		trace.append("enter %s %s" % [name, machine.payload])
		super()

	func exit() -> void:
		trace.append("exit %s" % name)
		super()

	func apply_payload(next_payload: Variant) -> void:
		trace.append("payload %s %s" % [name, next_payload])

	func update(delta: float) -> void:
		trace.append("update %s %s" % [name, delta])

	func physics_update(delta: float) -> void:
		trace.append("physics %s %s" % [name, delta])


## A machine whose state belongs to someone else (e.g. a value the network replicates): requests are only written down.
class Owned extends FsmMachine:
	var asked: Array[String]

	func _request_transition(next: FsmState, next_payload: Variant) -> bool:
		asked.append("%s %s" % [next.name, next_payload])
		return false


## Actor > machine > Idle, Move, Hurt. `setup` runs on the machine before it enters the tree.
func _build(trace: Array[String], machine: FsmMachine = null, setup: Callable = Callable()) -> FsmMachine:
	var actor := Node.new()
	actor.name = "Actor"
	var m := machine if machine != null else FsmMachine.new()
	m.name = "States"
	for state_name in ["Idle", "Move", "Hurt"]:
		var s := Rec.new()
		s.name = state_name
		s.trace = trace
		m.add_child(s)
	if setup.is_valid():
		setup.call(m)
	actor.add_child(m)
	tree.root.add_child(actor)
	return m


func _free(m: FsmMachine) -> void:
	m.get_parent().free()


func test_autostart_enters_initial_state() -> void:
	var trace: Array[String] = []
	var m := _build(trace, null, func(x: FsmMachine) -> void: x.initial_state = x.get_node("Move"))
	check(m.is_started(), "started by itself")
	check(m.current_name() == &"Move", "initial_state Move, got %s" % m.current_name())
	check(m.is_in(&"Move") and not m.is_in(&"Idle"), "is_in")
	check(m.actor == m.get_parent(), "actor defaults to the parent")
	check(trace == ["enter Move <null>"], "one enter, got %s" % [trace])
	_free(m)


func test_autostart_without_initial_state_uses_first_child() -> void:
	var trace: Array[String] = []
	var m := _build(trace)
	check(m.current_name() == &"Idle", "first FsmState child, got %s" % m.current_name())
	_free(m)


func test_no_autostart_waits_for_start() -> void:
	var trace: Array[String] = []
	var m := _build(trace, null, func(x: FsmMachine) -> void: x.autostart = false)
	check(not m.is_started() and m.current == null, "not started")
	check(m.current_name() == StringName() and not m.is_in(&"Idle"), "no current state")
	m.step_physics(0.1)
	check(trace.is_empty(), "nothing runs before start, got %s" % [trace])
	check(m.start(m.get_node("Hurt"), "no_anim"), "start returns true")
	check(m.is_in(&"Hurt") and m.payload == "no_anim", "starts in the given state with its payload")
	check(trace == ["enter Hurt no_anim"], "enter sees the start payload, got %s" % [trace])
	check(not m.start(m.get_node("Idle")), "second start returns false")
	check(m.is_in(&"Hurt"), "second start changes nothing")
	_free(m)


func test_start_rejects_a_state_of_another_machine() -> void:
	var trace: Array[String] = []
	var m := _build(trace, null, func(x: FsmMachine) -> void: x.autostart = false)
	var other := _build(trace)
	check(not m.start(other.get_node("Move")), "a state that is not a child")
	check(not m.is_started(), "still not started")
	_free(m)
	_free(other)


func test_transition_exits_then_enters() -> void:
	var trace: Array[String] = []
	var m := _build(trace)
	var changes: Array[String] = []
	var transitions: Array[String] = []
	m.state_changed.connect(func(a: StringName, b: StringName) -> void: changes.append("%s>%s" % [a, b]))
	m.transitioned.connect(func(a: StringName, b: StringName, p: Variant) -> void: transitions.append("%s>%s %s" % [a, b, p]))
	trace.clear()
	m.transition(&"Move", 7)
	check(trace == ["exit Idle", "enter Move 7"], "exit before enter, payload set first, got %s" % [trace])
	check(changes == ["Idle>Move"] and transitions == ["Idle>Move 7"], "signals, got %s %s" % [changes, transitions])
	m.transition_to(m.get_node("Hurt"))
	check(m.is_in(&"Hurt") and m.payload == null, "transition_to by node, payload reset")
	_free(m)


func test_same_state_only_applies_the_payload() -> void:
	var trace: Array[String] = []
	var m := _build(trace)
	var changes: Array[String] = []
	var transitions: Array[String] = []
	m.state_changed.connect(func(a: StringName, b: StringName) -> void: changes.append("%s>%s" % [a, b]))
	m.transitioned.connect(func(a: StringName, b: StringName, p: Variant) -> void: transitions.append("%s>%s %s" % [a, b, p]))
	trace.clear()
	m.transition(&"Idle", "again")
	check(trace == ["payload Idle again"], "no exit / enter, got %s" % [trace])
	check(changes.is_empty() and transitions == ["Idle>Idle again"], "transitioned only, got %s %s" % [changes, transitions])
	check(m.payload == "again", "machine payload")
	_free(m)


func test_unknown_state_changes_nothing() -> void:
	var trace: Array[String] = []
	var m := _build(trace)
	trace.clear()
	m.transition(&"Nope")
	m.request(&"Nope")
	check(m.is_in(&"Idle") and trace.is_empty(), "still Idle, got %s" % [trace])
	_free(m)


func test_state_transition_is_a_request_allowed_by_default() -> void:
	var trace: Array[String] = []
	var m := _build(trace)
	(m.get_node("Idle") as FsmState).transition(&"Move", 1)
	check(m.is_in(&"Move") and m.payload == 1, "default hook lets the state change it")
	_free(m)


func test_request_hook_can_hand_the_change_to_its_owner() -> void:
	var trace: Array[String] = []
	var m := _build(trace, Owned.new()) as Owned
	trace.clear()
	(m.get_node("Idle") as FsmState).transition(&"Hurt", "hit")
	check(m.asked == ["Hurt hit"], "the hook sees the request, got %s" % [m.asked])
	check(m.is_in(&"Idle") and trace.is_empty(), "a refused request changes nothing, got %s" % [trace])
	m.transition(&"Hurt", "hit")
	check(m.is_in(&"Hurt") and m.payload == "hit", "the owner's transition() is direct")
	check(m.asked.size() == 1, "the owner does not go through the hook")
	_free(m)


func test_manual_steps() -> void:
	var trace: Array[String] = []
	var m := _build(trace, null, _engine_off)
	trace.clear()
	m._physics_process(0.5)
	m._process(0.5)
	check(trace.is_empty(), "run_physics / run_process off: the engine callbacks do nothing, got %s" % [trace])
	m.step_physics(0.25)
	m.step_process(0.125)
	check(trace == ["physics Idle 0.25", "update Idle 0.125"], "steps run the current state, got %s" % [trace])
	_free(m)


func _engine_off(m: FsmMachine) -> void:
	m.run_physics = false
	m.run_process = false


func test_engine_callbacks_run_the_current_state() -> void:
	var trace: Array[String] = []
	var m := _build(trace)
	trace.clear()
	m._physics_process(0.5)
	m._process(0.25)
	check(trace == ["physics Idle 0.5", "update Idle 0.25"], "on by default, got %s" % [trace])
	_free(m)


func test_states_added_later() -> void:
	var trace: Array[String] = []
	var actor := Node.new()
	var m := FsmMachine.new()
	actor.add_child(m)
	tree.root.add_child(actor)
	check(not m.is_started(), "no state yet: not started")
	var idle := Rec.new()
	idle.name = "Idle"
	idle.trace = trace
	var move := Rec.new()
	move.name = "Move"
	move.trace = trace
	m.add_child(idle)
	m.add_child(move)
	check(move.machine == m, "a late state gets its machine")
	m.notify_actor_ready()
	check(m.is_in(&"Idle"), "notify_actor_ready starts it")
	move.transition(&"Idle", 2)
	check(m.payload == 2, "a late state can ask for a transition")
	actor.free()
