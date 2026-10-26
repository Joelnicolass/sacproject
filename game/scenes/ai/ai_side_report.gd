class_name AiSideReport
extends RefCounted

## What a human (or the bench's report) reads of an AI side: how long its ticks and jobs took, and what it holds right now. It
## reads the side's clock and children and changes nothing; the simulation never reads it. Static.

## Mean, p99 and max of the milliseconds a tick of the side took: whole (the criterion, RFC-024 addendum 1.2) and, under
## `decisions`, without the calls into the game it made through the port (diagnostic).
static func ms_stats(side: AiSide) -> Dictionary:
	var tick_ms := side.clock.tick_ms
	var tick_ms_decisions := side.clock.tick_ms_decisions
	if tick_ms.is_empty():
		return {}
	var out := _stats_of(tick_ms)
	out["decisions"] = _stats_of(tick_ms_decisions)
	var over := 0
	var over_game := 0
	for i in tick_ms.size():
		if tick_ms[i] > 2.0:
			over += 1
			if tick_ms[i] - tick_ms_decisions[i] > 1.0:
				over_game += 1
	## ticks over 2 ms, and how many of them spent more than 1 ms inside the game (a summon, a wizard's long path)
	out["over_2ms"] = over
	out["over_2ms_game"] = over_game
	## the first second holds the scan of the map (scanGlobal) and the first orders of every body: the max without it
	if tick_ms.size() > 60:
		out["max_after_1s"] = snappedf(Array(tick_ms.slice(60)).max(), 0.001)
	return out


## Per job k0..k5 (status, stance, perception, groups, replan, tasks): runs, mean, p99 and max in ms (diagnostic).
static func slot_stats(side: AiSide) -> Dictionary:
	var out := {}
	for k in 6:
		var values := PackedFloat32Array()
		for us in side.clock.slot_us[k]:
			values.append(float(us) / 1000.0)
		if not values.is_empty():
			out["k%d" % k] = _stats_of(values)
	out["worst_tick"] = side.clock.worst
	return out


static func _stats_of(values: PackedFloat32Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"mean": snappedf(total / sorted.size(), 0.001),
		"p99": snappedf(sorted[int(sorted.size() * 0.99)], 0.001),
		"max": snappedf(sorted[sorted.size() - 1], 0.001),
		"ticks": sorted.size(),
	}


## What the side holds right now: tracks per category, the records of each task with their members, the stance numbers.
static func summary(side: AiSide) -> Dictionary:
	var perception := side.perception
	var stance := side.stance
	var groups := side.groups
	var tasks := []
	for task in side.board.tasks:
		var rows := []
		for record in task.records:
			rows.append({"target": str(record.target.node.name) if record.target != null and record.target.is_valid() else "-", "score": ("nan" if is_nan(record.score) else snappedf(record.score, 0.001)), "members": record.members.size(), "leader": str(record.leader.node.name) if record.leader != null and record.leader.is_valid() else "-"})
		tasks.append({"task": task.name, "records": rows})
	var wizard_track := perception.find(side.wizard)
	return {
		"tracks": [perception.tracks_of(0).size(), perception.tracks_of(1).size(), perception.tracks_of(2).size(), perception.tracks_of(3).size()],
		"manaliths": stance.manalith_count(),
		"souls_all": stance.recs[0].souls_all,
		"enemy_ratio": snappedf(stance.enemy_ratio(), 0.0001),
		"threat": snappedf(wizard_track.threat, 0.0001) if wizard_track != null else -1.0,
		"wizard_age": wizard_track.age if wizard_track != null else -1,
		"groups": [groups.list(0).size(), groups.list(1).size(), groups.list(2).size(), groups.list(3).size()],
		"tasks": tasks,
	}
