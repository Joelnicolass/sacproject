extends RefCounted

## RFC-052 052e (F364): the player's voices.
## Open gate (--audio-probe):
## - queue_rules (VoiceQueue, pure): a higher line cuts and drops the lower ones waiting; the same or a lower one waits; a key
##   speaking or waiting is dropped; past max_queued it is dropped; finish() hands the highest waiting, the oldest among equals.
## - advisor_channel (AdvisorVoice on looping fixture lines, so «speaking» does not depend on real time): lowm, then watt
##   cuts it; orng waits; lowm again is quiet (cooldown); dese cuts and drops orng; bdam (same priority) waits and speaks when
##   the channel ends; CommandLog.say("no_mana") says lowm and a message that is no refusal says nothing.
## - advisor_watch: the bound wizard's health down -> watt, below the low ratio -> whlt; an own building hit -> bdam, to 0 ->
##   bdst; a building of another side says nothing; a Desecrate on the local altar -> dese; it ends completed -> sacc.
## - command_voice: Selection.changed -> selected (three times), the fourth time in a row annoyed; Orders.requested move -> ack,
##   attack -> attack_ack (the set's Xcat); retreat says nothing; an order starts the count again; a selection that shrank
##   says nothing; a creature with no set says nothing; within the cooldown nothing.
## Closed gate (plain headless, --dedicated, --room-server):
## - voices_closed: AdvisorVoice (with its AdvisorWatch) and CommandVoice enter the tree and create no channel; say() is false.

const LOOP_ROOT := "res://debug/audio/fixtures/voices_loop/"
const VOICES_ROOT := "res://debug/audio/fixtures/voices/"
const CUES := "res://data/ui/command_cues.tres"


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	if not open:
		results["voices_closed"] = await _closed(host)
		return results
	if not SoundBus.is_active():
		results["voice_cases_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	results["queue_rules"] = _queue_rules()
	results["advisor_channel"] = await _advisor_channel(host)
	results["advisor_watch"] = await _advisor_watch(host)
	results["command_voice"] = await _command_voice(host)
	SoundBus.stop_all()
	SoundLibrary.reset_roots()
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


func _use_roots(root: String) -> void:
	SoundLibrary.roots = PackedStringArray([root])
	SoundLibrary.clear_cache()


func _advisor(host: Node) -> Array:
	var log := CommandLog.new()
	log.cues = load(CUES)
	host.add_child(log)
	var advisor := AdvisorVoice.new()
	advisor.command_log = log
	host.add_child(advisor)
	return [advisor, log]


func _advisor_channel(host: Node) -> Dictionary:
	_use_roots(LOOP_ROOT)
	var made := _advisor(host)
	var advisor: AdvisorVoice = made[0]
	var log: CommandLog = made[1]
	await host.get_tree().process_frame
	SoundBus.sound_log.clear()
	var checks := {}
	checks["lowm_speaks"] = advisor.say(&"lowm") and advisor.speaking() == &"lowm" and _played(0, &"lowm")
	checks["watt_cuts"] = advisor.say(&"watt") and advisor.speaking() == &"watt" and _played(0, &"watt")
	var mark := SoundBus.sound_log.size()
	checks["orng_waits"] = advisor.say(&"orng") and advisor.speaking() == &"watt" and advisor.waiting() == [&"orng"] \
		and not _played(mark, &"orng")
	checks["lowm_quiet"] = not advisor.say(&"lowm") and advisor.waiting() == [&"orng"]
	checks["dese_cuts_drops_lower"] = advisor.say(&"dese") and advisor.speaking() == &"dese" and advisor.waiting().is_empty()
	mark = SoundBus.sound_log.size()
	checks["bdam_waits"] = advisor.say(&"bdam") and advisor.speaking() == &"dese" and advisor.waiting() == [&"bdam"] \
		and not _played(mark, &"bdam")
	(advisor.get_node("Channel") as AudioStreamPlayer).stop()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	checks["bdam_after_end"] = advisor.speaking() == &"bdam" and _played(mark, &"bdam")
	advisor.reset()
	mark = SoundBus.sound_log.size()
	log.say("Mago")
	checks["no_refusal_quiet"] = advisor.speaking() == &"" and SoundBus.sound_log.size() == mark
	log.say(String(Refusal.NO_MANA))
	checks["refusal_says_lowm"] = advisor.speaking() == &"lowm" and _played(mark, &"lowm")
	advisor.reset()
	advisor.queue_free()
	log.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _advisor_watch(host: Node) -> Dictionary:
	_use_roots(LOOP_ROOT)
	var made := _advisor(host)
	var advisor: AdvisorVoice = made[0]
	var watch := AdvisorWatch.new()
	watch.advisor = advisor
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
	checks["wizard_hit_watt"] = advisor.speaking() == &"watt"
	_health(wizard).current = 20.0
	checks["wizard_low_whlt"] = advisor.speaking() == &"whlt"
	_health(theirs).current = 50.0
	checks["their_building_quiet"] = advisor.waiting().is_empty()
	_health(ours).current = 50.0
	checks["building_hit_bdam"] = advisor.waiting() == [&"bdam"]
	_health(ours).current = 0.0
	checks["building_down_bdst"] = advisor.waiting() == [&"bdam", &"bdst"]
	advisor.reset()
	var ritual := Ritual.new()
	ritual.process_mode = Node.PROCESS_MODE_DISABLED
	ritual.kind = Ritual.Kind.DESECRATE
	ritual.target_slot = MpKit.local_slot()
	ritual.caster_slot = MpKit.local_slot()
	host.add_child(ritual)
	ritual.phase = Ritual.Phase.SETUP
	watch.scan()
	checks["desecration_dese"] = advisor.speaking() == &"dese"
	ritual.outcome = Ritual.Outcome.COMPLETED
	watch.scan()
	checks["complete_sacc"] = advisor.waiting() == [&"sacc"]
	advisor.reset()
	for node: Node in [advisor, made[1], wizard, ours, theirs, ritual]:
		node.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _command_voice(host: Node) -> Dictionary:
	_use_roots(VOICES_ROOT)
	var selection := Node.new()
	selection.add_user_signal("changed", [{"name": "units", "type": TYPE_ARRAY}])
	var orders := Node.new()
	orders.add_user_signal("requested", [{"name": "units", "type": TYPE_ARRAY}, {"name": "command", "type": TYPE_STRING}])
	host.add_child(selection)
	host.add_child(orders)
	var voice := CommandVoice.new()
	voice.selection = selection
	voice.orders = orders
	voice.cooldown_s = 0.0
	voice.ack_cooldown_s = 0.0
	host.add_child(voice)
	var unit := _creature(host, "Speaker", "nmuh")
	var other := _creature(host, "Other", "nmuh")
	var mute := _creature(host, "Mute", "zzzz")
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
	checks["attack_ack_from_xcat"] = _stream_of(&"Speaker", &"attack_ack") != ""
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
	for node: Node in [voice, selection, orders, unit, other, mute]:
		node.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _closed(host: Node) -> Dictionary:
	var made := _advisor(host)
	var advisor: AdvisorVoice = made[0]
	var watch := AdvisorWatch.new()
	watch.advisor = advisor
	advisor.add_child(watch)
	var voice := CommandVoice.new()
	host.add_child(voice)
	await host.get_tree().process_frame
	var no_channel := advisor.get_node_or_null("Channel") == null and voice.get_node_or_null("Channel") == null
	var quiet := not advisor.say(&"lowm") and advisor.cue_for(&"lowm") == null
	var no_log := SoundBus.sound_log == null
	for node: Node in [advisor, made[1], voice]:
		node.queue_free()
	await host.get_tree().process_frame
	return {"ok": no_channel and quiet and no_log, "no_channel": no_channel, "quiet": quiet, "no_log": no_log}


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


func _creature(host: Node, body_name: String, tag: String) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar creature_tag := \"%s\"\n" % tag
	script.reload()
	var body := Node3D.new()
	body.set_script(script)
	body.name = body_name
	host.add_child(body)
	return body


func _health(body: Node) -> Health:
	return body.get_node("Health") as Health


func _played(since: int, code: StringName) -> bool:
	var entries := SoundBus.sound_log.entries()
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
