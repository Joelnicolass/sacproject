class_name LobbyText
extends RefCounted

## Every text of the room screens that is not a label of a scene. The lobby of the kit speaks in stable
## codes (`room_full`, `rate`…); this is where they become Spanish. Pure functions: no node, no network.

const OFFLINE := "LOBBY_OFFLINE"
const CONNECTING := "LOBBY_CONNECTING"
const NO_ROOMS := "LOBBY_NO_ROOMS"
const ENTERING_MATCH := "LOBBY_ENTERING_MATCH"
const RESUMING := "LOBBY_RESUMING"
const FREE_SEAT := "LOBBY_FREE_SEAT"

const ERRORS := {
	"version": "LOBBY_ERR_VERSION",
	"bad_name": "LOBBY_ERR_BAD_NAME",
	"timeout": "LOBBY_ERR_TIMEOUT",
	"rate": "LOBBY_ERR_RATE",
	"bad_text": "LOBBY_ERR_BAD_TEXT",
	"bad_options": "LOBBY_ERR_BAD_OPTIONS",
	"bad_meta": "LOBBY_ERR_BAD_META",
	"no_session": "LOBBY_ERR_NO_SESSION",
	"no_room": "LOBBY_ERR_NO_ROOM",
	"already_in_room": "LOBBY_ERR_ALREADY_IN_ROOM",
	"not_in_room": "LOBBY_ERR_NOT_IN_ROOM",
	"room_full": "LOBBY_ERR_ROOM_FULL",
	"room_not_open": "LOBBY_ERR_ROOM_NOT_OPEN",
	"bad_seat": "LOBBY_ERR_BAD_SEAT",
	"seat_taken": "LOBBY_ERR_SEAT_TAKEN",
	"in_match": "LOBBY_ERR_IN_MATCH",
	"rooms_cap": "LOBBY_ERR_ROOMS_CAP",
	"matches_cap": "LOBBY_ERR_MATCHES_CAP",
	"spawn_failed": "LOBBY_ERR_SPAWN_FAILED",
	"match_failed": "LOBBY_ERR_MATCH_FAILED",
	"not_host": "LOBBY_ERR_NOT_HOST",
	"bad_bot": "LOBBY_ERR_BAD_BOT",
}

const LOST := {
	"connect_failed": "LOBBY_LOST_CONNECT_FAILED",
	"server_lost": "LOBBY_LOST_SERVER_LOST",
	"connect_timeout": "LOBBY_LOST_CONNECT_TIMEOUT",
	"closed": "LOBBY_LOST_CLOSED",
	"resume_window": "LOBBY_LOST_RESUME_WINDOW",
}

const STATES := {
	MpLobbyRooms.State.OPEN: "LOBBY_STATE_OPEN",
	MpLobbyRooms.State.COUNTDOWN: "LOBBY_STATE_COUNTDOWN",
	MpLobbyRooms.State.LAUNCHING: "LOBBY_STATE_LAUNCHING",
	MpLobbyRooms.State.IN_MATCH: "LOBBY_STATE_IN_MATCH",
	MpLobbyRooms.State.CLOSED: "LOBBY_STATE_CLOSED",
}


static func error_text(code: String) -> String:
	return UiText.t(ERRORS[code]) if ERRORS.has(code) else UiText.t("LOBBY_ERR_UNKNOWN") % code


static func lost_text(reason: String) -> String:
	return UiText.t(LOST.get(reason, OFFLINE))


static func state_text(state: int) -> String:
	return UiText.t(STATES[state]) if STATES.has(state) else ""


## «Mago · Dios: Y» of a seat's pick; «Sin elegir» if it has none.
static func pick_text(meta: Dictionary) -> String:
	if meta.is_empty():
		return UiText.t("LOBBY_NO_PICK")
	var pick: WizardPick = MatchWire.decode_pick(meta)
	if pick == null:
		return UiText.t("LOBBY_PICK_FORMAT") % [str(meta.get("model", meta.get("wizard", "?"))), str(meta.get("god", "?")).capitalize()]
	return UiText.t("LOBBY_PICK_FORMAT") % [pick.wizard.display_name, pick.god.display_name]


## «Dios: X · Normal» of a bot seat's meta ({god, difficulty}); an empty god is drawn when the match starts.
static func bot_text(meta: Dictionary) -> String:
	var god := str(meta.get("god", ""))
	var god_name := UiText.t("LOBBY_BOT_RANDOM_GOD")
	if not god.is_empty():
		var data: GodType = MatchWire.decode_god(god)
		god_name = data.display_name if data != null else god.capitalize()
	return UiText.t("LOBBY_BOT_FORMAT") % [god_name, AiDifficultyPicker.difficulty_name(str(meta.get("difficulty", "normal")))]


## What a result says to the player in `my_slot` (0 = not in the match). `result` is the Dictionary the dedicated
## reports: winner_slot, winner_slots (the whole winning team), reason ("result", "abandon", "empty").
static func result_text(result: Dictionary, my_slot: int) -> String:
	if result.is_empty():
		return ""
	var winner := int(result.get("winner_slot", 0))
	var reason := str(result.get("reason", "result"))
	if reason == "empty" or winner <= 0:
		return UiText.t("LOBBY_RESULT_NO_WINNER")
	var winners: Array = result.get("winner_slots", [])
	if winners.is_empty():
		winners = [winner]
	var won := my_slot > 0 and (winners.has(my_slot) or winners.has(float(my_slot)))
	# A winning team of two or more speaks of teams («Ganó tu equipo»).
	var prefix := "LOBBY_RESULT_TEAM_" if winners.size() >= 2 else "LOBBY_RESULT_"
	if reason == "abandon":
		return UiText.t(prefix + ("WON_ABANDON" if won else "LOST_ABANDON"))
	return UiText.t(prefix + ("WON" if won else "LOST"))
