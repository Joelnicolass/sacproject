extends Node

## RFC-052 052c (F362). A test hook of the debug world `debug/audio/audio_net_match.tscn` (`--world=` on a dedicated started by
## hand and on its client, agent/runs/run_audio_net.sh): once the human of slot 1 sits, the authority summons two foes next to
## his wizard (`--audio-duel=ycro,plfl`: slot 1 and slot 2), ends the summon after `summon_ticks`, cuts their health to
## `duel_health` and makes them fight. Every sound the client then hears comes from the replicated state (mode, swings, shots,
## Health): nothing here is sent to the client. Only the authority acts; not in the product.
## 052d: then it broadcasts `fx_name` through FxBus (the RPC every FX already uses) `fx_times` times, one every
## `fx_every_ticks`, between the two creatures: the client hears it through FxBus.played and FxSoundMap.
## 052f: the fight first lasts `battle_hold_ms` of REAL time with `battle_health` (nobody dies), and only then the health drops
## to `duel_health`. With --fixed-fps the dedicated runs far faster than real time, so a short duel would end between two
## frames of the client (it then gets the whole fight in one burst of state, and its CombatGauge, which samples every
## 0.25 s, never sees two creatures fighting at once). Holding the fight in real time lets the client measure it.

@export var summon_ticks := 90
@export var duel_health := 150.0
## Health while the fight is held (high: nobody dies before the hold ends).
@export var battle_health := 100000.0
## Real milliseconds the fight is held before the health drops to `duel_health`.
@export var battle_hold_ms := 3000
@export var gap_m := 4.0
@export var ahead_m := 6.0
@export var fx_name := "blood"
@export var fx_times := 4
@export var fx_every_ticks := 30

var _tags: PackedStringArray = []
var _units: Array[Node3D] = []
var _armed_tick := -1
var _phase := 0
var _fx_sent := 0
var _hold_until := 0


func _ready() -> void:
	_tags = MpBoot.user_value("audio-duel", "ycro,plfl").split(",", false)


func _physics_process(_delta: float) -> void:
	if _phase >= 5 or (MpKit.is_networked() and not MpKit.is_server()) or _tags.size() < 2:
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
						(unit.get_node("Health") as Health).current = battle_health
				_phase = 2
		2:
			if _units.size() == 2 and is_instance_valid(_units[0]) and is_instance_valid(_units[1]):
				_units[0].call("engage", _units[1])
				_units[1].call("engage", _units[0])
				print("duelo de audio: %s contra %s" % [_units[0].name, _units[1].name])
			_hold_until = Time.get_ticks_msec() + battle_hold_ms
			_phase = 3
		3:
			if Time.get_ticks_msec() < _hold_until:
				return
			for unit in _units:
				if is_instance_valid(unit):
					(unit.get_node("Health") as Health).current = duel_health
			print("duelo de audio: fin de la pelea sostenida")
			_armed_tick = MatchClock.now()
			_phase = 4
		4:
			if MatchClock.now() - _armed_tick < fx_every_ticks:
				return
			_armed_tick = MatchClock.now()
			var wizard := _wizard(1)
			if wizard != null:
				FxBus.broadcast(fx_name, wizard.global_position + Vector3.UP)
			_fx_sent += 1
			if _fx_sent >= fx_times:
				print("duelo de audio: %d FX %s" % [_fx_sent, fx_name])
				_phase = 5


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
