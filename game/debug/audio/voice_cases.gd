extends RefCounted

## RFC-052 052e (F364): the player's voices.
## Open gate (--audio-probe):
## - queue_rules (VoiceQueue, pure): a higher line cuts and drops the lower ones waiting; the same or a lower one waits; a key
##   speaking or waiting is dropped; past max_queued it is dropped; finish() hands the highest waiting, the oldest among equals.
## - advisor_channel (AdvisorVoice on looping fixture lines with the priorities and quiet times of advisor.tscn, so «speaking»
##   does not depend on real time): low_mana, then wizard_attacked cuts it; out_of_range waits; low_mana again is quiet; desecrated
##   cuts and drops out_of_range; building_attacked (same priority) waits and speaks when the channel ends;
##   CommandLog.say("no_mana") says low_mana and a message that is no refusal says nothing.
## - advisor_watch: the bound wizard's health down -> wizard_attacked, below the low ratio -> wizard_low_health; an own building
##   hit -> building_attacked, to 0 -> building_destroyed; a building of another side says nothing; a Desecrate on the local altar
##   -> desecrated; it ends completed -> sacrifice_complete.
## - advisor_scene: advisor.tscn carries the 14 lines with a stream each, the seven refusals, the eight warnings and a channel.
## - command_voice: Selection.changed -> selected (three times), the fourth time in a row annoyed; Orders.requested move -> ack,
##   attack -> attack_ack (its own field of the set); retreat says nothing; an order starts the count again; a selection that shrank
##   says nothing; a creature with no set says nothing; within the cooldown nothing.
## Closed gate (plain headless, --dedicated, --room-server):
## - voices_closed: AdvisorVoice (with its AdvisorWatch) and CommandVoice enter the tree and their channels stay idle; say() is false.

const _LOOK := preload("res://debug/audio/sound_look.gd")
const LOOP_CUE := "res://debug/audio/fixtures/beep_a.tres"
const VOICES_ROOT := "res://debug/audio/fixtures/voices/"
const CUES := "res://data/ui/command_cues.tres"
const ADVISOR_SCENE := "res://scenes/audio/advisor/advisor.tscn"
## name, priority (AdvisorLine.Priority), quiet_s: the values of advisor.tscn.
const LINES: Array = [
	[&"wizard_attacked", 1, 15.0], [&"wizard_low_health", 2, 5.0], [&"creatures_attacked", 1, 15.0], [&"creature_died", 1, 5.0],
	[&"building_attacked", 2, 5.0], [&"building_destroyed", 1, 1.0], [&"desecrated", 2, 5.0], [&"sacrifice_complete", 1, 2.0],
	[&"low_mana", 0, 5.0], [&"not_ready", 0, 2.0], [&"out_of_range", 0, 2.0], [&"invalid_target", 0, 2.0],
	[&"need_souls", 0, 2.0], [&"far_from_altar", 0, 2.0],
]
## The lines AdvisorWatch holds (its exports have these names).
const WATCH_LINES: PackedStringArray = ["wizard_attacked", "wizard_low_health", "creatures_attacked", "creature_died",
	"building_attacked", "building_destroyed", "desecrated", "sacrifice_complete"]
const REFUSALS := {&"no_mana": &"low_mana", &"cooling": &"not_ready", &"out_of_range": &"out_of_range",
	&"bad_target": &"invalid_target", &"no_target": &"invalid_target", &"no_souls": &"need_souls", &"far_from_altar": &"far_from_altar"}


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	if not open:
		results["voices_closed"] = await _closed(host)
		return results
	if not SoundBus.is_active():
		results["voice_cases_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	results["queue_rules"] = _queue_rules()
	results["advisor_scene"] = _advisor_scene()
	results["advisor_channel"] = await _advisor_channel(host)
	results["advisor_watch"] = await _advisor_watch(host)
	results["command_voice"] = await _command_voice(host)
	SoundBus.stop_all()
	## The audio server lets go of the stopped playbacks a moment (real time) later; quitting before leaks them at exit.
	## A wait of real time, not of frames: under --fixed-fps a headless frame takes microseconds and --quit-after would come first.
	OS.delay_msec(200)
	for _i in 3:
		await host.get_tree().process_frame
	return results


func _queue_rules() -> Dictionary:
	var q := VoiceQueue.new(2)
	var checks := {}
	checks["first_plays"] = q.offer(&"lowm", 0) == VoiceQueue.Offer.PLAY_NOW
	checks["same_waits"] = q.offer(&"orng", 0) == VoiceQueue.Offer.QUEUED
	checks["repeat_dropped"] = q.offer(&"orng", 0) == VoiceQueue.Offer.DROPPED and q.offer(&"lowm", 0) == VoiceQueue.Offer.DROPPED
	checks["higher_cuts"] = q.offer(&"watt", 1) == VoiceQueue.Offer.PLAY_NOW and q.current.key == &"watt"
	checks["lower_waiting_dropped"] = q.waiting().is_empty()
	checks["lower_never_cuts"] = q.offer(&"invl", 0) == VoiceQueue.Offer.QUEUED and q.current.key == &"watt"
	q.offer(&"nred", 0)
	checks["full_dropped"] = q.offer(&"orng", 0) == VoiceQueue.Offer.DROPPED and q.waiting() == [&"invl", &"nred"]
	checks["oldest_next"] = q.finish().get("key") == &"invl" and q.finish().get("key") == &"nred"
	checks["then_quiet"] = q.finish().is_empty() and q.current.is_empty()
	var q2 := VoiceQueue.new(3)
	q2.offer(&"dese", 2)
	q2.offer(&"invl", 0)
	q2.offer(&"uatt", 1)
	checks["equal_waits"] = q2.offer(&"bdam", 2) == VoiceQueue.Offer.QUEUED and q2.waiting() == [&"bdam"]
	checks["lower_behind_kept"] = q2.offer(&"cdie", 1) == VoiceQueue.Offer.QUEUED
	checks["highest_next"] = q2.finish().get("key") == &"bdam" and q2.finish().get("key") == &"cdie"
	return _verdict(checks)


## The 14 lines of the advisor over a looping fixture stream, by name.
func _lines() -> Dictionary:
	var cue := SoundCue.new()
	cue.streams = [load(LOOP_CUE) as AudioStream]
	cue.bus = &"Voice"
	cue.max_voices = 0
	var out := {}
	for row: Array in LINES:
		var line := AdvisorLine.new()
		line.resource_name = String(row[0])
		line.cue = cue
		line.priority = row[1]
		line.quiet_s = row[2]
		out[row[0]] = line
	return out


## An AdvisorVoice with its Channel and the refusal table of advisor.tscn; [advisor, command log, lines].
func _advisor(host: Node) -> Array:
	var log := CommandLog.new()
	log.cues = load(CUES)
	host.add_child(log)
	var lines := _lines()
	var advisor := AdvisorVoice.new()
	advisor.command_log = log
	advisor.channel = _channel(advisor)
	for key: StringName in REFUSALS:
		advisor.refusal_lines[key] = lines[REFUSALS[key]]
	host.add_child(advisor)
	return [advisor, log, lines]


## A voice channel child named «Channel» on `owner_node` (what a scene gives its voice).
func _channel(owner_node: Node) -> AudioStreamPlayer:
	var channel := AudioStreamPlayer.new()
	channel.name = "Channel"
	owner_node.add_child(channel)
	return channel


func _advisor_scene() -> Dictionary:
	var advisor := (load(ADVISOR_SCENE) as PackedScene).instantiate() as AdvisorVoice
	var watch := advisor.get_node_or_null("AdvisorWatch") as AdvisorWatch
	var checks := {}
	checks["has_channel"] = advisor.channel != null and advisor.channel.bus == &"Voice"
	checks["watch_child"] = watch != null and watch.advisor == advisor
	var names := {}
	for row: Array in LINES:
		names[row[0]] = row
	var found := {}
	for key: StringName in advisor.refusal_lines:
		found[StringName(advisor.refusal_lines[key].resource_name)] = advisor.refusal_lines[key]
	if watch != null:
		for name: StringName in names:
			var line := watch.get(name) as AdvisorLine
			if line != null:
				found[name] = line
	checks["fourteen_lines"] = found.size() == LINES.size()
	checks["refusals"] = advisor.refusal_lines.size() == REFUSALS.size() and REFUSALS.keys().all(
		func(key: StringName) -> bool: return advisor.line_for_refusal(key) != null and advisor.line_for_refusal(key).resource_name == REFUSALS[key])
	var all_ok := true
	for name: StringName in found:
		var line: AdvisorLine = found[name]
		var row: Array = names.get(name, [])
		all_ok = all_ok and not row.is_empty() and line.cue != null and not line.cue.is_silent() and line.cue.bus == &"Voice" \
			and line.priority == row[1] and is_equal_approx(line.quiet_s, row[2])
	checks["priorities_and_quiet"] = all_ok
	checks["only_log_warning"] = advisor._get_configuration_warnings().size() == 1
	advisor.free()
	return _verdict(checks)


func _advisor_channel(host: Node) -> Dictionary:
	var made := _advisor(host)
	var advisor: AdvisorVoice = made[0]
	var log: CommandLog = made[1]
	var lines: Dictionary = made[2]
	await host.get_tree().process_frame
	SoundBus.sound_log.clear()
	var checks := {}
	checks["low_mana_speaks"] = advisor.say(lines.low_mana) and advisor.speaking() == &"low_mana" and _played(0, &"low_mana")
	checks["attacked_cuts"] = advisor.say(lines.wizard_attacked) and advisor.speaking() == &"wizard_attacked" and _played(0, &"wizard_attacked")
	var mark: int = SoundBus.sound_log.size()
	checks["out_of_range_waits"] = advisor.say(lines.out_of_range) and advisor.speaking() == &"wizard_attacked" \
		and advisor.waiting() == [&"out_of_range"] and not _played(mark, &"out_of_range")
	checks["low_mana_quiet"] = not advisor.say(lines.low_mana) and advisor.waiting() == [&"out_of_range"]
	checks["desecrated_cuts_drops_lower"] = advisor.say(lines.desecrated) and advisor.speaking() == &"desecrated" and advisor.waiting().is_empty()
	mark = SoundBus.sound_log.size()
	checks["building_waits"] = advisor.say(lines.building_attacked) and advisor.speaking() == &"desecrated" \
		and advisor.waiting() == [&"building_attacked"] and not _played(mark, &"building_attacked")
	advisor.channel.stop()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	checks["building_after_end"] = advisor.speaking() == &"building_attacked" and _played(mark, &"building_attacked")
	advisor.reset()
	mark = SoundBus.sound_log.size()
	log.say("Mago")
	checks["no_refusal_quiet"] = advisor.speaking() == &"" and SoundBus.sound_log.size() == mark
	log.say(String(Refusal.NO_MANA))
	checks["refusal_says_low_mana"] = advisor.speaking() == &"low_mana" and _played(mark, &"low_mana")
	advisor.reset()
	advisor.queue_free()
	log.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _advisor_watch(host: Node) -> Dictionary:
	var made := _advisor(host)
	var advisor: AdvisorVoice = made[0]
	var lines: Dictionary = made[2]
	var watch := AdvisorWatch.new()
	watch.advisor = advisor
	for line: AdvisorLine in lines.values():
		if line.resource_name in WATCH_LINES:
			watch.set(line.resource_name, line)
	watch.scan_every_s = 100.0
	advisor.add_child(watch)
	var wizard := _body(host, "LabWizard", 1, "")
	var ours := _body(host, "OwnBuilding", 1, "structure")
	var theirs := _body(host, "TheirBuilding", 2, "structure")
	await host.get_tree().process_frame
	watch.bind_wizard(wizard)
	watch.scan()
	var checks := {}
	_health(wizard).current = 90.0
	checks["wizard_hit_attacked"] = advisor.speaking() == &"wizard_attacked"
	_health(wizard).current = 20.0
	checks["wizard_low_health"] = advisor.speaking() == &"wizard_low_health"
	_health(theirs).current = 50.0
	checks["their_building_quiet"] = advisor.waiting().is_empty()
	_health(ours).current = 50.0
	checks["building_hit"] = advisor.waiting() == [&"building_attacked"]
	_health(ours).current = 0.0
	checks["building_down"] = advisor.waiting() == [&"building_attacked", &"building_destroyed"]
	advisor.reset()
	var ritual := Ritual.new()
	ritual.process_mode = Node.PROCESS_MODE_DISABLED
	ritual.kind = Ritual.Kind.DESECRATE
	ritual.target_slot = MpKit.local_slot()
	ritual.caster_slot = MpKit.local_slot()
	host.add_child(ritual)
	ritual.phase = Ritual.Phase.SETUP
	watch.scan()
	checks["desecration"] = advisor.speaking() == &"desecrated"
	ritual.outcome = Ritual.Outcome.COMPLETED
	watch.scan()
	checks["complete"] = advisor.waiting() == [&"sacrifice_complete"]
	advisor.reset()
	for node: Node in [advisor, made[1], wizard, ours, theirs, ritual]:
		node.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _command_voice(host: Node) -> Dictionary:
	var selection := Node.new()
	selection.add_user_signal("changed", [{"name": "units", "type": TYPE_ARRAY}])
	var orders := Node.new()
	orders.add_user_signal("requested", [{"name": "units", "type": TYPE_ARRAY}, {"name": "command", "type": TYPE_STRING}])
	host.add_child(selection)
	host.add_child(orders)
	var voice := CommandVoice.new()
	voice.channel = _channel(voice)
	voice.selection = selection
	voice.orders = orders
	voice.cooldown_s = 0.0
	voice.ack_cooldown_s = 0.0
	host.add_child(voice)
	var voices := load(VOICES_ROOT + "command_set.tres") as SoundSet
	var unit := _creature("Speaker", voices)
	var other := _creature("Other", voices)
	var mute := _creature("Mute", null)
	await host.get_tree().process_frame
	SoundBus.sound_log.clear()
	var checks := {}
	for i in 4:
		selection.emit_signal("changed", [unit])
	checks["selected_three"] = _events_of(&"Speaker") == [&"selected", &"selected", &"selected", &"annoyed"]
	SoundBus.sound_log.clear()
	orders.emit_signal("requested", [unit], "move")
	orders.emit_signal("requested", [unit], "attack")
	orders.emit_signal("requested", [unit], "retreat")
	var events := _events_of(&"Speaker")
	checks["orders_ack"] = events == [&"ack", &"attack_ack"]
	checks["attack_ack_has_stream"] = _stream_of(&"Speaker", &"attack_ack") != ""
	SoundBus.sound_log.clear()
	selection.emit_signal("changed", [unit])
	checks["order_resets_count"] = _events_of(&"Speaker") == [&"selected"]
	SoundBus.sound_log.clear()
	selection.emit_signal("changed", [other, unit])
	selection.emit_signal("changed", [unit])
	checks["shrink_quiet"] = _events_of(&"Other") == [&"selected"] and _events_of(&"Speaker").is_empty()
	selection.emit_signal("changed", [mute])
	checks["no_set_quiet"] = _events_of(&"Mute").is_empty()
	voice.cooldown_s = 10.0
	SoundBus.sound_log.clear()
	selection.emit_signal("changed", [unit, other])
	checks["cooldown_quiet"] = SoundBus.sound_log.size() == 0
	for node: Node in [voice, selection, orders]:
		node.queue_free()
	for unit_body: UnitBody in [unit, other, mute]:
		unit_body.free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _closed(host: Node) -> Dictionary:
	var log := CommandLog.new()
	log.cues = load(CUES)
	host.add_child(log)
	var line := AdvisorLine.new()
	line.resource_name = "low_mana"
	var advisor := AdvisorVoice.new()
	advisor.command_log = log
	advisor.channel = _channel(advisor)
	host.add_child(advisor)
	var watch := AdvisorWatch.new()
	watch.advisor = advisor
	advisor.add_child(watch)
	var voice := CommandVoice.new()
	voice.channel = _channel(voice)
	host.add_child(voice)
	await host.get_tree().process_frame
	var idle := not advisor.channel.playing and not voice.channel.playing
	var quiet := not advisor.say(line) and advisor.cue_for(line) == null
	var no_log: bool = SoundBus.sound_log == null
	for node: Node in [advisor, log, voice]:
		node.queue_free()
	await host.get_tree().process_frame
	return {"ok": idle and quiet and no_log, "idle": idle, "quiet": quiet, "no_log": no_log}


## A Node3D with `owner_slot` and a Health child of 100, in `group` (none when empty).
func _body(host: Node, body_name: String, slot: int, group: String) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar owner_slot := %d\n" % slot
	script.reload()
	var body := Node3D.new()
	body.set_script(script)
	body.name = body_name
	var health := Health.new()
	health.name = "Health"
	body.add_child(health)
	if not group.is_empty():
		body.add_to_group(group)
	host.add_child(body)
	health.maximum = 100.0
	health.current = 100.0
	return body


## A creature that is not in the tree (CommandVoice only reads its name and the sounds of the look it wears) with the given sounds.
func _creature(body_name: String, sounds: SoundSet) -> UnitBody:
	var body := UnitBody.new()
	body.name = body_name
	body.type = CreatureType.new()
	_LOOK.give(body, sounds)
	return body


func _health(body: Node) -> Health:
	return body.get_node("Health") as Health


func _played(since: int, code: StringName) -> bool:
	var entries: Array[Dictionary] = SoundBus.sound_log.entries()
	for i in range(mini(since, entries.size()), entries.size()):
		if entries[i].emitter == code and entries[i].event == SoundEvent.ADVICE and bool(entries[i].played):
			return true
	return false


func _events_of(emitter: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in SoundBus.sound_log.entries():
		if entry.emitter == emitter and bool(entry.played):
			out.append(entry.event)
	return out


func _stream_of(emitter: StringName, event: StringName) -> String:
	for entry in SoundBus.sound_log.entries():
		if entry.emitter == emitter and entry.event == event and bool(entry.played):
			return str(entry.stream)
	return ""


func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	var out := checks.duplicate()
	out["ok"] = ok
	return out
