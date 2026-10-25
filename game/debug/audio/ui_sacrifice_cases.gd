extends RefCounted

## RFC-052 052h (F367): UI clicks, the radial menu, the sacrifice and the souls.
## Open gate (--audio-probe). The UI cases use the fixture set of debug/audio/fixtures/ui_sacrifice/ (and an empty root); the
## ritual and the soul sound with the cues their scenes carry (data/audio/cues/):
## - ui_clicks: a Button that enters the tree clicks once per press (`click`); meta `no_ui_sound` silences it, `false` does
##   not; meta `ui_sound` picks its key (Iclk); out and back into the tree it still clicks once (no second connection).
## - menu_sounds: a RadialMenu with its MenuSounds: open -> menu_open, cancel -> menu_back, a confirm on nothing ->
##   menu_back; a confirm on nothing of a closed menu says nothing more than its cancel.
## - ritual_sounds: ritual.tscn (frozen): phase SHOOT -> sacrifice_round, WAIT nothing, SHOOT again -> another; aborted ->
##   no sacrifice_end; a Convert completed -> sacrifice_end and soul.
## - soul_sounds: soul.tscn (frozen): COLLECTING -> soul once (also when it then leaves the tree); DEVOURING -> nothing.
## Closed gate (plain headless, --dedicated, --room-server):
## - ui_sacrifice_closed: a press makes no log and ui_cue_for is null; RitualSounds and SoulSounds connect nothing.

const FIXTURE_ROOT := "res://debug/audio/fixtures/ui_sacrifice/"
const EMPTY_ROOT := "res://debug/audio/fixtures/empty/"
const RITUAL_SCENE := "res://scenes/sacrifice/ritual.tscn"
const SOUL_SCENE := "res://scenes/souls/soul.tscn"
const RADIAL_SCENE := "res://scenes/ui/radial/radial_menu.tscn"


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	if not open:
		results["ui_sacrifice_closed"] = await _closed(host)
		return results
	if not SoundBus.is_active():
		results["ui_sacrifice_cases_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	SoundLibrary.roots = PackedStringArray([FIXTURE_ROOT, EMPTY_ROOT])
	SoundLibrary.clear_cache()
	results["ui_clicks"] = await _ui_clicks(host)
	results["menu_sounds"] = await _menu_sounds(host)
	results["ritual_sounds"] = await _ritual_sounds(host)
	results["soul_sounds"] = await _soul_sounds(host)
	SoundBus.stop_all()
	SoundLibrary.reset_roots()
	## The audio server lets go of the stopped playbacks a moment (real time) later; quitting before leaks them at exit.
	OS.delay_msec(200)
	for _i in 3:
		await host.get_tree().process_frame
	return results


## Played entries of `emitter`/`event` since log index `since`.
static func _count(since: int, emitter: StringName, event: StringName) -> int:
	var n := 0
	var entries: Array[Dictionary] = SoundBus.sound_log.entries()
	for i in range(mini(since, entries.size()), entries.size()):
		var entry: Dictionary = entries[i]
		if entry.emitter == emitter and entry.event == event and bool(entry.played):
			n += 1
	return n


static func _mark() -> int:
	SoundBus.stop_all()
	return SoundBus.sound_log.entries().size()


func _ui_clicks(host: Node) -> Dictionary:
	var checks := {}
	var plain := Button.new()
	plain.name = "CasePlain"
	var muted := Button.new()
	muted.name = "CaseMuted"
	muted.set_meta(SoundBus.META_NO_UI_SOUND, true)
	var unmuted := Button.new()
	unmuted.name = "CaseUnmuted"
	unmuted.set_meta(SoundBus.META_NO_UI_SOUND, false)
	var keyed := Button.new()
	keyed.name = "CaseKeyed"
	keyed.set_meta(SoundBus.META_UI_SOUND, &"Iclk")
	for button: Button in [plain, muted, unmuted, keyed]:
		host.add_child(button)
	await host.get_tree().process_frame
	var at := _mark()
	plain.pressed.emit()
	checks["plain_clicks"] = _count(at, &"CasePlain", SoundEvent.CLICK) == 1
	at = _mark()
	muted.pressed.emit()
	checks["muted_silent"] = _count(at, &"CaseMuted", SoundEvent.CLICK) == 0 and SoundBus.ui_cue_for(muted) == null
	at = _mark()
	unmuted.pressed.emit()
	checks["meta_false_clicks"] = _count(at, &"CaseUnmuted", SoundEvent.CLICK) == 1
	at = _mark()
	keyed.pressed.emit()
	checks["keyed_clicks"] = _count(at, &"CaseKeyed", SoundEvent.CLICK) == 1 \
		and SoundBus.ui_cue_for(keyed) == SoundBus.lookup("ui", &"Iclk") and SoundBus.ui_cue_for(keyed) != null
	host.remove_child(plain)
	host.add_child(plain)
	await host.get_tree().process_frame
	at = _mark()
	plain.pressed.emit()
	checks["readded_once"] = _count(at, &"CasePlain", SoundEvent.CLICK) == 1
	for button: Button in [plain, muted, unmuted, keyed]:
		button.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _menu_sounds(host: Node) -> Dictionary:
	var checks := {}
	var packed := load(RADIAL_SCENE) as PackedScene
	var radial := packed.instantiate() as RadialMenu
	radial.name = "CaseRadial"
	radial.open_s = 0.0
	radial.close_s = 0.0
	host.add_child(radial)
	await host.get_tree().process_frame
	checks["has_menu_sounds"] = radial.get_node_or_null("MenuSounds") is MenuSounds
	var at := _mark()
	radial.open_at(Vector2(200.0, 200.0))
	checks["open"] = _count(at, &"CaseRadial", SoundEvent.MENU_OPEN) == 1
	at = _mark()
	radial.cancel()
	checks["cancel"] = _count(at, &"CaseRadial", SoundEvent.MENU_BACK) == 1
	at = _mark()
	radial.cancel()
	checks["closed_cancel_quiet"] = _count(at, &"CaseRadial", SoundEvent.MENU_BACK) == 0
	radial.open_at(Vector2(200.0, 200.0))
	at = _mark()
	radial.confirm()
	checks["confirm_on_nothing"] = _count(at, &"CaseRadial", SoundEvent.MENU_BACK) == 1
	radial.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _ritual(host: Node, node_name: String, kind: Ritual.Kind) -> Ritual:
	var ritual := (load(RITUAL_SCENE) as PackedScene).instantiate() as Ritual
	ritual.name = node_name
	ritual.kind = kind
	ritual.caster_slot = 9
	ritual.target_slot = 9
	ritual.process_mode = Node.PROCESS_MODE_DISABLED
	host.add_child(ritual)
	return ritual


func _ritual_sounds(host: Node) -> Dictionary:
	var checks := {}
	var desecrate := _ritual(host, "CaseDesecrate", Ritual.Kind.DESECRATE)
	var convert := _ritual(host, "CaseConvert", Ritual.Kind.CONVERT)
	await host.get_tree().process_frame
	var at := _mark()
	desecrate.phase = Ritual.Phase.WALK
	checks["walk_quiet"] = _count(at, &"CaseDesecrate", SoundEvent.SACRIFICE_ROUND) == 0
	desecrate.phase = Ritual.Phase.SHOOT
	checks["shoot_round"] = _count(at, &"CaseDesecrate", SoundEvent.SACRIFICE_ROUND) == 1
	desecrate.phase = Ritual.Phase.WAIT
	desecrate.phase = Ritual.Phase.WALK
	desecrate.phase = Ritual.Phase.SHOOT
	checks["second_round"] = _count(at, &"CaseDesecrate", SoundEvent.SACRIFICE_ROUND) == 2
	at = _mark()
	desecrate.outcome = Ritual.Outcome.ABORTED
	checks["aborted_no_end"] = _count(at, &"CaseDesecrate", SoundEvent.SACRIFICE_END) == 0
	at = _mark()
	convert.phase = Ritual.Phase.SHOOT
	convert.outcome = Ritual.Outcome.COMPLETED
	checks["convert_end"] = _count(at, &"CaseConvert", SoundEvent.SACRIFICE_END) == 1
	checks["convert_soul"] = _count(at, &"CaseConvert", SoundEvent.SOUL) == 1
	desecrate.queue_free()
	convert.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _soul(host: Node, node_name: String) -> Soul:
	var soul := (load(SOUL_SCENE) as PackedScene).instantiate() as Soul
	soul.name = node_name
	soul.process_mode = Node.PROCESS_MODE_DISABLED
	host.add_child(soul)
	return soul


func _soul_sounds(host: Node) -> Dictionary:
	var checks := {}
	var taken := _soul(host, "CaseTaken")
	var eaten := _soul(host, "CaseEaten")
	await host.get_tree().process_frame
	var at := _mark()
	taken.state = Soul.State.COLLECTING
	checks["collect_soul"] = _count(at, &"CaseTaken", SoundEvent.SOUL) == 1
	taken.get_parent().remove_child(taken)
	checks["leaving_once"] = _count(at, &"CaseTaken", SoundEvent.SOUL) == 1
	taken.free()
	at = _mark()
	eaten.state = Soul.State.DEVOURING
	checks["devour_quiet"] = _count(at, &"CaseEaten", SoundEvent.SOUL) == 0
	eaten.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks)


func _closed(host: Node) -> Dictionary:
	var button := Button.new()
	button.name = "CaseClosedButton"
	host.add_child(button)
	var ritual := _ritual(host, "CaseClosedRitual", Ritual.Kind.CONVERT)
	var soul := _soul(host, "CaseClosedSoul")
	await host.get_tree().process_frame
	button.pressed.emit()
	var no_log: bool = SoundBus.sound_log == null and SoundBus.ui_cue_for(button) == null
	var ritual_sounds := ritual.get_node("RitualSounds")
	var soul_sounds := soul.get_node("SoulSounds")
	var unconnected := not ritual.phase_changed.get_connections().any(func(c: Dictionary) -> bool: return (c.callable as Callable).get_object() == ritual_sounds) \
		and not soul.state_changed.get_connections().any(func(c: Dictionary) -> bool: return (c.callable as Callable).get_object() == soul_sounds)
	for node: Node in [button, ritual, soul]:
		node.queue_free()
	await host.get_tree().process_frame
	return {"ok": no_log and unconnected, "no_log": no_log, "unconnected": unconnected}


static func _verdict(checks: Dictionary) -> Dictionary:
	var ok := checks.values().all(func(v: bool) -> bool: return v)
	var out := {"ok": ok}
	if not ok:
		out.merge(checks)
	return out
