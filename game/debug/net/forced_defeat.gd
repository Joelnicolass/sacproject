extends Node

## RFC-049 049e (F294). A test hook for a dedicated started by hand (no room ticket, so no MatchTicketGlue): defeats the slots of
## `--force-defeat-slot=3,4` once `--force-defeat-after-ticks=T` ticks have passed since the human of `--force-defeat-after-slot`
## (slot 1 by default) sat in his seat. A dedicated started by hand runs its world from the start, so the count cannot start with the
## world: a client takes seconds to arrive. It lives in the debug world `debug/net/forced_defeat_match.tscn` (`--world=` on the
## dedicated and on the clients), not in the product. Only the authority acts.

var _slots: Array[int] = []
var _after_ticks := 0
var _after_slot := 1
var _armed_tick := -1
var _done := false


func _ready() -> void:
	for part in MpBoot.user_value("force-defeat-slot", "").split(",", false):
		_slots.append(int(part))
	_after_ticks = int(MpBoot.user_value("force-defeat-after-ticks", "600"))
	_after_slot = int(MpBoot.user_value("force-defeat-after-slot", "1"))


func _physics_process(_delta: float) -> void:
	if _done or _slots.is_empty() or (MpKit.is_networked() and not MpKit.is_server()):
		return
	var state := get_tree().get_first_node_in_group(&"match_state") as MatchState
	if state == null:
		return
	if _armed_tick < 0:
		if state.seated_slots.has(_after_slot):
			_armed_tick = MatchClock.now()
			print("derrota forzada armada: el slot %d está sentado (tick %d)" % [_after_slot, _armed_tick])
		return
	if MatchClock.now() - _armed_tick < _after_ticks:
		return
	for child in state.get_children():
		if child is DefeatRule:
			_done = true
			for slot in _slots:
				print("derrota forzada del slot %d (prueba)" % slot)
				(child as DefeatRule).defeat(slot)
			return
