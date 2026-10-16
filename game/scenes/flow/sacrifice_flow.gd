extends MpFlow

signal slot_picks_changed

const PICK_CHANNEL := &"pick"
const SLOT_PICKS_CHANNEL := &"slot_picks"
## The seat of «Contra la IA» (RFC-024 024f): slot 2, the god drawn, Normal.
const VS_AI_SEAT := "res://data/ai/seat_vs_ai.tres"

## Local choice: {wizard: "cwa1", model: "serx", god: "persephone"}.
var pick: Dictionary = {"wizard": "cwa0", "model": "jnwr", "god": "james"}
## Server-validated picks by MpKit slot, replicated to clients.
var slot_picks: Dictionary = {}
## RFC-024 024f: the AI seats of the match this process simulates when the rules bring none (AiRoster reads them):
## «Contra la IA» in solo, or the dedicated started with --ai-slots=2 [--ai-god=pyro]. Empty = only humans.
var solo_ai_seats: Array[AiSeat] = []
## RFC-031 031a2 (F140): what the next match overrides of its rules (level, friendly fire). HighNoon applies it on
## the authority. «Contra la IA» takes the level from the boot; the dedicated (and solo) the flags of this process.
var setup := MatchSetup.new()
## The flags of this process (--level=N, --friendly-fire / --no-friendly-fire), read once; every reset starts here.
var _cli_setup := MatchSetup.new()

func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	## `--world=res://debug/….tscn` on the dedicated and its clients plays a debug scene online.
	world_path = MpBoot.user_value("world", "res://scenes/world/high_noon.tscn")
	room_name = "High Noon"
	max_players = 2
	advertise_lan = false
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	## Before super._ready(): MpKit.configure takes max_players there, so the one human gets slot 1 and the AI keeps slot 2.
	_read_dedicated_ai()
	_cli_setup = MatchSetup.from_cli()
	setup = _cli_setup.copy()
	MpKit.slot_assigned.connect(_on_slot_assigned)
	MpKit.custom_received.connect(_on_custom_received)
	MpKit.peer_left.connect(_on_peer_left)
	super._ready()
	if MpBoot.is_dedicated_process():
		print("dedicated listo puerto ", MpKit.port)


func set_pick(wizard_tag: String, god: String) -> void:
	var chosen := sanitize_pick({"wizard": wizard_tag, "god": god})
	if chosen.is_empty():
		return
	pick = chosen
	print("pick %s %s" % [pick["model"], pick["god"]])


func sanitize_pick(raw: Dictionary) -> Dictionary:
	var tag := str(raw.get("wizard", ""))
	var god := str(raw.get("god", ""))
	if not GameData.gods().has(god):
		return {}
	var wizard: WizardType = GameData.wizard(tag)
	if wizard != null:
		return {"wizard": wizard.tag, "model": wizard.model, "god": god}
	if GameData.is_loaded():
		return {}
	var model := str(raw.get("model", "")).validate_filename()
	if tag.is_empty() or model.is_empty():
		return {}
	return {"wizard": tag, "model": model, "god": god}


func pick_for(slot: int) -> Dictionary:
	if slot_picks.has(slot):
		return slot_picks[slot]
	if slot == MpKit.local_slot():
		return pick
	return {}


func play_solo() -> void:
	solo_ai_seats = []
	setup = _cli_setup.copy()
	_play_alone()


## «Contra la IA»: solo, with the AI in slot 2. `god` empty = drawn when the match starts. `level` 1-9 is the wizard
## level of both wizards (030d) and wins over --level; 0 keeps --level or the rules.
func play_vs_ai(god: StringName = &"", level: int = 0) -> void:
	solo_ai_seats = [_vs_ai_seat(god)]
	setup = _cli_setup.copy()
	if level >= 1 and level <= 9:
		setup.level = level
	_play_alone()


func _play_alone() -> void:
	super.play_solo()
	slot_picks = {MpKit.local_slot(): pick.duplicate()}
	slot_picks_changed.emit()


func host_lan() -> Error:
	solo_ai_seats = []
	setup = _cli_setup.copy()
	return super.host_lan()


func return_to_boot() -> void:
	solo_ai_seats = []
	setup = _cli_setup.copy()
	super.return_to_boot()


func join_lan(ip: String) -> Error:
	slot_picks = {}
	solo_ai_seats = []
	return super.join_lan(ip)


## Solo or server: the pick of an AI slot (AiRoster), published like a human's.
func set_ai_pick(slot: int, chosen: Dictionary) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	slot_picks[slot] = chosen
	if MpKit.is_networked():
		_publish_picks()
	else:
		slot_picks_changed.emit()


func _vs_ai_seat(god: StringName) -> AiSeat:
	var seat := (load(VS_AI_SEAT) as AiSeat).duplicate() as AiSeat
	## An unknown god is drawn by AiRoster (GameData is not ready yet when the dedicated reads its flags).
	if god != &"":
		seat.god = god
	return seat


## --ai-slots=2 [--ai-god=pyro] on the dedicated (RFC-024 §4). Only slot 2 for now (High Noon has two starts).
func _read_dedicated_ai() -> void:
	if not MpBoot.is_dedicated_process():
		return
	var raw := MpBoot.user_value("ai-slots", "")
	if raw.is_empty():
		return
	var seats: Array[AiSeat] = []
	for part in raw.split(",", false):
		var seat := _vs_ai_seat(StringName(MpBoot.user_value("ai-god", "")))
		seat.slot = int(part)
		if seat.slot >= 2 and seat.slot <= max_players:
			seats.append(seat)
	if seats.is_empty():
		push_warning("--ai-slots=%s: ningún slot válido" % raw)
		return
	solo_ai_seats = seats
	max_players = seats[0].slot - 1
	print("dedicado con ia en slots %s" % raw)


func _on_slot_assigned(_slot: int) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		MpKit.send_custom(PICK_CHANNEL, pick)


func _on_custom_received(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel == PICK_CHANNEL:
		_store_pick(data, from_peer)
	elif channel == SLOT_PICKS_CHANNEL and not MpKit.is_server():
		var picks: Variant = data.get("picks")
		if picks is Dictionary:
			slot_picks = picks
			slot_picks_changed.emit()


func _store_pick(data: Dictionary, from_peer: int) -> void:
	if not MpKit.is_server():
		return
	var slot := MpKit.slot_for_peer(from_peer)
	if slot <= 0:
		return
	var chosen := sanitize_pick(data)
	if chosen.is_empty():
		return
	slot_picks[slot] = chosen
	print("slot %d pick %s %s" % [slot, chosen["model"], chosen["god"]])
	_publish_picks()


func _on_peer_left(_peer_id: int, slot: int) -> void:
	if not slot_picks.has(slot):
		return
	slot_picks.erase(slot)
	_publish_picks()


func _publish_picks() -> void:
	MpKit.broadcast_custom(SLOT_PICKS_CHANNEL, {"picks": slot_picks})
	slot_picks_changed.emit()
