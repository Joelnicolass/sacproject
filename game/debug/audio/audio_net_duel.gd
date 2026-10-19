extends Node

## RFC-052 052c (F362). A test hook of the debug world `debug/audio/audio_net_match.tscn` (`--world=` on a dedicated started by
## hand and on its client, agent/runs/run_audio_net.sh): once the human of slot 1 sits, the authority summons two foes next to
## his wizard (`--audio-duel=ycro,plfl`: slot 1 and slot 2), ends the summon after `summon_ticks`, cuts their health to
## `duel_health` and makes them fight. Every sound the client then hears comes from the replicated state (mode, swings, shots,
## Health): nothing here is sent to the client. Only the authority acts; not in the product.

@export var summon_ticks := 90
@export var duel_health := 150.0
@export var gap_m := 4.0
@export var ahead_m := 6.0

var _tags: PackedStringArray = []
var _units: Array[Node3D] = []
var _armed_tick := -1
var _phase := 0


func _ready() -> void:
	_tags = MpBoot.user_value("audio-duel", "ycro,plfl").split(",", false)


func _physics_process(_delta: float) -> void:
	if _phase >= 3 or (MpKit.is_networked() and not MpKit.is_server()) or _tags.size() < 2:
		return
	var state := get_tree().get_first_node_in_group(&"match_state") as MatchState
	if state == null:
		return
	match _phase:
		0:
			var wizard := _wizard(1)
			if state.seated_slots.has(1) and wizard != null:
				_spawn(wizard)
				_armed_tick = MatchClock.now()
				_phase = 1
		1:
			if MatchClock.now() - _armed_tick >= summon_ticks:
				for unit in _units:
					if is_instance_valid(unit):
						unit.call("finish_summon")
						(unit.get_node("Health") as Health).current = duel_health
				_phase = 2
		2:
			if _units.size() == 2 and is_instance_valid(_units[0]) and is_instance_valid(_units[1]):
				_units[0].call("engage", _units[1])
				_units[1].call("engage", _units[0])
				print("duelo de audio: %s contra %s" % [_units[0].name, _units[1].name])
			_phase = 3


func _wizard(slot: int) -> Node3D:
	for wizard in get_tree().get_nodes_in_group(&"wizard"):
		if int(wizard.get("owner_slot")) == slot:
			return wizard as Node3D
	return null


func _spawn(wizard: Node3D) -> void:
	var spawner := get_tree().get_first_node_in_group(&"unit_spawner") as UnitSpawner
	if spawner == null:
		push_error("audio_net_duel: no UnitSpawner")
		return
	var ahead := (wizard.call("facing_flat") as Vector3) if wizard.has_method("facing_flat") else Vector3.FORWARD
	var side := ahead.cross(Vector3.UP).normalized()
	for i in 2:
		var at := wizard.global_position + ahead * ahead_m + side * (gap_m * (i - 0.5))
		var unit := spawner.spawn_unit({"tag": _tags[i], "slot": i + 1, "x": at.x, "y": at.y + 1.0, "z": at.z, "yaw": 0.0, "summoning": true})
		if unit != null:
			_units.append(unit)
	print("duelo de audio: %d criaturas convocadas" % _units.size())
