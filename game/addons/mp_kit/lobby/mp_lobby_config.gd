class_name MpLobbyConfig
extends Resource

## Limits and times of the room server and its match processes. Pure data: no product text.
## Every int/float field can be overridden by a command-line flag with the same name, dashes
## instead of underscores (`max_matches` -> `--max-matches=4`), through `with_cli_overrides()`.

@export_group("Lobby")
@export var lobby_port: int = 7700
@export var max_connections: int = 64
## `enet` (UDP, default) or `ws` (WebSocket over TCP). Used by the lobby and forwarded to every dedicated.
@export_enum("enet", "ws") var transport: String = "enet"
@export var max_rooms: int = 32
@export var seats_per_room: int = 2
@export var proto_version: int = 1
@export var chat_max_len: int = 200
@export var chat_rate_per_s: float = 1.0
@export var chat_burst: int = 3
@export var name_max_len: int = 24
@export var list_push_hz: float = 4.0
@export var countdown_s: float = 5.0
@export var empty_room_close_s: float = 120.0
@export var resume_grace_s: float = 120.0
## A connected peer that does not say hello in this time is dropped.
@export var hello_timeout_s: float = 5.0
## Seconds between a rejection message and the disconnect (lets the message leave).
@export var reject_flush_s: float = 0.2
## Largest `options` / `meta` Dictionary a client may send (var_to_bytes size).
@export var payload_max_bytes: int = 2048
## Address sent to the clients for the match processes. Empty = the address they used for the lobby.
@export var public_host: String = ""

@export_group("Matches")
## Matches alive at once on this machine. Each match is one dedicated process.
@export var max_matches: int = 99
@export var match_port_min: int = 7800
@export var match_port_max: int = 7899
@export var spawn_timeout_s: float = 20.0
@export var ticket_ttl_s: float = 60.0
## How long a dropped player may come back with the same token.
@export var rejoin_grace_s: float = 60.0
@export var heartbeat_s: float = 2.0
@export var heartbeat_stale_s: float = 10.0
@export var idle_no_players_s: float = 60.0
@export var match_max_s: float = 7200.0
## A leftover process is killed at startup only if its heartbeat is newer than this.
@export var reap_heartbeat_max_s: float = 30.0

@export_group("Processes")
## The launcher polls state.json / result.json this often.
@export var poll_s: float = 0.25
## The dedicated checks that the room server is still alive this often.
@export var parent_check_s: float = 2.0
## Delay between result.json and quit, so the result reaches the clients.
@export var result_quit_delay_s: float = 3.0
## Root of the per-match folders.
@export var matches_root: String = "user://mp_matches"
## Fields the launcher forwards to the dedicated as `--field-name=value`.
@export var agent_fields: PackedStringArray = PackedStringArray([
	"transport", "heartbeat_s", "idle_no_players_s", "rejoin_grace_s", "parent_check_s", "result_quit_delay_s",
])


static func flag_for(field: String) -> String:
	return "--%s" % field.replace("_", "-")


## A copy with the command-line flags applied (int and float fields only).
func with_cli_overrides() -> MpLobbyConfig:
	var out := duplicate() as MpLobbyConfig
	for prop in get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var field := String(prop["name"])
		var raw := MpBoot.user_value(flag_for(field).trim_prefix("--"), "")
		if raw.is_empty():
			continue
		match int(prop["type"]):
			TYPE_INT:
				if raw.is_valid_int():
					out.set(field, raw.to_int())
			TYPE_FLOAT:
				if raw.is_valid_float():
					out.set(field, raw.to_float())
			TYPE_STRING:
				out.set(field, raw)
	return out
