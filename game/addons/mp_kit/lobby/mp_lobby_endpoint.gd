class_name MpLobbyEndpoint
extends Resource

## Where the clients find the room server. Pure data. `--lobby=host:port` on the command line wins over the
## values saved in the `.tres`, so a test or a local server needs no other file.

@export var host: String = "127.0.0.1"
@export var port: int = 7700


## `host:port` of the `--lobby=` flag applied over this resource (a copy). A flag that does not parse is ignored.
func resolved() -> MpLobbyEndpoint:
	var out := duplicate() as MpLobbyEndpoint
	var raw := MpBoot.user_value("lobby", "")
	if raw.is_empty():
		return out
	var cut := raw.rfind(":")
	var wanted_host := raw if cut < 0 else raw.substr(0, cut)
	var wanted_port := out.port if cut < 0 else raw.substr(cut + 1).to_int()
	if wanted_host.is_empty() or wanted_port < 1 or wanted_port > 65535:
		push_warning("--lobby=%s: no es host:puerto, se usa el del recurso" % raw)
		return out
	out.host = wanted_host
	out.port = wanted_port
	return out
