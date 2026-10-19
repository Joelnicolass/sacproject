class_name LocalServerText
extends RefCounted

## RFC-034 034m: every text of the «Servidor local» screens that is not a label of a scene. Pure functions: no node.

const TITLE := "LOCAL_TITLE"
const PICK_BUTTON := "LOCAL_PICK_BUTTON"
const PICK_CONFIRM := "LOCAL_PICK_CONFIRM"
const PICK_CHOICE := "LOCAL_PICK_CHOICE"
const STARTING := "LOCAL_STARTING"
const INFO_ADDRESS := "LOCAL_INFO_ADDRESS"
const INFO_NO_ADDRESS := "LOCAL_INFO_NO_ADDRESS"
const INFO_PORT := "LOCAL_INFO_PORT"
const INFO_TRANSPORT := "LOCAL_INFO_TRANSPORT"
const INFO_CODE := "LOCAL_INFO_CODE"
const INFO_SEAT_CODE := "LOCAL_INFO_SEAT_CODE"
const INFO_NO_CODE := "LOCAL_INFO_NO_CODE"
const COPIED := "LOCAL_COPIED"
const HELP_HOST := "LOCAL_HELP_HOST"
const HELP_JOIN := "LOCAL_HELP_JOIN"
const CONNECTING := "LOCAL_CONNECTING"
const WAITING_HOST := "LOCAL_WAITING_HOST"
const BAD_ENDPOINT := "LOCAL_BAD_ENDPOINT"
const BAD_CODE := "LOCAL_BAD_CODE"
const FAILED_START := "LOCAL_FAILED_START"

const TRANSPORT_NAMES := {
	"enet": "UDP (ENet)",
	"ws": "TCP (WebSocket)",
}

const REJECTIONS := {
	"rejected": "LOCAL_REJECT_REJECTED",
	"slot_taken": "LOCAL_REJECT_SLOT_TAKEN",
	"timeout": "LOCAL_REJECT_TIMEOUT",
	"bad_pick": "LOCAL_REJECT_BAD_PICK",
	"dropped": "LOCAL_REJECT_DROPPED",
}
const REJECTION_FALLBACK := "LOCAL_REJECTION_FALLBACK"

const START_ERRORS := {
	"spawn_timeout": "LOCAL_START_ERR_SPAWN_TIMEOUT",
	"exited": "LOCAL_START_ERR_EXITED",
	"heartbeat_stale": "LOCAL_START_ERR_HEARTBEAT_STALE",
	"match_max": "LOCAL_START_ERR_MATCH_MAX",
}
const START_ERROR_FALLBACK := "LOCAL_START_ERROR_FALLBACK"


## RFC-049 049h: the codes to pass along, one line per seat for a person ({slot: code}); one seat keeps the 1v1 line.
static func codes_text(codes: Dictionary) -> String:
	if codes.is_empty():
		return UiText.t(INFO_NO_CODE)
	if codes.size() == 1:
		return UiText.t(INFO_CODE) % str(codes.values()[0])
	var slots := codes.keys()
	slots.sort()
	var lines := PackedStringArray()
	for slot in slots:
		lines.append(UiText.t(INFO_SEAT_CODE) % [int(slot), str(codes[slot])])
	return "\n".join(lines)


static func transport_name(kind: String) -> String:
	return TRANSPORT_NAMES.get(MpTransport.normalize(kind), "")


static func rejection_text(reason: String) -> String:
	return UiText.t(REJECTIONS.get(reason, REJECTION_FALLBACK))


static func start_error_text(reason: String) -> String:
	return UiText.t(START_ERRORS.get(reason, START_ERROR_FALLBACK))


static func address_text(address: String) -> String:
	return UiText.t(INFO_ADDRESS) % address if not address.is_empty() else UiText.t(INFO_NO_ADDRESS)


## «UDP (ENet)» / «TCP (WebSocket)» in `picker`, each item with its kind as metadata; the one of MpKit selected.
static func fill_transports(picker: OptionButton) -> void:
	picker.clear()
	for kind: String in [MpTransport.ENET, MpTransport.WS]:
		picker.add_item(TRANSPORT_NAMES[kind])
		picker.set_item_metadata(picker.item_count - 1, kind)
		if kind == MpKit.transport:
			picker.select(picker.item_count - 1)
