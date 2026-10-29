class_name MpBoot
extends RefCounted

## Detect a dedicated-server process. Does not start the peer — glue calls MpKit.host_dedicated().
## Do not treat `--headless` alone as dedicated (CI / GUT also run headless).
## Editor Run Instances: `--dedicated` often lands in get_cmdline_args(), not user args
## (user args need `-- --dedicated`). Also honor feature tags `dedicated_server` / `dedicated`.


static func is_dedicated_process() -> bool:
	if OS.has_feature("dedicated_server") or OS.has_feature("dedicated"):
		return true
	return user_flag("dedicated")


static func user_flag(name: String) -> bool:
	var needle := "--%s" % name
	for arg in OS.get_cmdline_user_args():
		if _arg_is_flag(arg, needle):
			return true
	for arg in OS.get_cmdline_args():
		if _arg_is_flag(arg, needle):
			return true
	return false


static func role() -> String:
	if user_flag("server"):
		return "server"
	if user_flag("client1"):
		return "client1"
	if user_flag("client2"):
		return "client2"
	if user_flag("listen-host"):
		return "listen"
	if user_flag("room-server"):
		return "room-server"
	if user_flag("dedicated"):
		return "server"
	return ""


static func user_value(name: String, default: String = "") -> String:
	var prefix := "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	for arg in OS.get_cmdline_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default


## The highest slot of the ticket this match process was started with (`--match-ticket-file`; 0 if none or unreadable).
static func ticket_seats() -> int:
	var text := FileAccess.get_file_as_string(user_value("match-ticket-file", ""))
	var ticket: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var top := 0
	if ticket is Dictionary:
		for row in (ticket as Dictionary).get("seats", []):
			if row is Dictionary:
				top = maxi(top, int((row as Dictionary).get("slot", 0)))
	return top


static func _arg_is_flag(arg: String, needle: String) -> bool:
	return arg == needle or arg.begins_with(needle + "=")
