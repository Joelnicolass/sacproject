class_name MpRoomRules
extends Resource

## The rules of a room in the online lobby, as functions you override in your own script:
##   extends MpRoomRules
##   func seats_for(options: Dictionary) -> int: return 4 if options.get("mode") == "2v2" else 2
## Assign it to MpRoomServer.rules. The defaults accept everything (2 seats per room from MpLobbyConfig).
## Every function runs on the room server, with what a client sent: check it, never trust it.
## Not: the match itself (that runs in its own dedicated process, see MpMatch).


## Seats of a room created with these options (0 or less = refuse the options). -1 = MpLobbyConfig.seats_per_room.
func seats_for(_options: Dictionary) -> int:
	return -1


## Room options a client asked for (map, mode...). False = `bad_options`.
func accept_options(_options: Dictionary) -> bool:
	return true


## The pick of a seat (character, team...). False = `bad_meta`.
func accept_pick(_pick: Dictionary) -> bool:
	return true


## The pick of a bot the room's host put in a seat. False = `bad_bot`.
func accept_bot(_pick: Dictionary) -> bool:
	return true


## What the match process receives. `seats`: [{slot, token, meta}] (bots: {slot, bot: true, meta}). Keep `seats`;
## add what the match needs (a seed, the map). The default sends options and seats as they are.
func build_ticket(seats: Array, options: Dictionary) -> Dictionary:
	return {"options": options, "seats": seats}


## Wires these rules into a lobby server (MpRoomServer does it before start).
func bind(server: MpLobbyServer) -> void:
	server.options_validator = accept_options
	server.meta_validator = accept_pick
	server.bot_validator = accept_bot
	server.ticket_builder = build_ticket
	server.seat_count_for = func(options: Dictionary) -> int:
		var seats := seats_for(options)
		return seats if seats != -1 else server.config.seats_per_room if server.config else 2
