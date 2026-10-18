class_name LobbyText
extends RefCounted

## RFC-034 034f: every text of the room screens that is not a label of a scene. The lobby of the kit speaks in stable
## codes (`room_full`, `rate`…); this is where they become Spanish. Pure functions: no node, no network.

const OFFLINE := "Sin conexión"
const CONNECTING := "Conectando con las salas…"
const NO_ROOMS := "No hay salas abiertas. Creá una."
const ENTERING_MATCH := "Entrando a la partida…"
const RESUMING := "Se perdió la conexión. Volviendo a las salas…"
const FREE_SEAT := "Asiento libre"

const ERRORS := {
	"version": "Tu juego y el servidor de salas son de versiones distintas.",
	"bad_name": "Ese nombre no sirve. Usá hasta 24 letras, sin símbolos raros.",
	"timeout": "El servidor de salas no respondió a tiempo.",
	"rate": "Escribís muy rápido. Esperá un momento.",
	"bad_text": "Ese mensaje es demasiado largo.",
	"bad_options": "Esas opciones de sala no son válidas.",
	"bad_meta": "Ese personaje no es válido.",
	"no_session": "Se perdió tu sesión. Volvé a conectarte.",
	"no_room": "Esa sala ya no existe.",
	"already_in_room": "Ya estás en una sala.",
	"not_in_room": "No estás en ninguna sala.",
	"room_full": "La sala está llena.",
	"room_not_open": "La sala ya no acepta cambios.",
	"bad_seat": "Ese asiento no existe.",
	"seat_taken": "Ese asiento ya está ocupado.",
	"in_match": "La partida ya empezó.",
	"rooms_cap": "No caben más salas en el servidor. Probá más tarde.",
	"matches_cap": "El servidor está lleno de partidas. Probá en un rato.",
	"spawn_failed": "No se pudo preparar la partida. Volvé a intentarlo.",
	"match_failed": "La partida terminó con un error.",
}

const LOST := {
	"connect_failed": "No se pudo conectar con las salas.",
	"server_lost": "Se perdió la conexión con las salas.",
	"connect_timeout": "Las salas no respondieron a tiempo. Probá de nuevo.",
	"closed": "Se cerró la conexión con las salas.",
	"resume_window": "No se pudo volver a las salas a tiempo. Conectate de nuevo.",
}

const STATES := {
	MpLobbyRooms.State.OPEN: "Abierta",
	MpLobbyRooms.State.COUNTDOWN: "Por empezar",
	MpLobbyRooms.State.LAUNCHING: "Preparando",
	MpLobbyRooms.State.IN_MATCH: "En partida",
	MpLobbyRooms.State.CLOSED: "Cerrada",
}


static func error_text(code: String) -> String:
	return str(ERRORS.get(code, "Algo salió mal (%s)." % code))


static func lost_text(reason: String) -> String:
	return str(LOST.get(reason, OFFLINE))


static func state_text(state: int) -> String:
	return str(STATES.get(state, ""))


## «Mago · Dios: Y» of a seat's pick; «Sin elegir» if it has none.
static func pick_text(meta: Dictionary) -> String:
	if meta.is_empty():
		return "Sin elegir"
	var wizard: WizardType = GameData.wizard(str(meta.get("wizard", "")))
	var wizard_name := wizard.display_name if wizard != null else str(meta.get("model", meta.get("wizard", "?")))
	return "%s · Dios: %s" % [wizard_name, str(meta.get("god", "?")).capitalize()]


## What a result says to the player in `my_slot` (0 = not in the match). `result` is the Dictionary the dedicated
## reports: winner_slot, reason ("result", "abandon", "empty").
static func result_text(result: Dictionary, my_slot: int) -> String:
	if result.is_empty():
		return ""
	var winner := int(result.get("winner_slot", 0))
	var reason := str(result.get("reason", "result"))
	if reason == "empty" or winner <= 0:
		return "La partida se cerró sin ganador."
	var won := my_slot > 0 and winner == my_slot
	if reason == "abandon":
		return "Ganaste: tu rival abandonó." if won else "Perdiste: abandonaste la partida."
	return "Ganaste." if won else "Perdiste."
