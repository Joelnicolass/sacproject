class_name LocalServerEndpoint
extends RefCounted

## The text a rival types to reach a local server. Pure functions: no node, no network.
## `192.168.1.5:7710`, `mi-pc.example.com:7710` or only `192.168.1.5` (then the default port is used).

const PORT_MIN := 1
const PORT_MAX := 65535


## `{ok, host, port}`. `ok` is false when the host is not an IPv4 or a hostname, or the port is out of range.
## Without `:port`, `default_port` is used.
static func parse(text: String, default_port: int) -> Dictionary:
	var trimmed := text.strip_edges()
	var host := trimmed
	var port := default_port
	var cut := trimmed.rfind(":")
	if cut >= 0:
		host = trimmed.substr(0, cut).strip_edges()
		var raw := trimmed.substr(cut + 1).strip_edges()
		if not raw.is_valid_int():
			return {"ok": false, "host": host, "port": 0}
		port = raw.to_int()
	var valid_host := MpLan.is_valid_ipv4(host) or MpLan.is_valid_hostname(host)
	var ok := valid_host and port >= PORT_MIN and port <= PORT_MAX
	return {"ok": ok, "host": host, "port": port}


## The credential a rival typed: trimmed and lower case (the host shows it in lower case hex).
static func clean_code(text: String) -> String:
	return text.strip_edges().to_lower()


static func format(host: String, port: int) -> String:
	return "%s:%d" % [host, port]
